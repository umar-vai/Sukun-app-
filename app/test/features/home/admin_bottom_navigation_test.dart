import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/core/widgets/brand_logo.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

void main() {
  testWidgets('selected Users tab returns from routine detail to user list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: '/admin/user-routines',
      routes: [
        GoRoute(
          path: '/admin/user-routines',
          builder: (context, state) => const AdminScaffold(
            title: 'ব্যবহারকারী ও রুটিন',
            selectedIndex: 1,
            body: Center(child: Text('Routine detail')),
          ),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const AdminScaffold(
            title: 'সকল ব্যবহারকারী',
            selectedIndex: 1,
            body: Center(child: Text('User directory')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(SukunBottomNavigation), findsOneWidget);
    await tester.tap(find.text('রোগী'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/admin/users');
    expect(find.text('User directory'), findsOneWidget);
    expect(find.byType(SukunBottomNavigation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every admin page shows the logo and an Account tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminScaffold(
            title: 'Dashboard',
            selectedIndex: 0,
            body: Center(child: Text('Dashboard body')),
          ),
        ),
        GoRoute(
          path: '/admin/account',
          builder: (context, state) => const AdminScaffold(
            title: 'Account',
            selectedIndex: AdminScaffold.accountIndex,
            body: Center(child: Text('Account body')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(SukunLifeLogo), findsOneWidget);
    final nav = tester.widget<SukunBottomNavigation>(
      find.byType(SukunBottomNavigation),
    );
    expect(nav.destinations, hasLength(5));
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/admin/account');
    expect(find.text('Account body'), findsOneWidget);
  });
}
