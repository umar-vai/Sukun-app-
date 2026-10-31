import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/account/presentation/unified_account_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'public-test-key',
    );
  });

  Future<GoRouter> showAccount(
    WidgetTester tester, {
    required UserRole role,
    required Size size,
  }) async {
    await tester.binding.setSurfaceSize(size);
    final router = GoRouter(
      initialLocation: '/account',
      routes: [
        GoRoute(
          path: '/account',
          builder: (context, state) => const UnifiedAccountScreen(),
        ),
        for (final path in <String>[
          '/my-media',
          '/my-routines',
          '/progress',
          '/announcements',
          '/settings/appearance',
          '/settings/notifications',
          '/patient/plan',
          '/patient/profile',
        ])
          GoRoute(
            path: path,
            builder: (context, state) =>
                Scaffold(body: Text('Destination: ${state.uri.path}')),
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession(
                role: role,
                userId: 'synthetic-account-user',
                displayName: 'দীর্ঘ পরীক্ষামূলক নাম',
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final width in <double>[320, 390, 768, 1280]) {
    testWidgets('Member account has no overflow at width ${width.round()}', (
      tester,
    ) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final router = await showAccount(
        tester,
        role: UserRole.member,
        size: Size(width, 720),
      );
      addTearDown(router.dispose);

      expect(find.text('আমার কার্যক্রম'), findsOneWidget);
      expect(find.byKey(const Key('account-audio-library')), findsOneWidget);
      await tester.scrollUntilVisible(find.text('পছন্দ ও সেটিংস'), 220);
      expect(find.text('পছন্দ ও সেটিংস'), findsOneWidget);
      expect(find.text('আমার যত্ন'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('account preference entry opens actual appearance route', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await showAccount(
      tester,
      role: UserRole.member,
      size: const Size(320, 640),
    );
    addTearDown(router.dispose);

    final appearance = find.byKey(const Key('account-appearance'));
    await tester.ensureVisible(appearance);
    await tester.pumpAndSettle();
    await tester.tap(appearance);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/settings/appearance',
    );
    expect(find.text('Destination: /settings/appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Patient account keeps owner-only care destinations', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await showAccount(
      tester,
      role: UserRole.patient,
      size: const Size(390, 720),
    );
    addTearDown(router.dispose);

    expect(find.text('রোগী অ্যাকাউন্ট'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('আমার যত্ন'), 220);
    expect(find.text('আমার যত্ন'), findsOneWidget);
    expect(find.text('আমার চিকিৎসা পরিকল্পনা'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
