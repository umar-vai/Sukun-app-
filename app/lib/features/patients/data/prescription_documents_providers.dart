import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_repository.dart';
import 'package:sukun_life/features/patients/data/supabase_prescription_documents_repository.dart';
import 'package:sukun_life/features/patients/domain/prescription_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final prescriptionDocumentsRepositoryProvider =
    Provider<PrescriptionDocumentsRepository>((ref) {
      if (!AppEnvironment.isSupabaseConfigured) {
        return const UnavailablePrescriptionDocumentsRepository();
      }
      return SupabasePrescriptionDocumentsRepository(Supabase.instance.client);
    });

final class UnavailablePrescriptionDocumentsRepository
    implements PrescriptionDocumentsRepository {
  const UnavailablePrescriptionDocumentsRepository();

  @override
  Future<PrescriptionDocumentImportResult> importDocument(
    PrescriptionDocumentImportInput input,
  ) => throw const PrescriptionDocumentException(
    'Connect Supabase to import prescription documents.',
  );
}
