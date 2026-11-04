import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/app/theme/app_display_settings.dart';
import 'package:sukun_life/core/widgets/reader_settings_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppDisplaySettings.instance.setThemeMode(ThemeMode.system);
    await AppDisplaySettings.instance.resetReaderPreferences();
  });

  testWidgets('Quran gear offers theme, fonts, sizes and translation toggle', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Text('Quran'),
            actions: [
              ReaderSettingsAction(
                showTranslationSwitch: true,
                sourceLines: ['Al Quran Cloud'],
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('reader-settings-gear')), findsOneWidget);
    final gear = tester.widget<IconButton>(
      find.byKey(const Key('reader-settings-gear')),
    );
    expect((gear.icon as Icon).icon, Icons.settings_rounded);
    expect(gear.iconSize, 24);
    expect(gear.style?.backgroundColor?.resolve({}), const Color(0xFF0A70A8));
    expect(gear.style?.foregroundColor?.resolve({}), Colors.white);
    expect(
      tester.getSize(find.byKey(const Key('reader-settings-gear'))),
      const Size(48, 48),
    );
    await tester.tap(find.byKey(const Key('reader-settings-gear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-settings-panel')), findsOneWidget);
    expect(find.text('পাঠের সেটিংস'), findsOneWidget);
    expect(find.byKey(const Key('reader-bangla-translation')), findsOneWidget);
    expect(find.byKey(const Key('reader-theme-dark')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reader-bangla-translation')));
    await tester.pumpAndSettle();
    expect(
      AppDisplaySettings.instance.value.showQuranBanglaTranslation,
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('reader-bengali-size')),
      220,
    );
    expect(find.byKey(const Key('reader-bengali-size')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('reader-arabic-font-notoNaskhArabic')),
      220,
    );
    await tester.tap(
      find.byKey(const Key('reader-arabic-font-notoNaskhArabic')),
    );
    await tester.pumpAndSettle();
    expect(
      AppDisplaySettings.instance.value.arabicFont,
      ArabicReaderFont.notoNaskhArabic,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('reader-reset-preferences')),
      220,
    );
    // Provider metadata is retained in source records, never displayed as
    // an unwanted extra dropdown inside the reading settings sheet.
    expect(find.byKey(const Key('reader-source-credits')), findsNothing);
    expect(find.text('উৎস ও স্বত্বের তথ্য'), findsNothing);
    expect(find.text('Al Quran Cloud'), findsNothing);
    await tester.tap(find.byKey(const Key('reader-reset-preferences')));
    await tester.pumpAndSettle();
    expect(
      AppDisplaySettings.instance.value.showQuranBanglaTranslation,
      isTrue,
    );
    expect(
      AppDisplaySettings.instance.value.arabicFont,
      ArabicReaderFont.amiriQuran,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings gear contrast survives light and dark AppBars', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            appBar: AppBar(actions: const [ReaderSettingsAction()]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gear = tester.widget<IconButton>(
        find.byKey(const Key('reader-settings-gear')),
      );
      expect(gear.style?.foregroundColor?.resolve({}), Colors.white);
      expect(gear.style?.backgroundColor?.resolve({}), const Color(0xFF0A70A8));
      expect(gear.style?.side?.resolve({})?.width, 1.5);
      expect(
        tester.getSize(find.byKey(const Key('reader-settings-gear'))),
        const Size(48, 48),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-Quran readers do not show a translation switch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [ReaderSettingsAction(pdfDocument: true)]),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('reader-settings-gear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reader-bangla-translation')), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('PDF-এর ভেতরের ফন্ট'),
      220,
    );
    expect(find.textContaining('PDF-এর ভেতরের ফন্ট'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
