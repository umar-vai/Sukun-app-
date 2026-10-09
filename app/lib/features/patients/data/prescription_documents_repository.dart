import 'package:sukun_life/features/patients/domain/prescription_document.dart';

abstract interface class PrescriptionDocumentsRepository {
  Future<PrescriptionDocumentImportResult> importDocument(
    PrescriptionDocumentImportInput input,
  );
}
