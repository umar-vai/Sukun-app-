import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';

enum ArabicReaderFont {
  amiriQuran('আমিরি কুরআন'),
  notoNaskhArabic('নোটো নাসখ');

  const ArabicReaderFont(this.label);
  final String label;
}

/// Only local, non-clinical display preferences. Never stored with patient data.
@immutable
class AppDisplayPreferences {
  const AppDisplayPreferences({
    this.themeMode = ThemeMode.system,
    this.accentPalette = SukunAccentPalette.sukunBlue,
    this.bengaliScale = 1.0,
    this.arabicScale = 1.0,
    this.arabicFont = ArabicReaderFont.amiriQuran,
    this.showQuranBanglaTranslation = true,
    this.readerLineSpacing = 1.0,
  });

  final ThemeMode themeMode;
  final SukunAccentPalette accentPalette;
  final double bengaliScale;
  final double arabicScale;
  final ArabicReaderFont arabicFont;
  final bool showQuranBanglaTranslation;
  final double readerLineSpacing;

  AppDisplayPreferences copyWith({
    ThemeMode? themeMode,
    SukunAccentPalette? accentPalette,
    double? bengaliScale,
    double? arabicScale,
    ArabicReaderFont? arabicFont,
    bool? showQuranBanglaTranslation,
    double? readerLineSpacing,
  }) => AppDisplayPreferences(
    themeMode: themeMode ?? this.themeMode,
    accentPalette: accentPalette ?? this.accentPalette,
    bengaliScale: bengaliScale ?? this.bengaliScale,
    arabicScale: arabicScale ?? this.arabicScale,
    arabicFont: arabicFont ?? this.arabicFont,
    showQuranBanglaTranslation:
        showQuranBanglaTranslation ?? this.showQuranBanglaTranslation,
    readerLineSpacing: readerLineSpacing ?? this.readerLineSpacing,
  );
}

class AppDisplaySettings extends ValueNotifier<AppDisplayPreferences> {
  AppDisplaySettings._() : super(const AppDisplayPreferences());

  static final AppDisplaySettings instance = AppDisplaySettings._();
  static const themeKey = 'sukun_display_mode_v1';
  static const paletteKey = 'sukun_accent_palette_v1';
  static const bengaliKey = 'sukun_bengali_scale_v1';
  static const arabicKey = 'sukun_arabic_scale_v1';
  static const arabicFontKey = 'sukun_reader_arabic_font_v1';
  static const quranTranslationKey = 'sukun_quran_bangla_translation_v1';
  static const readerLineSpacingKey = 'sukun_reader_spacing_v1';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(themeKey);
      final savedMode = ThemeMode.values.where((option) => option.name == mode);
      value = AppDisplayPreferences(
        themeMode: savedMode.isEmpty ? ThemeMode.system : savedMode.first,
        accentPalette: parseAccentPalette(prefs.getString(paletteKey)),
        bengaliScale: validBengaliScale(prefs.getDouble(bengaliKey)),
        arabicScale: validArabicScale(prefs.getDouble(arabicKey)),
        arabicFont: parseArabicFont(prefs.getString(arabicFontKey)),
        showQuranBanglaTranslation: prefs.getBool(quranTranslationKey) ?? true,
        readerLineSpacing: validReaderLineSpacing(
          prefs.getDouble(readerLineSpacingKey),
        ),
      );
    } catch (_) {
      // A blocked local storage provider never stops the app from opening.
    }
  }

  static SukunAccentPalette parseAccentPalette(String? name) {
    for (final option in SukunAccentPalette.values) {
      if (option.name == name) return option;
    }
    return SukunAccentPalette.sukunBlue;
  }

  static ArabicReaderFont parseArabicFont(String? name) {
    for (final font in ArabicReaderFont.values) {
      if (font.name == name) return font;
    }
    return ArabicReaderFont.amiriQuran;
  }

  static double validReaderLineSpacing(double? value) =>
      value != null && value.isFinite && value >= 0.9 && value <= 1.4
      ? value
      : 1.0;

  Future<void> setAccentPalette(SukunAccentPalette palette) async {
    value = value.copyWith(accentPalette: palette);
    await _persist(paletteKey, palette.name);
  }

  static double validBengaliScale(double? scale) =>
      scale != null && scale.isFinite && scale >= 0.85 && scale <= 1.4
      ? scale
      : 1.0;

  static double validArabicScale(double? scale) =>
      scale != null && scale.isFinite && scale >= 0.85 && scale <= 1.6
      ? scale
      : 1.0;

  Future<void> setArabicFont(ArabicReaderFont font) async {
    value = value.copyWith(arabicFont: font);
    await _persist(arabicFontKey, font.name);
  }

  Future<void> setShowQuranBanglaTranslation(bool enabled) async {
    value = value.copyWith(showQuranBanglaTranslation: enabled);
    await _persist(quranTranslationKey, enabled);
  }

  void previewReaderLineSpacing(double spacing) {
    value = value.copyWith(readerLineSpacing: validReaderLineSpacing(spacing));
  }

  Future<void> setReaderLineSpacing(double spacing) async {
    value = value.copyWith(readerLineSpacing: validReaderLineSpacing(spacing));
    await _persist(readerLineSpacingKey, value.readerLineSpacing);
  }

  Future<void> resetReaderPreferences() async {
    await setBengaliScale(1.0);
    await setArabicScale(1.0);
    await setReaderLineSpacing(1.0);
    await setArabicFont(ArabicReaderFont.amiriQuran);
    await setShowQuranBanglaTranslation(true);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    value = value.copyWith(themeMode: mode);
    await _persist(themeKey, mode.name);
  }

  /// Update the reader immediately while a slider is being dragged.
  /// Persist only on release to avoid writing to storage on every frame.
  void previewBengaliScale(double scale) {
    value = value.copyWith(bengaliScale: validBengaliScale(scale));
  }

  void previewArabicScale(double scale) {
    value = value.copyWith(arabicScale: validArabicScale(scale));
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
      } else if (value is bool) {
        await prefs.setBool(key, value);
      }
    } catch (_) {
      // Apply instantly in this session and retry persistence next change.
    }
  }
}
