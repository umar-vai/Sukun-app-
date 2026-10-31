import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/patients/presentation/admin_all_users_screen.dart';

void main() {
  testWidgets('tapping a user opens that user\'s routine and progress', (
    tester,
  ) async {
    const userId = 'a03d5e31-e02b-4601-a4d2-111111111111';
    final router = GoRouter(
      initialLocation: '/admin/users',
      routes: [
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => Scaffold(
            body: AdminUserDirectoryTile(
              user: const {
                'id': userId,
                'display_name': 'Test Member',
              },
              onOpen: () => context.go(
                '/admin/user-routines?userId=${Uri.encodeComponent(userId)}',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/admin/user-routines',
          builder: (context, state) => Scaffold(
            body: Text(state.uri.queryParameters['userId'] ?? 'Missing user'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('admin-user-$userId')), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.text('Test Member'));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/admin/user-routines',
    );
    expect(find.text(userId), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a profile without an id cannot open another user', (
    tester,
  ) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserDirectoryTile(
            user: const {'display_name': 'Unknown'},
            onOpen: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unknown'), warnIfMissed: false);
    expect(opened, isFalse);
  });
}
