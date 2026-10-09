import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/app_session.dart';
import 'package:sukun_life/core/auth/user_role.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';
import 'package:sukun_life/features/auth/presentation/member_signup_screen.dart';

void main() {
  test('email input validator rejects malformed email addresses', () {
    expect(validateRegistrationEmail('not-email'), isNotNull);
    expect(validateRegistrationEmail('a@example.com'), isNull);
    expect(validateRegistrationEmail(' a@example.com '), isNull);
  });

  test('member account is distinct from clinical and admin access', () {
    const member = AppSession(role: UserRole.member, userId: 'member-1');
    expect(member.isAuthenticated, true);
    expect(member.isMember, true);
    expect(member.isPatient, false);
    expect(member.isSuperAdmin, false);
  });

  testWidgets('signup stays unavailable until backend rollout is approved', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MemberSignUpScreen()));
    await tester.pumpAndSettle();
    expect(
      find.text('নতুন অ্যাকাউন্ট খোলার সুবিধা প্রস্তুত করা হচ্ছে।'),
      findsOneWidget,
    );
    final signUp = find.widgetWithText(FilledButton, 'অ্যাকাউন্ট তৈরি করুন');
    await tester.ensureVisible(signUp);
    expect(tester.widget<FilledButton>(signUp).onPressed, isNull);
  });
}
