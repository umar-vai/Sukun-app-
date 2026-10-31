import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/features/account/presentation/app_appearance_settings_screen.dart';

void main() {
  for (final width in <double>[320, 390, 768, 1280]) {
    testWidgets('appearance controls fit ${width.round()}px viewport', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await AppDisplaySettings.instance.setThemeMode(ThemeMode.system);
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: AppAppearanceSettingsScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('appearance-theme-system')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('accent-palette-sukunBlue')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('bengali-font-size')),
        160,
      );
      expect(find.byKey(const Key('bengali-font-size')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('arabic-font-size')),
        160,
      );
      expect(find.byKey(const Key('arabic-font-size')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('theme choices immediately update local preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppDisplaySettings.instance.setThemeMode(ThemeMode.system);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(home: AppAppearanceSettingsScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('appearance-theme-dark')));
    await tester.pumpAndSettle();

    expect(AppDisplaySettings.instance.value.themeMode, ThemeMode.dark);
    expect(tester.takeException(), isNull);
    await AppDisplaySettings.instance.setThemeMode(ThemeMode.system);
  });
}
