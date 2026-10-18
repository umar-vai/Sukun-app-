import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/app/router/role_navigation_shell.dart';
import 'package:sukun_life/app/router/shared_user_navigation.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/user_role.dart';

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
    expect(navigationIndex('/resources/ruqyah', patient), 0);
    expect(showsNavigationShell('/patient/resources'), isFalse);
    expect(showsNavigationShell('/admin/dashboard'), isFalse);
    expect(showsNavigationShell('/admin/announcements/new'), isTrue);
    expect(showsNavigationShell('/patient/notifications'), isTrue);
    expect(showsNavigationShell('/resources/quran/2'), isTrue);
  });

  test('Member and Patient have identical primary navigation', () {
    const member = AppSession(role: UserRole.member, userId: 'member');
    const patient = AppSession(role: UserRole.patient, userId: 'patient');
    const admin = AppSession(role: UserRole.superAdmin, userId: 'admin');
    expect(sharedUserRoutes, ['/', '/my-routines', '/progress', '/account']);
    expect(sharedUserDestinations.length, 4);
    expect(
      sharedUserDestinations.any((destination) => destination.label == 'উপকরণ'),
      isFalse,
    );
    for (final path in sharedUserRoutes) {
      expect(navigationIndex(path, member), navigationIndex(path, patient));
    }
    expect(navigationIndex('/my-routines/action/a', patient), 1);
    expect(navigationIndex('/patient/plan', patient), 1);
    expect(navigationIndex('/patient/progress', patient), 2);
    expect(navigationIndex('/resources/audio', member), 0);
    expect(navigationIndex('/account', member), 3);
    expect(navigationIndex('/admin/announcements/new', admin), 3);
    expect(navigationParent('/my-routines/action/a', member), '/my-routines');
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
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsOneWidget);
    expect(find.byKey(const Key('navigation-back')), findsOneWidget);
    expect(find.byKey(const Key('navigation-home')), findsOneWidget);
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
}
