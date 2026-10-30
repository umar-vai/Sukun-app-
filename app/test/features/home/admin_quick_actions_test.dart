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
    final sharedLibrary = find.text('লাইব্রেরি খুলুন');
    await tester.scrollUntilVisible(
      sharedLibrary,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(sharedLibrary);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/resources');
    expect(find.text('Shared public resource library'), findsOneWidget);
  });
}
