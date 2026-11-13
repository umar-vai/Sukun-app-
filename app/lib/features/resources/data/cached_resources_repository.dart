import 'dart:async';

import 'package:sukun_life/features/resources/data/resources_repository.dart';
import 'package:sukun_life/features/resources/domain/content_resource.dart';
import 'package:sukun_life/features/resources/domain/resource_browsing.dart';

/// Remembers recent resource reads in memory so reopening a Qur'an, Dua,
/// Hadith or Ruqyah screen is instant instead of showing a loader each time.
///
/// Safety rules:
/// * Entries are scoped to the signed-in identity. Resource visibility
///   (`public`, `patient_only`, `assigned_only`) depends on who is asking, so
///   switching or signing out discards everything.
/// * Failures are never cached; a retry always reaches the backend.
/// * Typed search queries are never cached.
/// * Entries expire after [ttl], so edited content appears shortly after.
final class CachedResourcesRepository implements ResourcesRepository {
  CachedResourcesRepository(
    this._inner, {
    required String? Function() scope,
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _scope = scope,
       _now = now ?? DateTime.now;

  final ResourcesRepository _inner;
  final String? Function() _scope;
  final DateTime Function() _now;
  final Duration ttl;
  final Map<String, _Entry> _entries = {};
  String? _activeScope;

  void clear() => _entries.clear();

  Future<T> _cached<T>(String key, Future<T> Function() load) {
    final scope = _scope() ?? 'guest';
    if (_activeScope != scope) {
      _entries.clear();
      _activeScope = scope;
    }
    final existing = _entries[key];
    if (existing != null && _now().difference(existing.at) < ttl) {
      return existing.future as Future<T>;
    }
    final future = load();
    final entry = _Entry(future, _now());
    _entries[key] = entry;
    unawaited(_forgetIfFailed(key, entry));
    return future;
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
    return _cached(key, load);
  }

  @override
  Future<ContentResource?> getResource(String resourceId) {
    final key = 'resource|$resourceId';
    return _cached(key, () => _inner.getResource(resourceId));
  }

  @override
  Future<List<QuranSurahSummary>> browseSurahs() {
    return _cached('surahs', _inner.browseSurahs);
  }

  @override
  Future<List<ContentResource>> browseSurah(int surahNumber) {
    final key = 'surah|$surahNumber';
    return _cached(key, () => _inner.browseSurah(surahNumber));
  }

  @override
  Future<List<ResourceTopic>> browseTopics({
    required Set<String> types,
    Set<String> categoryPrefixes = const {},
  }) {
    final key = 'topics|${_set(types)}|${_set(categoryPrefixes)}';
    return _cached(key, () {
      return _inner.browseTopics(
        types: types,
        categoryPrefixes: categoryPrefixes,
      );
    });
  }

  @override
  Future<List<ContentCollection>> browseCollections({
    Set<String> types = const {},
  }) {
    final key = 'collections|${_set(types)}';
    return _cached(key, () => _inner.browseCollections(types: types));
  }

  @override
  Future<ContentCollectionDetails?> getCollection(String collectionId) {
    final key = 'collection|$collectionId';
    return _cached(key, () => _inner.getCollection(collectionId));
  }

  /// Quietly loads the screens people open first, while the user is still on
  /// the home screen. Errors are ignored; real screens retry on their own.
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
  }
}

final class _Entry {
  const _Entry(this.future, this.at);
  final Future<Object?> future;
  final DateTime at;
}
