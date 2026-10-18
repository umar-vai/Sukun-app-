import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/public_welcome_screen.dart';

void main() {
  test('Android download requires an HTTPS release URL', () {
    expect(approvedAndroidApkUri(''), isNull);
    expect(approvedAndroidApkUri('http://example.com/app.apk'), isNull);
    expect(approvedAndroidApkUri('javascript:alert(1)'), isNull);
    expect(
      approvedAndroidApkUri('https://downloads.example.com/app.apk')?.host,
      'downloads.example.com',
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
            path: '/resources/ruqyah',
            builder: (_, _) => const Text('Ruqyah route'),
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
      expect(find.text('Android অ্যাপ শীঘ্রই'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('রুকইয়াহ রিসোর্স দেখুন'), 500);
      await tester.pumpAndSettle();
      await tester.tap(find.text('রুকইয়াহ রিসোর্স দেখুন'));
      await tester.pumpAndSettle();
      expect(find.text('Ruqyah route'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.text('লগইন'));
      await tester.pumpAndSettle();
      expect(find.text('Login route'), findsOneWidget);
    });
  }
}
