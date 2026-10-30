import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/home/presentation/role_home_screens.dart';

void main() {
  testWidgets('admin can start adding a patient directly from the dashboard', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminHomeScreen(),
        ),
        GoRoute(
          path: '/admin/patients/new',
          builder: (context, state) =>
              const Scaffold(body: Text('Create patient destination')),
        ),
        GoRoute(
          path: '/admin/patients',
          builder: (context, state) =>
              const Scaffold(body: Text('Patient list destination')),
        ),
        GoRoute(
          path: '/admin/content',
          builder: (context, state) =>
              const Scaffold(body: Text('Content destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('দ্রুত কাজ শুরু করুন'), findsOneWidget);
    await tester.tap(find.text('নতুন রোগী যোগ করুন'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/admin/patients/new',
    );
    expect(find.text('Create patient destination'), findsOneWidget);
  });
  testWidgets('admin opens the same public resource library as members', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminHomeScreen(),
        ),
        GoRoute(
          path: '/resources',
          builder: (context, state) =>
              const Scaffold(body: Text('Shared public resource library')),
        ),
        GoRoute(
          path: '/admin/patients',
          builder: (context, state) =>
              const Scaffold(body: Text('Patient list')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final sharedLibrary = find.text('সবার লাইব্রেরি');
    await tester.ensureVisible(sharedLibrary);
    await tester.pumpAndSettle();
    await tester.tap(sharedLibrary);
    await tester.pumpAndSettle();
    // go_router.push adds an imperative page while the route information
    // provider can retain the underlying dashboard URI.
    expect(find.text('Shared public resource library'), findsOneWidget);
  });
  testWidgets('admin can navigate to user progress and routine delegation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminHomeScreen(),
        ),
        GoRoute(
          path: '/admin/user-routines',
          builder: (context, state) =>
              const Scaffold(body: Text('Admin user routines destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ব্যবহারকারীর রুটিন ও অগ্রগতি'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/admin/user-routines',
    );
    expect(find.text('Admin user routines destination'), findsOneWidget);
  });
}
