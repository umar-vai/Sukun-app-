import 'dart:async';

import 'package:sukun_life/features/resources/data/resource_disk_cache.dart';
import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

/// Remembers resource reads so reopening a Qur'an, Dua, Hadith or Ruqyah
/// screen is instant instead of showing a loader each time.
///
/// Two layers:
/// * Memory, for repeat reads in one session (fresh for [ttl]).
/// * The phone's storage (when a [ResourceDiskCache] is given), so even the
///   first read after the app is reopened is answered at once. A saved value
///   older than [ttl] is shown immediately and refreshed quietly in the
///   background, so edited content appears the next time the screen opens.
///
/// Safety rules:
/// * Entries are scoped to the signed-in identity. Resource visibility
///   (`public`, `patient_only`, `assigned_only`) depends on who is asking, so
///   switching or signing out discards everything, on disk too.
/// * Failures are never cached; a retry always reaches the backend.
/// * Typed search queries are never cached.
/// * Empty answers are not saved to the phone, so a temporary empty response
///   can never stick.
/// * Saved values older than [diskMaxAge] are ignored.
final class CachedResourcesRepository implements ResourcesRepository {
  CachedResourcesRepository(
    this._inner,
    this._scope, {
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? now,
    this.disk,
    this.diskMaxAge = const Duration(days: 30),
  }) : _now = now ?? DateTime.now;

  final ResourcesRepository _inner;
  final String? Function() _scope;
  final DateTime Function() _now;

  /// Where values are saved on the phone; null keeps the cache memory-only.
  final ResourceDiskCache? disk;
  final Duration ttl;
  final Duration diskMaxAge;
  final Map<String, _Entry> _entries = {};
  String? _activeScope;

  /// Forgets everything, in memory and on the phone.
  Future<void> clear() async {
    _entries.clear();
    _activeScope = null;
    await disk?.clear();
  }

  Future<T> _cached<T>(
    String key,
    Future<T> Function() load, {
    required Object? Function(T value) encode,
    required T Function(Object? json) decode,
    bool Function(T value)? worthSaving,
  }) {
    final scope = _scope() ?? 'guest';
    if (_activeScope != scope) {
      _entries.clear();
      _activeScope = scope;
      final store = disk;
      if (store != null) unawaited(store.removeOtherScopes(scope));
    }
    final existing = _entries[key];
    if (existing != null && _now().difference(existing.at) < ttl) {
      return existing.future as Future<T>;
    }
    final future = _resolve<T>(
      key,
      scope,
      load,
      encode,
      decode,
      worthSaving ?? (_) => true,
    );
    final entry = _Entry(future, _now());
    _entries[key] = entry;
    unawaited(_forgetIfFailed(key, entry));
    return future;
  }

  Future<T> _resolve<T>(
    String key,
    String scope,
    Future<T> Function() load,
    Object? Function(T value) encode,
    T Function(Object? json) decode,
    bool Function(T value) worthSaving,
  ) async {
    final stored = await _readDisk(key, scope);
    if (stored != null) {
      try {
        final value = decode(decodeDiskJson(stored.json));
        if (_now().difference(stored.savedAt) >= ttl) {
          unawaited(_refresh<T>(key, scope, load, encode, worthSaving));
        }
        return value;
      } on Object {
        // A damaged or outdated saved value is treated as a miss.
      }
    }
    final value = await load();
    await _save<T>(key, scope, value, encode, worthSaving);
    return value;
  }

  /// Quietly replaces a saved value with the latest one. Errors are ignored:
  /// the older value stays on screen and the next open tries again.
  Future<void> _refresh<T>(
    String key,
    String scope,
    Future<T> Function() load,
    Object? Function(T value) encode,
    bool Function(T value) worthSaving,
  ) async {
    try {
      final fresh = await load();
      if (_activeScope != scope) return;
      await _save<T>(key, scope, fresh, encode, worthSaving);
      if (_activeScope == scope) {
        _entries[key] = _Entry(Future<T>.value(fresh), _now());
      }
    } on Object {
      // Offline or backend error: keep showing the saved value.
    }
  }

  Future<DiskCacheEntry?> _readDisk(String key, String scope) async {
    final store = disk;
    if (store == null) return null;
    final stored = await store.read(key);
    if (stored == null || stored.scope != scope) return null;
    if (_now().difference(stored.savedAt) > diskMaxAge) return null;
    return stored;
  }

  Future<void> _save<T>(
    String key,
    String scope,
    T value,
    Object? Function(T value) encode,
    bool Function(T value) worthSaving,
  ) async {
    final store = disk;
    if (store == null || !worthSaving(value)) return;
    try {
      await store.write(
        key,
        DiskCacheEntry(
          savedAt: _now(),
          scope: scope,
          json: encodeDiskJson(encode(value)),
        ),
      );
    } on Object {
      // Saving is an optimisation, never a reason to fail a read.
    }
  }

  Future<void> _forgetIfFailed(String key, _Entry entry) async {
    try {
      await entry.future;
    } catch (_) {
      if (identical(_entries[key], entry)) _entries.remove(key);
    }
  }

  static String _set(Set<String> values) {
    final sorted = values.toList()..sort();
    return sorted.join(',');
  }

  static Object? _encodeResources(List<ContentResource> items) => [
    for (final item in items) item.toJson(),
  ];

  static List<ContentResource> _decodeResources(Object? json) => [
    for (final item in json! as List<dynamic>)
      ContentResource.fromJson(item as Map<String, dynamic>),
  ];

  static bool _notEmpty(List<Object?> items) => items.isNotEmpty;

