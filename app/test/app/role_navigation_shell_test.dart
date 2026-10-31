import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/router/role_navigation_shell.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

void main() {
  test('deep links have a safe parent for each role', () {
    const patient = AppSession(role: UserRole.patient, userId: 'patient');
    const admin = AppSession(role: UserRole.superAdmin, userId: 'admin');
    expect(navigationParent('/resources/quran/2', patient), '/resources/quran');
    expect(navigationParent('/resources/audio', patient), '/patient/resources');
    expect(
      navigationParent('/admin/patients/123/plans/new', admin),
      '/admin/patients/123',
    );
    expect(
      navigationParent('/admin/patients/123/plans/plan-1/preview', admin),
      '/admin/patients/123/plans/plan-1',
    );
    expect(
      navigationParent('/admin/announcements/new', admin),
      '/admin/announcements',
    );
    expect(navigationParent('/prayer-times', null), '/');
    expect(navigationIndex('/admin/announcements/new', admin), 3);
    expect(navigationIndex('/admin/users', admin), 1);
    expect(navigationIndex('/admin/user-routines', admin), 1);
    expect(navigationIndex('/admin/library', admin), 2);
    expect(navigationIndex('/resources/ruqyah', patient), 2);
    expect(showsNavigationShell('/patient/resources'), isFalse);
    expect(showsNavigationShell('/admin/dashboard'), isFalse);
    expect(showsNavigationShell('/admin/users'), isFalse);
    expect(showsNavigationShell('/admin/user-routines'), isFalse);
    expect(showsNavigationShell('/admin/library'), isFalse);
    expect(showsNavigationShell('/admin/announcements/new'), isTrue);
    expect(showsNavigationShell('/patient/notifications'), isTrue);
    expect(showsNavigationShell('/resources/quran/2'), isTrue);
  });

  test('Member and Patient have identical primary navigation', () {
    const member = AppSession(role: UserRole.member, userId: 'member');
    const patient = AppSession(role: UserRole.patient, userId: 'patient');
    const admin = AppSession(role: UserRole.superAdmin, userId: 'admin');
    expect(sharedUserRoutes, ['/', '/my-routines', '/resources', '/account']);
    expect(sharedUserDestinations.length, 4);
    expect(
      sharedUserDestinations.any((destination) => destination.label == 'উপকরণ'),
      isTrue,
    );
    for (final path in sharedUserRoutes) {
      expect(navigationIndex(path, member), navigationIndex(path, patient));
    }
    expect(navigationIndex('/my-routines/action/a', patient), 1);
    expect(navigationIndex('/patient/plan', patient), 1);
    expect(navigationIndex('/patient/progress', patient), 1);
    expect(navigationIndex('/resources/audio', member), 2);
    expect(navigationIndex('/account', member), 3);
    expect(navigationIndex('/admin/announcements/new', admin), 3);
    expect(navigationParent('/my-routines/action/a', member), '/my-routines');
  });

  testWidgets('admin primary screens never stack two bottom menus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const admin = AppSession(
      role: UserRole.superAdmin,
      userId: 'synthetic-admin',
    );
    for (final path in <String>[
      '/admin/users',
      '/admin/user-routines',
      '/admin/library',
    ]) {
      final router = GoRouter(
        initialLocation: path,
        routes: [
          ShellRoute(
            builder: (context, state, child) => RoleNavigationShell(
              path: state.uri.path,
              session: admin,
              child: child,
            ),
            routes: [
              for (final destination in <String>[
                '/admin/users',
                '/admin/user-routines',
                '/admin/library',
              ])
                GoRoute(
                  path: destination,
                  builder: (context, state) => AdminScaffold(
                    title: 'Admin',
                    selectedIndex: 1,
                    body: const Center(child: Text('Admin content')),
                  ),
                ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SukunBottomNavigation), findsOneWidget);
      expect(find.byKey(const Key('navigation-home')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });

  testWidgets('guest resource deep link keeps back and home available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/resources/detail',
      routes: [
        ShellRoute(
          builder: (context, state, child) => RoleNavigationShell(
            path: state.uri.path,
            session: const AppSession.guest(),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: Text('Guest home')),
            ),
            GoRoute(
              path: '/resources',
              builder: (context, state) =>
                  const Scaffold(body: Text('Library')),
            ),
            GoRoute(
              path: '/resources/detail',
              builder: (context, state) => const Scaffold(body: Text('Detail')),
            ),
            GoRoute(
              path: '/announcements',
              builder: (context, state) =>
                  const Scaffold(body: Text('Notices')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsOneWidget);
    expect(find.byKey(const Key('navigation-back')), findsOneWidget);
    // The Back action is now inside the same bottom bar (no second
    // Back/Home strip above the navigation).
    expect(find.byKey(const Key('navigation-home')), findsNothing);
    expect(find.byType(SukunBottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('navigation-back')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/resources');
    expect(find.text('Library'), findsOneWidget);
    await tester.tap(find.text('হোম').last);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    router.push('/resources/detail');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-back')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('all authenticated roles keep one accessible resource footer', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final session in <AppSession>[
      const AppSession(role: UserRole.member, userId: 'synthetic-member'),
      const AppSession(role: UserRole.patient, userId: 'synthetic-patient'),
      const AppSession(role: UserRole.superAdmin, userId: 'synthetic-admin'),
    ]) {
      final router = GoRouter(
        initialLocation: '/resources/detail',
        routes: [
          ShellRoute(
            builder: (context, state, child) => RoleNavigationShell(
              path: state.uri.path,
              session: session,
              child: child,
            ),
            routes: [
              GoRoute(
                path: '/resources/detail',
                builder: (context, state) =>
                    const Scaffold(body: Text('Synthetic detail')),
              ),
            ],
          ),
        ],
      );
      for (final width in <double>[360, 430, 1280]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('navigation-back')), findsOneWidget);
        expect(find.byKey(const Key('navigation-home')), findsNothing);
        final footer = tester.widget<SukunBottomNavigation>(
          find.byType(SukunBottomNavigation),
        );
        expect(footer.destinations, hasLength(4));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    }
  });
}
