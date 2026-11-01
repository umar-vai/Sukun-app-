import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/resources/domain/resource_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-in member logout waits for Supabase before guest state', (
    tester,
  ) async {
    final fake = _ControllableAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();
    fake.emit(
      const AppSession(
        role: UserRole.member,
        userId: 'synthetic-member',
        displayName: 'QA Member',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('আসসালামু আলাইকুম, QA Member'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'লগআউট'));
    await tester.pump();
    expect(fake.signOutCalls, 1);
    expect(find.text('লগআউট হচ্ছে…'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'লগআউট'), findsNothing);
    expect(find.text('আসসালামু আলাইকুম, QA Member'), findsOneWidget);

    fake.finishSignOut();
    await tester.pumpAndSettle();
    expect(find.text('আসসালামু আলাইকুম, QA Member'), findsNothing);
    expect(find.widgetWithText(TextButton, 'লগইন'), findsOneWidget);
  });

  testWidgets('failed member sign-out keeps session and shows retry feedback', (
    tester,
  ) async {
    final fake = _ControllableAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();
    fake.emit(
      const AppSession(
        role: UserRole.member,
        userId: 'synthetic-member',
        displayName: 'QA Member',
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'লগআউট'));
    await tester.pump();
    fake.failSignOut();
    await tester.pumpAndSettle();

    expect(find.text('আসসালামু আলাইকুম, QA Member'), findsOneWidget);
    expect(find.text('লগআউট করা যায়নি। আবার চেষ্টা করুন।'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'লগআউট'), findsOneWidget);
  });

  testWidgets('member dashboard stays readable in wide desktop viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _ControllableAuthRepository();
    addTearDown(fake.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();
    fake.emit(
      const AppSession(role: UserRole.member, userId: 'synthetic-member'),
    );
    await tester.pumpAndSettle();

    final width = tester
        .getSize(find.byKey(const Key('public-home-content-width')))
        .width;
    expect(width, lessThanOrEqualTo(1140));
    expect(find.text('আপনার প্রতিদিনের সুকুন'), findsOneWidget);
    expect(find.text('নামাজের সময়'), findsOneWidget);
    expect(find.byKey(const Key('home-forty-day-challenge')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('universal-announcements-shortcut')),
        matching: find.text('নোটিশ'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-compact-prayer')), findsOneWidget);
    expect(
      find.byKey(const Key('home-prayer-location-action')),
      findsOneWidget,
    );
    expect(resourceSections.length, 8);
    for (final section in resourceSections) {
      expect(
        find.byKey(Key('home-resource-${section.slug}')),
        findsOneWidget,
        reason: 'Home must expose the canonical ${section.slug} section',
      );
    }
  });
}

final class _ControllableAuthRepository implements AuthRepository {
  final _changes = StreamController<AppSession>.broadcast(sync: true);
  final _completion = Completer<void>();
  int signOutCalls = 0;

  void emit(AppSession session) => _changes.add(session);

  void finishSignOut() => _completion.complete();

  void failSignOut() =>
      _completion.completeError(StateError('staging network unavailable'));

  Future<void> dispose() => _changes.close();

  @override
  Stream<AppSession> watchSession() => _changes.stream;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await _completion.future;
    emit(const AppSession.guest());
  }

  @override
  Future<void> signIn({required String identifier, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => throw UnimplementedError();
}
