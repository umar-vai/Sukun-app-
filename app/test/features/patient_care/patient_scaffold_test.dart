import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

void main() {
  testWidgets('patient resources deep link remains usable without bottom tab', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/resources',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PatientScaffold(
            title: 'Home',
            selectedIndex: 0,
            body: Text('Home resources grid'),
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

    expect(find.text('Islamic Resources'), findsOneWidget);
    expect(find.text('Resource content'), findsOneWidget);
    expect(find.text('হোম'), findsOneWidget);
    expect(find.text('রুটিন'), findsOneWidget);
    expect(find.text('অগ্রগতি'), findsOneWidget);
    expect(find.text('অ্যাকাউন্ট'), findsOneWidget);
    expect(find.text('উপকরণ'), findsNothing);

    await tester.tap(find.text('হোম'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Home resources grid'), findsOneWidget);
  });
}