  @override
  Future<List<ContentResource>> browseResources({
    String query = '',
    Set<String> types = const {},
    Set<String> categoryPrefixes = const {},
  }) {
    Future<List<ContentResource>> load() {
      return _inner.browseResources(
        query: query,
        types: types,
        categoryPrefixes: categoryPrefixes,
      );
    }

    if (query.trim().isNotEmpty) return load();
    final key = 'browse|${_set(types)}|${_set(categoryPrefixes)}';
    return _cached(
      key,
      load,
      encode: _encodeResources,
      decode: _decodeResources,
      worthSaving: _notEmpty,
    );
  }

  @override
  Future<ContentResource?> getResource(String resourceId) {
    final key = 'resource|$resourceId';
    return _cached<ContentResource?>(
      key,
      () => _inner.getResource(resourceId),
      encode: (value) => value?.toJson(),
      decode: (json) => ContentResource.fromJson(json! as Map<String, dynamic>),
      // A missing resource is never saved: it may simply not be published yet.
      worthSaving: (value) => value != null,
    );
  }

  @override
  Future<List<QuranSurahSummary>> browseSurahs() {
    return _cached(
      'surahs',
      _inner.browseSurahs,
      encode: (items) => [for (final item in items) item.toJson()],
      decode: (json) => [
        for (final item in json! as List<dynamic>)
          QuranSurahSummary.fromJson(item as Map<String, dynamic>),
      ],
      worthSaving: _notEmpty,
    );
  }

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) {
    final key = 'surah|$surahNumber';
    return _cached(
      key,
      () => _inner.browseSurah(surahNumber),
      encode: _encodeResources,
      decode: _decodeResources,
      worthSaving: _notEmpty,
    );
  }

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) {
    final key = 'topics|${_set(types)}|${_set(categoryPrefixes)}';
    return _cached(
      key,
      () {
        return _inner.browseTopics(
          types: types,
          categoryPrefixes: categoryPrefixes,
        );
      },
      encode: (items) => [for (final item in items) item.toJson()],
      decode: (json) => [
        for (final item in json! as List<dynamic>)
          ResourceTopic.fromJson(item as Map<String, dynamic>),
      ],
      worthSaving: _notEmpty,
    );
  }

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) {
    final key = 'collections|${_set(types)}';
    return _cached(
      key,
      () => _inner.browseCollections(types: types),
      encode: (items) => [for (final item in items) item.toJson()],
      decode: (json) => [
        for (final item in json! as List<dynamic>)
          ContentCollection.fromJson(item as Map<String, dynamic>),
      ],
      worthSaving: _notEmpty,
    );
  }

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) {
    final key = 'collection|$collectionId';
    return _cached<ContentCollectionDetails?>(
      key,
      () => _inner.getCollection(collectionId),
      encode: (value) => value?.toJson(),
      decode: (json) =>
          ContentCollectionDetails.fromJson(json! as Map<String, dynamic>),
      worthSaving: (value) => value != null,
    );
  }

  /// Quietly loads the screens people open first, while the user is still on
  /// the home screen. Errors are ignored; real screens retry on their own.
  ///
  /// On a phone with a disk cache this is what fills it on the first launch,
  /// so later launches (and offline use) need no loaders.
  Future<void> warmUp() async {
    Future<void> quiet(Future<Object?> job) async {
      try {
        await job;
      } catch (_) {
        // The real screen shows its own retry state if this still fails.
      }
    }

    const ayatTypes = {'selected_ayat', 'ruqyah_ayat'};
    await Future.wait([
      quiet(browseSurahs()),
      quiet(browseCollections(types: ayatTypes)),
      quiet(browseTopics(types: const {'hadith'})),
    ]);
    // Then each Resources section's first list, with the same arguments the
    // category screen uses, so opening a section needs no loader.
    await Future.wait([
      for (final section in resourceSections)
        quiet(
          browseResources(
            types: section.slug == 'books-articles'
                ? const {'book', 'book_chapter', 'pdf'}
                : section.types,
            categoryPrefixes: section.categoryPrefixes,
          ),
        ),
    ]);
    // The Dua & Azkar and Self Ruqyah guide screens use their own list
    // arguments, so warm those exact lists too.
    final duaList = <ContentResource>[];
    final guideList = <ContentResource>[];
    await Future.wait([
      quiet(browseResources(types: const {'dua', 'amal'}).then(duaList.addAll)),
      quiet(
        browseResources(
          types: const {'guide'},
          categoryPrefixes: const {'ruqyah'},
        ).then(guideList.addAll),
      ),
      quiet(
        browseResources(
          types: const {'quran', 'amal', 'audio', 'guide'},
          categoryPrefixes: const {'ruqyah'},
        ),
      ),
    ]);
    // Dua and guide pages show each item's full text on one page, so keep
    // those texts on the phone too. A few at a time, and only if not already
    // saved recently.
    await _warmFullTexts([...duaList, ...guideList]);
  }

  Future<void> _warmFullTexts(List<ContentResource> items) async {
    if (disk == null) return;
    const maxItems = 400;
    const batchSize = 4;
    const recent = Duration(days: 1);
    final scope = _scope() ?? 'guest';
    final pending = <String>[];
    for (final item in items.take(maxItems)) {
      final stored = await _readDisk('resource|${item.id}', scope);
      if (stored == null || _now().difference(stored.savedAt) >= recent) {
        pending.add(item.id);
      }
    }
    for (var start = 0; start < pending.length; start += batchSize) {
      final batch = pending.skip(start).take(batchSize);
      await Future.wait([
        for (final id in batch)
          () async {
            try {
              await getResource(id);
            } catch (_) {
              // Quiet by design; the page loads it again when opened.
            }
          }(),
      ]);
    }
  }
}

final class _Entry {
  const _Entry(this.future, this.at);
  final Future<Object?> future;
  final DateTime at;
}
