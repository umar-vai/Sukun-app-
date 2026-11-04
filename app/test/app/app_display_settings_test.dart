import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('system default and independent reading sizes persist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppDisplaySettings.instance;
    await prefs.setThemeMode(ThemeMode.dark);
    await prefs.setBengaliScale(1.2);
    await prefs.setArabicScale(1.5);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(AppDisplaySettings.themeKey), 'dark');
    expect(stored.getDouble(AppDisplaySettings.bengaliKey), 1.2);
    expect(stored.getDouble(AppDisplaySettings.arabicKey), 1.5);
    expect(prefs.value.bengaliScale, 1.2);
    expect(prefs.value.arabicScale, 1.5);
    await prefs.setThemeMode(ThemeMode.system);
    await prefs.setBengaliScale(1.0);
    await prefs.setArabicScale(1.0);
  });

  test(
    'drag preview is immediate but never persisted before release',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppDisplaySettings.instance;
      await settings.setBengaliScale(1.0);
      await settings.setArabicScale(1.0);
      settings.previewBengaliScale(1.3);
      settings.previewArabicScale(1.4);
      expect(settings.value.bengaliScale, 1.3);
      expect(settings.value.arabicScale, 1.4);
      final stored = await SharedPreferences.getInstance();
      expect(stored.getDouble(AppDisplaySettings.bengaliKey), 1.0);
      expect(stored.getDouble(AppDisplaySettings.arabicKey), 1.0);
      await settings.setBengaliScale(1.3);
      await settings.setArabicScale(1.4);
      expect(stored.getDouble(AppDisplaySettings.bengaliKey), 1.3);
      expect(stored.getDouble(AppDisplaySettings.arabicKey), 1.4);
      await settings.setBengaliScale(1.0);
      await settings.setArabicScale(1.0);
    },
  );

  test('reader Arabic font, line spacing and Quran Bangla toggle persist', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppDisplaySettings.instance;
    await settings.setArabicFont(ArabicReaderFont.notoNaskhArabic);
    await settings.setShowQuranBanglaTranslation(false);
    await settings.setReaderLineSpacing(1.25);
    final stored = await SharedPreferences.getInstance();
    expect(
      stored.getString(AppDisplaySettings.arabicFontKey),
      'notoNaskhArabic',
    );
    expect(
      stored.getBool(AppDisplaySettings.quranTranslationKey),
      isFalse,
    );
    expect(stored.getDouble(AppDisplaySettings.readerLineSpacingKey), 1.25);
    await settings.load();
    expect(settings.value.arabicFont, ArabicReaderFont.notoNaskhArabic);
    expect(settings.value.showQuranBanglaTranslation, isFalse);
    expect(settings.value.readerLineSpacing, 1.25);
    await settings.resetReaderPreferences();
    expect(settings.value.showQuranBanglaTranslation, isTrue);
    expect(settings.value.arabicFont, ArabicReaderFont.amiriQuran);
  });

  test('unrecognized reader font and spacing use safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      AppDisplaySettings.arabicFontKey: 'unsupported',
      AppDisplaySettings.quranTranslationKey: false,
      AppDisplaySettings.readerLineSpacingKey: 14.0,
    });
    await AppDisplaySettings.instance.load();
    expect(AppDisplaySettings.instance.value.arabicFont,
        ArabicReaderFont.amiriQuran);
    expect(AppDisplaySettings.instance.value.readerLineSpacing, 1.0);
    expect(AppDisplaySettings.instance.value.showQuranBanglaTranslation, isFalse);
    await AppDisplaySettings.instance.resetReaderPreferences();
  });

  test('accent theme choice persists and unknown values fail safe', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppDisplaySettings.instance;
    await settings.setAccentPalette(SukunAccentPalette.calmTeal);
    final stored = await SharedPreferences.getInstance();
    expect(stored.getString(AppDisplaySettings.paletteKey), 'calmTeal');
    expect(settings.value.accentPalette, SukunAccentPalette.calmTeal);
    expect(
      AppDisplaySettings.parseAccentPalette('unrecognized'),
      SukunAccentPalette.sukunBlue,
    );
    await settings.setAccentPalette(SukunAccentPalette.sukunBlue);
  });

  test('invalid saved appearance values are safely reset', () async {
    SharedPreferences.setMockInitialValues({
      AppDisplaySettings.themeKey: 'unsupported_mode',
      AppDisplaySettings.paletteKey: 'invalid_palette',
      AppDisplaySettings.bengaliKey: 0.1,
      AppDisplaySettings.arabicKey: 10.0,
    });
    await AppDisplaySettings.instance.load();
    expect(AppDisplaySettings.instance.value.themeMode, ThemeMode.system);
    expect(
      AppDisplaySettings.instance.value.accentPalette,
      SukunAccentPalette.sukunBlue,
    );
    expect(AppDisplaySettings.instance.value.bengaliScale, 1.0);
    expect(AppDisplaySettings.instance.value.arabicScale, 1.0);
  });
}
