import 'package:sukun_life/features/patients/domain/prescription.dart';

class CreatePatientInput {
  const CreatePatientInput({
    required this.fullName,
    required this.phone,
    required this.temporaryPassword,
    required this.requestId,
    this.patientCode,
  });

  final String fullName;
  final String phone;
  final String temporaryPassword;
  final String requestId;
  final String? patientCode;

  Map<String, dynamic> toJson() => {
    'full_name': fullName.trim(),
    'phone': phone.trim(),
    'temporary_password': temporaryPassword,
    'request_id': requestId,
    if (patientCode?.trim().isNotEmpty == true)
      'patient_code': patientCode!.trim(),
  };
}

class CreatePrescriptionInput {
  const CreatePrescriptionInput({
    required this.patientId,
    required this.rawText,
    required this.visibility,
    required this.requestId,
    this.sessionDate,
  });

  final String patientId;
  final String rawText;
  final PrescriptionVisibility visibility;
  final String requestId;
  final DateTime? sessionDate;
}

String? validatePatientName(String? value) {
  final length = value?.trim().length ?? 0;
  if (length < 2 || length > 160) {
    return 'Enter a name between 2 and 160 characters.';
  }
  return null;
}

String? validateInternationalPhone(String? value) {
  final normalized = value?.replaceAll(RegExp(r'[\s()-]'), '') ?? '';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(normalized)) {
    return 'Use international format, for example +8801…';
  }
  return null;
}

String? validateTemporaryPassword(String? value) {
  final length = value?.length ?? 0;
  if (length < 8 || length > 72) {
    return 'Use 8–72 characters.';
  }
  return null;
}

String? validatePatientCode(String? value) {
  final normalized = value?.trim().toUpperCase() ?? '';
  if (normalized.isEmpty) return null;
  if (!RegExp(r'^[A-Z0-9][A-Z0-9-]{2,31}$').hasMatch(normalized)) {
    return 'Use 3–32 letters, numbers, or hyphens.';
  }
  return null;
}

String? validatePrescriptionText(String? value) {
  if (value?.trim().isEmpty ?? true) return 'Enter the original instruction.';
  return null;
}
