import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One value saved on the phone, with when and for whom it was saved.
final class DiskCacheEntry {
  const DiskCacheEntry({
    required this.savedAt,
    required this.scope,
    required this.json,
  });

  final DateTime savedAt;
  final String scope;

  /// The already-encoded JSON payload.
  final String json;
}

/// Storage behind the on-device resource cache. Kept as an interface so the
/// cache logic is testable without a real device.
abstract interface class ResourceDiskCache {
  Future<DiskCacheEntry?> read(String key);

  Future<void> write(String key, DiskCacheEntry entry);

  /// Removes every saved entry that was not saved for [scope].
  Future<void> removeOtherScopes(String scope);

  Future<void> clear();
}

/// SharedPreferences-backed cache. Works on Android, iOS and the web build.
///
/// Each value is one string: `savedAtMs|scope|json`. Reading the header
/// needs no JSON parsing, so scope checks and eviction stay cheap.
final class SharedPreferencesResourceDiskCache implements ResourceDiskCache {
  SharedPreferencesResourceDiskCache({
    Future<SharedPreferences>? preferences,
    this.maxEntries = 400,
    this.maxEntryChars = 600000,
  }) : _preferences = preferences ?? SharedPreferences.getInstance();

  static const _prefix = 'rescache.v1.';

  final Future<SharedPreferences> _preferences;

  /// Oldest entries are dropped beyond this count.
  final int maxEntries;

  /// A single oversized list is skipped rather than slowing every launch.
  final int maxEntryChars;

  String _storageKey(String key) => '$_prefix$key';

  static ({DateTime savedAt, String scope, int jsonStart})? _header(
    String raw,
  ) {
    final first = raw.indexOf('|');
    if (first <= 0) return null;
    final second = raw.indexOf('|', first + 1);
    if (second <= first) return null;
    final millis = int.tryParse(raw.substring(0, first));
    if (millis == null) return null;
    return (
      savedAt: DateTime.fromMillisecondsSinceEpoch(millis),
      scope: raw.substring(first + 1, second),
      jsonStart: second + 1,
    );
  }

  @override
  Future<DiskCacheEntry?> read(String key) async {
    try {
      final prefs = await _preferences;
      final raw = prefs.getString(_storageKey(key));
      if (raw == null) return null;
      final header = _header(raw);
      if (header == null) {
        await prefs.remove(_storageKey(key));
        return null;
      }
      return DiskCacheEntry(
        savedAt: header.savedAt,
        scope: header.scope,
        json: raw.substring(header.jsonStart),
      );
    } on Object {
      // A cache that cannot be read is simply a cache miss.
      return null;
    }
  }

  @override
  Future<void> write(String key, DiskCacheEntry entry) async {
    if (entry.json.length > maxEntryChars) return;
    try {
      final prefs = await _preferences;
      await prefs.setString(
        _storageKey(key),
        '${entry.savedAt.millisecondsSinceEpoch}|${entry.scope}|${entry.json}',
      );
      await _evictOldest(prefs);
    } on Object {
      // Never let a full or unavailable disk break browsing.
    }
  }

  Future<void> _evictOldest(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
    if (keys.length <= maxEntries) return;
    final dated = <MapEntry<String, int>>[];
    for (final key in keys) {
      final header = _header(prefs.getString(key) ?? '');
      dated.add(MapEntry(key, header?.savedAt.millisecondsSinceEpoch ?? 0));
    }
    dated.sort((a, b) => a.value.compareTo(b.value));
    final excess = dated.length - maxEntries;
    for (final entry in dated.take(excess)) {
      await prefs.remove(entry.key);
    }
  }

  @override
  Future<void> removeOtherScopes(String scope) async {
    try {
      final prefs = await _preferences;
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        final header = _header(prefs.getString(key) ?? '');
        if (header == null || header.scope != scope) await prefs.remove(key);
      }
    } on Object {
      // Best effort; reads also ignore entries saved for another scope.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await _preferences;
      for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
        await prefs.remove(key);
      }
    } on Object {
      // Nothing to clean up if storage is unavailable.
    }
  }
}

/// Encodes a decoded-JSON value for [DiskCacheEntry.json].
String encodeDiskJson(Object? value) => jsonEncode(value);

/// Decodes a payload written by [encodeDiskJson].
Object? decodeDiskJson(String raw) => jsonDecode(raw);
