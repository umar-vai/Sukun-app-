import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_repository.dart';
import 'package:sukun_life/features/patients/domain/prescription_document.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePrescriptionDocumentsRepository
    implements PrescriptionDocumentsRepository {
  SupabasePrescriptionDocumentsRepository(this._client);

  static const _bucket = 'prescription-private';
  final SupabaseClient _client;

  @override
  Future<PrescriptionDocumentImportResult> importDocument(
    PrescriptionDocumentImportInput input,
  ) async {
    final validation = validatePrescriptionDocument(input.file);
    if (validation != null) {
      throw PrescriptionDocumentException(validation);
    }

    try {
      final attachmentResponse = await _client.rpc(
        'create_prescription_attachment',
        params: {
          'p_patient_id': input.patientId,
          'p_original_filename': input.file.filename,
          'p_mime_type': input.file.mimeType,
          'p_byte_size': input.file.byteSize,
          'p_session_date': input.sessionDate == null
              ? null
              : _dateOnly(input.sessionDate!),
          'p_visibility': input.visibility.databaseValue,
          'p_request_id': input.createRequestId,
        },
      );
      if (attachmentResponse is! Map) {
        throw const PrescriptionDocumentException(
          'The prescription upload could not be prepared.',
        );
      }
      final attachment = Map<String, dynamic>.from(attachmentResponse);
      final attachmentId = attachment['id'];
      final storagePath = attachment['storage_path'];
      if (attachmentId is! String || storagePath is! String) {
        throw const PrescriptionDocumentException(
          'The prescription upload could not be prepared.',
        );
      }

      await _client.storage.from(_bucket).uploadBinary(
        storagePath,
        input.file.bytes,
        fileOptions: FileOptions(
          contentType: input.file.mimeType,
          upsert: false,
        ),
      );

      final response = await _client.functions.invoke(
        'prescription-document-to-actions',
        body: {
          'attachment_id': attachmentId,
          'request_id': input.extractionRequestId,
        },
      );
      final body = response.data;
      if (body is! Map) {
        throw const PrescriptionDocumentException(
          prescriptionDocumentManualMessage,
        );
      }
      final json = Map<String, dynamic>.from(body);
      final aiResult = AiActionGenerationResult.fromJson(
        json,
        expectedRequestId: input.extractionRequestId,
      );
      return PrescriptionDocumentImportResult(
        attachmentId: attachmentId,
        prescriptionId: json['prescription_id'] as String?,
        carePlanId: json['care_plan_id'] as String?,
        aiResult: aiResult,
      );
    } on PrescriptionDocumentException {
      rethrow;
    } on PostgrestException catch (error) {
      throw PrescriptionDocumentException(
        _safeDatabaseMessage(error),
      );
    } on StorageException {
      throw const PrescriptionDocumentException(
        'The prescription file could not be uploaded securely. Please try again.',
      );
    } on FunctionException catch (error) {
      throw PrescriptionDocumentException(
        _safeFunctionMessage(error.status),
      );
    } on AiActionSchemaException {
      throw const PrescriptionDocumentException(
        prescriptionDocumentManualMessage,
      );
    } catch (_) {
      throw const PrescriptionDocumentException(
        prescriptionDocumentManualMessage,
      );
    }
  }
}

String _safeDatabaseMessage(PostgrestException error) {
  const allowed = <String>[
    'Authentication is required.',
    'Super Admin access is required.',
    'A request identifier is required.',
    'Choose a prescription file.',
    'Use a PDF, JPG, or PNG prescription.',
    'Prescription files must be 10 MB or smaller.',
    'An active patient was not found.',
  ];
  return allowed.contains(error.message)
      ? error.message
      : 'The prescription upload could not be prepared. Please try again.';
}

String _safeFunctionMessage(int status) => switch (status) {
  401 => 'Please sign in again before importing a prescription.',
  403 => 'Super Admin access is required to import prescriptions.',
  400 => 'The prescription file could not be read safely.',
  404 => 'The preserved prescription file could not be found.',
  409 => 'This prescription is already being processed. Please try again shortly.',
  _ => prescriptionDocumentManualMessage,
};

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
