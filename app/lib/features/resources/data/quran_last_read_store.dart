import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the reader last stopped in the Qur'an. Stored only on this device;
/// it holds a surah/ayah position and the display title, never Qur'an text.
@immutable
class QuranLastRead {
  const QuranLastRead({
    required this.surah,
    required this.ayah,
    required this.title,
  });

  final int surah;
  final int ayah;
  final String title;

  String get route => '/resources/quran/$surah?ayah=$ayah';

  Map<String, Object> toJson() => {
    'surah': surah,
    'ayah': ayah,
    'title': title,
  };

  static QuranLastRead? fromJson(Object? json) {
    if (json is! Map) return null;
    final surah = json['surah'];
    final ayah = json['ayah'];
    final title = json['title'];
    if (surah is! int || surah < 1 || surah > 114) return null;
    if (ayah is! int || ayah < 1) return null;
    return QuranLastRead(
      surah: surah,
      ayah: ayah,
      title: title is String && title.trim().isNotEmpty ? title : 'সূরা $surah',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is QuranLastRead &&
      other.surah == surah &&
      other.ayah == ayah &&
      other.title == title;

  @override
  int get hashCode => Object.hash(surah, ayah, title);
}

/// Device-local "continue reading" position. Failures are silent: losing a
/// bookmark must never block reading.
abstract final class QuranLastReadStore {
  static const _key = 'sukun.quran.last_read';

  static final ValueNotifier<QuranLastRead?> current = ValueNotifier(null);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      current.value = QuranLastRead.fromJson(jsonDecode(raw));
    } catch (_) {
      // Ignore unreadable or unavailable storage.
    }
  }

  static Future<void> save(QuranLastRead position) async {
    if (current.value == position) return;
    current.value = position;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(position.toJson()));
    } catch (_) {
      // Keep the in-memory position even if the device refuses to store it.
    }
  }

  /// Signing out or switching accounts must not show someone else's place.
  static Future<void> clear() async {
    current.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }

  @visibleForTesting
  static void resetForTest() {
    _loaded = false;
    current.value = null;
  }
}
