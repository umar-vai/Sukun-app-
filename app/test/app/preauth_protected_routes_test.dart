import 'dart:async';

import 'package:flutter/material.dart';

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

  testWidgets('unresolved identity can retain public my-media deep link', (
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
    router.go('/my-media');
    await tester.pump(const Duration(milliseconds: 150));

    expect(router.routeInformationProvider.value.uri.path, '/my-media');
    expect(find.text('রোগীর তালিকা'), findsNothing);
  });

  testWidgets('Guest can open all public 40-day challenge stages without login', (
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
    router.go('/challenge/40-day');
    await tester.pump(const Duration(milliseconds: 150));

    expect(router.routeInformationProvider.value.uri.path, '/challenge/40-day');
    expect(find.text('জাদু থেকে সুরক্ষার চ্যালেঞ্জ'), findsOneWidget);
    expect(find.byKey(const Key('challenge-login')), findsOneWidget);
    expect(find.byKey(const Key('challenge-stage-5')), findsOneWidget);
    expect(find.byKey(const Key('challenge-progress')), findsNothing);
  });

  testWidgets('unresolved identity cannot open private notification settings', (
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
    router.go('/settings/notifications');
    await tester.pump(const Duration(milliseconds: 150));
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.text('নোটিফিকেশন স্বাস্থ্য পরীক্ষা'), findsNothing);
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

  testWidgets('expired Patient session denies restored clinical deep links', (
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
    changes.add(
      const AppSession(
        role: UserRole.patient,
        userId: 'synthetic-patient-a',
        requiresCredentialChange: true,
      ),
    );
    await tester.pumpAndSettle();

    var router = container.read(appRouterProvider);
    router.go('/patient/change-password');
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/patient/change-password',
    );

    // Simulate an expired/rejected session or verified Supabase sign-out event.
    // No previously authorized screen can survive the new guest identity.
    changes.add(const AppSession.guest());
    await tester.pumpAndSettle();

    router = container.read(appRouterProvider);
    router.go('/patient/change-password');
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/login',
    );
    expect(tester.takeException(), isNull);
  });
}
