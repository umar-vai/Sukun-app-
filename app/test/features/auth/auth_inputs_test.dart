import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/auth/domain/auth_inputs.dart';

void main() {
  test('validates sign-in identifiers and account passwords', () {
    expect(validateSignInIdentifier('SL-2026-ABC123'), isNull);
    expect(validateSignInIdentifier('x'), isNotNull);
    expect(validateAccountPassword('short'), isNotNull);
    expect(validateAccountPassword('Secure-123'), isNull);
  });

  test('requires matching replacement passwords', () {
    expect(validateConfirmedPassword('Secure-123', 'different'), isNotNull);
    expect(validateConfirmedPassword('Secure-123', 'Secure-123'), isNull);
  });
}
