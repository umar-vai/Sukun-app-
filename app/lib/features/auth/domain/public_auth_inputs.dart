import 'package:sukun_life/core/auth/public_signin_gateway.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';

String? validateOtpRecipient(String? value, PublicOtpChannel channel) {
  if (channel == PublicOtpChannel.email) {
    return validateRegistrationEmail(value);
  }
  final phone = value?.trim() ?? '';
  if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
    return 'দেশের কোডসহ ফোন নম্বর লিখুন (যেমন +8801XXXXXXXXX)।';
  }
  return null;
}

String? validateOtpCode(String? value) {
  final code = value?.trim() ?? '';
  if (!RegExp(r'^[0-9]{6,8}$').hasMatch(code)) {
    return 'ইমেইল বা SMS-এ পাওয়া ৬–৮ সংখ্যার কোড লিখুন।';
  }
  return null;
}
