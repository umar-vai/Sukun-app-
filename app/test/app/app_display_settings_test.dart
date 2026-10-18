import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';

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

  test('invalid saved appearance values are safely reset', () async {
    SharedPreferences.setMockInitialValues({
      AppDisplaySettings.themeKey: 'unsupported_mode',
      AppDisplaySettings.bengaliKey: 0.1,
      AppDisplaySettings.arabicKey: 10.0,
    });
    await AppDisplaySettings.instance.load();
    expect(AppDisplaySettings.instance.value.themeMode, ThemeMode.system);
    expect(AppDisplaySettings.instance.value.bengaliScale, 1.0);
    expect(AppDisplaySettings.instance.value.arabicScale, 1.0);
  });
}
