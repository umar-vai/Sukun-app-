import 'package:sukun_life/features/patients/domain/prescription_document.dart';

abstract interface class PrescriptionDocumentsRepository {
  Future<PrescriptionDocumentImportResult> importDocument(
    PrescriptionDocumentImportInput input,
  );

  // Re-process an already uploaded private document; never re-upload its bytes.
  Future<PrescriptionDocumentImportResult> retryDocumentExtraction({
    required String attachmentId,
    required String requestId,
  });
}
