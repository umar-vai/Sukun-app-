import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';

void main() {
  group('patient account validation', () {
    test('requires international phone format', () {
      expect(validateInternationalPhone('01712345678'), isNotNull);
      expect(validateInternationalPhone('+880 1712-345678'), isNull);
    });

    test('accepts generated-code flow and validates explicit IDs', () {
      expect(validatePatientCode(''), isNull);
      expect(validatePatientCode('sl-dhaka-12'), isNull);
      expect(validatePatientCode('bad code'), isNotNull);
    });

    test('requires a non-empty original prescription', () {
      expect(validatePrescriptionText('   '), isNotNull);
      expect(
        validatePrescriptionText('সকাল-সন্ধ্যা আয়াতুল কুরসি পড়বেন।'),
        isNull,
      );
    });
  });
}
