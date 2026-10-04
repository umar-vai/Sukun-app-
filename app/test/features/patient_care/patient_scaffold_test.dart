import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patient_care/presentation/patient_scaffold.dart';

void main() {
  testWidgets('resources destination stays in the patient navigation shell', (
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
          path: '/patient/resources',
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
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/patient/resources',
    );
    expect(find.text('Islamic Resources'), findsOneWidget);
    expect(find.text('Resource content'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('My Plan'), findsOneWidget);
    expect(find.text('Resources'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
