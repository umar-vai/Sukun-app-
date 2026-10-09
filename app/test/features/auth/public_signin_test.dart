import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/auth/public_signin_gateway.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/auth/domain/public_auth_inputs.dart';
import 'package:sukun_life/features/auth/presentation/public_otp_signin_screen.dart';

void main() {
  test('external OTP and Google provider gates default to off', () {
    expect(AppEnvironment.emailOtpEnabled, isFalse);
    expect(AppEnvironment.phoneOtpEnabled, isFalse);
    expect(AppEnvironment.googleOAuthEnabled, isFalse);
  });

  test('validates email and E.164 phone without guessing identities', () {
    expect(validateOtpRecipient('me@example.com', PublicOtpChannel.email), isNull);
    expect(validateOtpRecipient('bad', PublicOtpChannel.email), isNotNull);
    expect(validateOtpRecipient('+8801712345678', PublicOtpChannel.phone), isNull);
    expect(validateOtpRecipient('01712345678', PublicOtpChannel.phone), isNotNull);
  });

  test('only numeric OTP codes of length 6-8 are valid', () {
    expect(validateOtpCode('123456'), isNull);
    expect(validateOtpCode('12345678'), isNull);
    expect(validateOtpCode('12345'), isNotNull);
    expect(validateOtpCode('123456789'), isNotNull);
    expect(validateOtpCode('12a456'), isNotNull);
  });

  for (final channel in PublicOtpChannel.values) {
    testWidgets('disabled $channel OTP cannot send codes', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PublicOtpSignInScreen(channel: channel),
      ));
      await tester.pumpAndSettle();
      expect(find.text('এই লগইন সুবিধা এখনো চালু হয়নি।'), findsOneWidget);
      expect(find.text('যাচাইকরণ কোড পাঠান'), findsNothing);
    });
  }
}
