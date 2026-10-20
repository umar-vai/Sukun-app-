import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/app.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/user_role.dart';

void main() {
  testWidgets(
    'failed restored session shows retry and recovers without logout',
    (tester) async {
      final auth = _FailThenRecoverAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(auth)],
          child: const SukunLifeApp(),
        ),
      );
      await tester.pump();
      auth.failInitialLookup();
      await tester.pumpAndSettle();

      expect(find.text('এই মুহূর্তে কাজটি করা যাচ্ছে না'), findsOneWidget);
      expect(find.text('আবার চেষ্টা করুন'), findsOneWidget);
      expect(find.textContaining('অ্যাকাউন্টের তথ্য যাচাই'), findsOneWidget);
      expect(find.textContaining('private SQL token'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'আবার চেষ্টা করুন'));
      await tester.pumpAndSettle();

      expect(auth.watchCalls, greaterThanOrEqualTo(2));
      expect(find.text('আসসালামু আলাইকুম, QA Member'), findsOneWidget);
      expect(find.text('এই মুহূর্তে কাজটি করা যাচ্ছে না'), findsNothing);
      expect(auth.signOutCalls, 0);
    },
  );

  testWidgets('error offers safe re-login without automatic sign-out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = _FailThenRecoverAuthRepository();
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const SukunLifeApp(),
      ),
    );
    await tester.pump();
    auth.failInitialLookup();
    await tester.pumpAndSettle();

    expect(find.text('আবার লগইন করুন'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('আবার লগইন করুন')).dy,
      lessThanOrEqualTo(667),
    );
    expect(find.textContaining('S-CLIENT-04'), findsOneWidget);
    await tester.tap(find.text('আবার লগইন করুন'));
    await tester.pumpAndSettle();

    expect(find.text('অ্যাকাউন্টে প্রবেশ'), findsOneWidget);
    expect(auth.signOutCalls, 0);
  });
}

final class _FailThenRecoverAuthRepository implements AuthRepository {
  final StreamController<AppSession> _first =
      StreamController<AppSession>.broadcast(sync: true);

  int watchCalls = 0;
  int signOutCalls = 0;

  void failInitialLookup() =>
      _first.addError(StateError('private SQL token - never display'));

  Future<void> dispose() => _first.close();

  @override
  Stream<AppSession> watchSession() {
    watchCalls++;
    if (watchCalls == 1) return _first.stream;
    return Stream.value(
      const AppSession(
        role: UserRole.member,
        userId: 'synthetic-member',
        displayName: 'QA Member',
      ),
    );
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
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
