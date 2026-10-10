import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/features/home/presentation/admin_scaffold.dart';

void main() {
  testWidgets('admin sees sign-out on desktop and stays busy until resolved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _ControllableAdminAuthRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'বের হয়ে যান'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pump();

    expect(fake.signOutCalls, 1);
    expect(find.text('লগআউট হচ্ছে…'), findsOneWidget);
    final action = tester.widget<TextButton>(
      find.byKey(const Key('admin-sign-out')),
    );
    expect(action.onPressed, isNull);
    expect(find.text('Admin content'), findsOneWidget);

    fake.finishSignOut();
    await tester.pumpAndSettle();
    expect(fake.signOutCalls, 1);
    // The router, not the button, reacts to the actual signed-out session.
    expect(find.widgetWithText(TextButton, 'বের হয়ে যান'), findsOneWidget);
  });

  testWidgets('admin sign-out is accessible on a narrow mobile screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _ControllableAdminAuthRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    expect(find.byTooltip('বের হয়ে যান'), findsOneWidget);
    expect(find.byKey(const Key('admin-sign-out')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pump();
    expect(fake.signOutCalls, 1);
    expect(find.byTooltip('লগআউট হচ্ছে…'), findsOneWidget);

    fake.finishSignOut();
    await tester.pumpAndSettle();
  });

  testWidgets('failed admin sign-out keeps the page and offers retry', (
    tester,
  ) async {
    final fake = _ControllableAdminAuthRepository();
    await tester.pumpWidget(_app(fake));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pump();
    fake.failSignOut();
    await tester.pumpAndSettle();

    expect(fake.signOutCalls, 1);
    expect(find.text('Admin content'), findsOneWidget);
    expect(find.text('লগআউট করা যায়নি। আবার চেষ্টা করুন।'), findsOneWidget);

    await tester.tap(find.byKey(const Key('admin-sign-out')));
    await tester.pump();
    expect(fake.signOutCalls, 2);
    fake.finishRetry();
    await tester.pumpAndSettle();
  });
}

Widget _app(AuthRepository auth) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(auth)],
  child: const MaterialApp(
    home: AdminScaffold(
      title: 'QA Admin',
      selectedIndex: 0,
      body: Center(child: Text('Admin content')),
    ),
  ),
);

class _ControllableAdminAuthRepository implements AuthRepository {
  Completer<void> _completion = Completer<void>();
  int signOutCalls = 0;

  void finishSignOut() => _completion.complete();

  void failSignOut() {
    _completion.completeError(StateError('staging connection unavailable'));
  }

  void finishRetry() => _completion.complete();

  @override
  Stream<AppSession> watchSession() => const Stream.empty();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    final request = _completion;
    if (signOutCalls > 1) _completion = Completer<void>();
    await (signOutCalls > 1 ? _completion.future : request.future);
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
