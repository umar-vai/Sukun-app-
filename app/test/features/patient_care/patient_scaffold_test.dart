import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

void main() {
  testWidgets('patient care subpages use the shared user navigation', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/patient/home',
      routes: [
        GoRoute(
          path: '/patient/home',
          builder: (context, state) => const PatientScaffold(
            title: 'Today',
            selectedIndex: 0,
            body: SizedBox(),
          ),
        ),
        GoRoute(
          path: '/resources',
          builder: (context, state) => const PatientScaffold(
            title: 'Islamic Resources',
            selectedIndex: 2,
            body: Text('Resource content'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('উপকরণ'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/resources');
    expect(find.text('Islamic Resources'), findsOneWidget);
    expect(find.text('Resource content'), findsOneWidget);
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('রুটিন'), findsOneWidget);
    expect(find.text('উপকরণ'), findsOneWidget);
    expect(find.text('অগ্রগতি'), findsOneWidget);
    expect(find.text('অ্যাকাউন্ট'), findsOneWidget);
  });
}
