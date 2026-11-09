import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/auth_providers.dart';
import 'package:sukun_life/core/auth/auth_repository.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/account/presentation/unified_account_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'public-test-key',
    );
  });

  Future<_CountingAuth> show(WidgetTester tester, UserRole role) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = _CountingAuth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          appSessionProvider.overrideWith(
            (ref) => Stream.value(
              AppSession(role: role, userId: 'u-1', displayName: 'আমিনা'),
            ),
          ),
        ],
        child: const MaterialApp(home: UnifiedAccountScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('profile card shows the initial and account type', (
    tester,
  ) async {
    await show(tester, UserRole.member);
    expect(find.byKey(const Key('account-profile-card')), findsOneWidget);
    expect(find.text('আ'), findsOneWidget);
    expect(find.text('সদস্য অ্যাকাউন্ট'), findsOneWidget);
  });

  testWidgets('patients see their care section before everything else', (
    tester,
  ) async {
    await show(tester, UserRole.patient);
    final care = tester.getTopLeft(find.text('আমার যত্ন')).dy;
    final daily = tester.getTopLeft(find.text('আমার কার্যক্রম')).dy;
    expect(care, lessThan(daily));
  });

  testWidgets('sign out asks first and staying keeps the session', (
    tester,
  ) async {
    final auth = await show(tester, UserRole.member);
    await tester.ensureVisible(find.byKey(const Key('account-sign-out')));
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('লগআউট করবেন?'), findsOneWidget);
    await tester.tap(find.text('থাকুন'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 0);

    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'লগআউট'));
    await tester.pumpAndSettle();
    expect(auth.signOutCalls, 1);
  });
}

final class _CountingAuth implements AuthRepository {
  int signOutCalls = 0;

  @override
  Future<void> signOut() async => signOutCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
