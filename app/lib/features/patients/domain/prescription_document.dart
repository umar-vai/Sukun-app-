import 'dart:typed_data';

import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

const prescriptionDocumentMaxBytes = 10 * 1024 * 1024;
const prescriptionDocumentManualMessage =
    'We could not read this prescription safely. The original file is preserved; continue with manual action entry.';

class PrescriptionDocumentFile {
  const PrescriptionDocumentFile({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final Uint8List bytes;

  int get byteSize => bytes.lengthInBytes;
}

class PrescriptionDocumentImportInput {
  const PrescriptionDocumentImportInput({
    required this.patientId,
    required this.file,
    required this.visibility,
    required this.createRequestId,
    required this.extractionRequestId,
    this.sessionDate,
  });

  final String patientId;
  final PrescriptionDocumentFile file;
  final PrescriptionVisibility visibility;
  final String createRequestId;
  final String extractionRequestId;
  final DateTime? sessionDate;
}

class PrescriptionDocumentImportResult {
  const PrescriptionDocumentImportResult({
    required this.attachmentId,
    required this.aiResult,
    this.prescriptionId,
    this.carePlanId,
  });

  final String attachmentId;
  final String? prescriptionId;
  final String? carePlanId;
  final AiActionGenerationResult aiResult;

  bool get isReadyForReview =>
      aiResult.status == AiActionGenerationStatus.generated &&
      prescriptionId != null &&
      carePlanId != null;
}

class PrescriptionDocumentException implements Exception {
  const PrescriptionDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

String? validatePrescriptionDocument(PrescriptionDocumentFile file) {
  const allowed = {'application/pdf', 'image/jpeg', 'image/png'};
  if (!allowed.contains(file.mimeType)) {
    return 'Choose a PDF, JPG, or PNG prescription.';
  }
  if (file.byteSize < 1 || file.byteSize > prescriptionDocumentMaxBytes) {
    return 'Prescription files must be 10 MB or smaller.';
  }
  return null;
}
