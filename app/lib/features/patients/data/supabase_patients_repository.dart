import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabasePatientsRepository implements PatientsRepository {
  SupabasePatientsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Patient>> searchPatients({String query = ''}) async {
    final response = await _client.rpc(
      'admin_search_patients',
      params: {'p_query': query.trim(), 'p_limit': 50, 'p_offset': 0},
    );
    return (response as List<dynamic>)
        .map((row) => Patient.fromJson(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  @override
  Future<Patient?> getPatient(String patientId) async {
    final response = await _client
        .from('patients')
        .select()
        .eq('id', patientId)
        .maybeSingle();
    return response == null ? null : Patient.fromJson(response);
  }

  @override
  Future<Patient> createPatient(CreatePatientInput input) async {
    try {
      final response = await _client.functions.invoke(
        'admin-create-patient',
        body: input.toJson(),
      );
      final body = response.data;
      if (body is! Map || body['patient'] is! Map) {
        throw const PatientWorkflowException(
          'The patient account could not be created. Please try again.',
        );
      }
      return Patient.fromJson(
        Map<String, dynamic>.from(body['patient'] as Map),
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['message'] is String) {
        throw PatientWorkflowException(details['message'] as String);
      }
      throw const PatientWorkflowException(
        'The patient account could not be created. Please try again.',
      );
    }
  }

  @override
  Future<List<Prescription>> getPrescriptions(String patientId) async {
    final response = await _client
        .from('prescriptions')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return response
        .map((row) => Prescription.fromJson(row))
        .toList(growable: false);
  }

  @override
  Future<Prescription> createPrescription(CreatePrescriptionInput input) async {
    final response = await _client.rpc(
      'create_prescription',
      params: {
        'p_patient_id': input.patientId,
        'p_raw_text': input.rawText.trim(),
        'p_session_date': input.sessionDate == null
            ? null
            : _dateOnly(input.sessionDate!),
        'p_visibility': input.visibility.databaseValue,
        'p_request_id': input.requestId,
      },
    );
    return Prescription.fromJson(response as Map<String, dynamic>);
  }
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
