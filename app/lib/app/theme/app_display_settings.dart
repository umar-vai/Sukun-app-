import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Only local, non-clinical display preferences. Never stored with patient data.
@immutable
class AppDisplayPreferences {
  const AppDisplayPreferences({
    this.themeMode = ThemeMode.system,
    this.bengaliScale = 1.0,
    this.arabicScale = 1.0,
  });

  final ThemeMode themeMode;
  final double bengaliScale;
  final double arabicScale;

  AppDisplayPreferences copyWith({
    ThemeMode? themeMode,
    double? bengaliScale,
    double? arabicScale,
  }) => AppDisplayPreferences(
    themeMode: themeMode ?? this.themeMode,
    bengaliScale: bengaliScale ?? this.bengaliScale,
    arabicScale: arabicScale ?? this.arabicScale,
  );
}

class AppDisplaySettings extends ValueNotifier<AppDisplayPreferences> {
  AppDisplaySettings._() : super(const AppDisplayPreferences());

  static final AppDisplaySettings instance = AppDisplaySettings._();
  static const themeKey = 'sukun_display_mode_v1';
  static const bengaliKey = 'sukun_bengali_scale_v1';
  static const arabicKey = 'sukun_arabic_scale_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(themeKey);
      final savedMode = ThemeMode.values.where((option) => option.name == mode);
      value = AppDisplayPreferences(
        themeMode: savedMode.isEmpty ? ThemeMode.system : savedMode.first,
        bengaliScale: validBengaliScale(prefs.getDouble(bengaliKey)),
        arabicScale: validArabicScale(prefs.getDouble(arabicKey)),
      );
    } catch (_) {
      // A blocked local storage provider never stops the app from opening.
    }
  }

  static double validBengaliScale(double? scale) =>
      scale != null && scale.isFinite && scale >= 0.85 && scale <= 1.4
      ? scale
      : 1.0;

  static double validArabicScale(double? scale) =>
      scale != null && scale.isFinite && scale >= 0.85 && scale <= 1.6
      ? scale
      : 1.0;

  Future<void> setThemeMode(ThemeMode mode) async {
    value = value.copyWith(themeMode: mode);
    await _persist(themeKey, mode.name);
  }

  Future<void> setBengaliScale(double scale) async {
    value = value.copyWith(bengaliScale: validBengaliScale(scale));
    await _persist(bengaliKey, value.bengaliScale);
  }

  Future<void> setArabicScale(double scale) async {
    value = value.copyWith(arabicScale: validArabicScale(scale));
    await _persist(arabicKey, value.arabicScale);
  }

  Future<void> _persist(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (_) {
      // Apply instantly in this session and retry persistence next change.
    }
  }
}
