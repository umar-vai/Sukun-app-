import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/public_welcome_screen.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';

void main() {
  test('Android download requires an HTTPS release URL', () {
    expect(approvedAndroidApkUri(''), isNull);
    expect(approvedAndroidApkUri('http://example.com/app.apk'), isNull);
    expect(approvedAndroidApkUri('javascript:alert(1)'), isNull);
    expect(
      approvedAndroidApkUri(
        'https://downloads.sukunlife.com/android/1.0.1/SukunLife.apk',
      )?.host,
      'downloads.sukunlife.com',
    );
    // Without an approved override the stable "latest" link is used.
    expect(publicAndroidDownloadUri('').toString(), publicAndroidApkLink);
    expect(
      publicAndroidDownloadUri('https://downloads.example.com/app.apk'),
      Uri.parse(publicAndroidApkLink),
    );
    expect(
      publicAndroidApkLink,
      endsWith('/releases/latest/download/SukunLife.apk'),
    );
    expect(
      approvedAndroidApkUri('https://downloads.example.com/app.apk'),
      isNull,
    );
  });

  for (final size in const [Size(360, 640), Size(1140, 900)]) {
    testWidgets('welcome page stays usable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const PublicWelcomeScreen()),
          GoRoute(path: '/login', builder: (_, _) => const Text('Login route')),
          GoRoute(
            path: '/resources',
            builder: (_, _) => const Text('Resources route'),
          ),
          GoRoute(
            path: '/announcements',
            builder: (_, _) => const Text('Notices route'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(
        find.text('যত্ন, চর্চা ও প্রশান্তির পথে সুকুন লাইফ'),
        findsOneWidget,
      );
      final download = find.byKey(const Key('welcome-download-android'));
      expect(download, findsOneWidget);
      expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
      expect(find.text('ইনস্টল করবেন যেভাবে'), findsOneWidget);
      expect(find.text(publicAndroidApkLink), findsOneWidget);
      expect(tester.takeException(), isNull);
      final loginButton = find.widgetWithText(OutlinedButton, 'লগইন');
      await tester.ensureVisible(loginButton);
      await tester.pumpAndSettle();
      await tester.tap(loginButton);
      await tester.pumpAndSettle();
      expect(find.text('Login route'), findsOneWidget);
    });
  }

  testWidgets('copy button puts the share link on the clipboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1140, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PublicWelcomeScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-copy-link')));
    await tester.pumpAndSettle();
    expect(copied, publicAndroidApkLink);
    expect(find.text('ডাউনলোড লিংক কপি হয়েছে।'), findsOneWidget);
  });

  testWidgets('Guest light surfaces remain readable in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const PublicWelcomeScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: ThemeData.dark(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    final sectionTitle = tester.widget<Text>(find.text('সুকুন লাইফে যা পাবেন'));
    expect(sectionTitle.style?.color, SukunColors.nightNavy);

    final whiteCardTitle = tester.widget<Text>(find.text('ইসলামিক পাঠ ও অডিও'));
    expect(whiteCardTitle.style?.color, SukunColors.nightNavy);

    final downloadButton = tester.widget<FilledButton>(
      find.byKey(const Key('welcome-download-android')),
    );
    expect(
      downloadButton.style?.backgroundColor?.resolve({}),
      SukunColors.sukunBlue,
    );
    expect(tester.takeException(), isNull);
  });
}
