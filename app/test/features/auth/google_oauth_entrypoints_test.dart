import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/auth/presentation/login_screen.dart';
import 'package:sukun_life/features/auth/presentation/member_signup_screen.dart';

void main() {
  if (!AppEnvironment.googleOAuthEnabled) {
    test('Google OAuth entrypoints are disabled in safe default builds', () {
      expect(AppEnvironment.googleOAuthEnabled, isFalse);
    });
    return;
  }

  testWidgets('staging signup shows Google without disabled email fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MemberSignUpScreen())),
    );
    await tester.pumpAndSettle();

    final googleButton = find.widgetWithText(
      OutlinedButton,
      'Google দিয়ে চালিয়ে যান',
    );
    expect(googleButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);

    if (!AppEnvironment.publicMemberSignupEnabled) {
      expect(find.byKey(const Key('member-email')), findsNothing);
      expect(find.byKey(const Key('member-password')), findsNothing);
      expect(
        find.textContaining('ইমেইল-পাসওয়ার্ড নিবন্ধন এখনো চালু হয়নি'),
        findsOneWidget,
      );
    }
  });

  testWidgets('staging login also shows Google sign-in', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    await tester.pumpAndSettle();

    final googleButton = find.widgetWithText(
      OutlinedButton,
      'Google দিয়ে লগইন',
    );
    await tester.ensureVisible(googleButton);
    expect(googleButton, findsOneWidget);
    expect(tester.widget<OutlinedButton>(googleButton).onPressed, isNotNull);
  });
}
