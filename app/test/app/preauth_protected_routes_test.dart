import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/app/router/app_router.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/user_role.dart';

void main() {
  testWidgets('unresolved session never builds a patient deep link', (
    tester,
  ) async {
    final changes = StreamController<AppSession>.broadcast(sync: true);
    addTearDown(changes.close);
    final container = ProviderContainer(
      overrides: [appSessionProvider.overrideWith((ref) => changes.stream)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();

    final router = container.read(appRouterProvider);
    router.go('/patient/today');
    await tester.pump(const Duration(milliseconds: 150));

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Faith. Care. Peace of mind.'), findsOneWidget);
    expect(find.text('আজকের কাজ'), findsNothing);
  });

  testWidgets('unresolved session never builds an admin deep link', (
    tester,
  ) async {
    final changes = StreamController<AppSession>.broadcast(sync: true);
    addTearDown(changes.close);
    final container = ProviderContainer(
      overrides: [appSessionProvider.overrideWith((ref) => changes.stream)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();

    final router = container.read(appRouterProvider);
    router.go('/admin/patients');
    await tester.pump(const Duration(milliseconds: 150));

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('Faith. Care. Peace of mind.'), findsOneWidget);
    expect(find.text('রোগীর তালিকা'), findsNothing);
  });

  testWidgets('verified member cannot enter patient or admin screens', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appSessionProvider.overrideWith(
          (ref) => Stream.value(
            const AppSession(
              role: UserRole.member,
              userId: 'synthetic-google-member',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SukunLifeApp(),
      ),
    );
    await tester.pumpAndSettle();

    var router = container.read(appRouterProvider);
    router.go('/admin/patients');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');

    router = container.read(appRouterProvider);
    router.go('/patient/today');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('আপনার প্রতিদিনের সুকুন'), findsOneWidget);
  });
}
