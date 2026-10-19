import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/app/theme/sukun_accent_palette.dart';
import 'package:sukun_life/features/account/presentation/app_appearance_settings_screen.dart';

void main() {
  testWidgets('theme choice is actionable and changes immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await AppDisplaySettings.instance.setAccentPalette(
      SukunAccentPalette.sukunBlue,
    );
    await tester.pumpWidget(
      const MaterialApp(home: AppAppearanceSettingsScreen()),
    );
    expect(find.byKey(const Key('accent-palette-sukunBlue')), findsOneWidget);
    expect(find.byKey(const Key('accent-palette-calmTeal')), findsOneWidget);
    expect(
      find.byKey(const Key('accent-palette-twilightPlum')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('accent-palette-calmTeal')));
    await tester.pump();
    expect(
      AppDisplaySettings.instance.value.accentPalette,
      SukunAccentPalette.calmTeal,
    );
    await AppDisplaySettings.instance.setAccentPalette(
      SukunAccentPalette.sukunBlue,
    );
  });
}
