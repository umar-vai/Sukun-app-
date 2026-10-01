import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/data/supabase_patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final patientsRepositoryProvider = Provider<PatientsRepository>((ref) {
  if (!AppEnvironment.isSupabaseConfigured) {
    return const UnavailablePatientsRepository();
  }
  return SupabasePatientsRepository(Supabase.instance.client);
});

final class UnavailablePatientsRepository implements PatientsRepository {
  const UnavailablePatientsRepository();

  Never _unavailable() => throw const PatientWorkflowException(
    'Connect Supabase to use secure patient management.',
  );

  @override
  Future<Patient> createPatient(CreatePatientInput input) async =>
      _unavailable();

  @override
  Future<Prescription> createPrescription(
    CreatePrescriptionInput input,
  ) async => _unavailable();

  @override
  Future<Patient?> getPatient(String patientId) async => _unavailable();

  @override
  Future<List<Prescription>> getPrescriptions(String patientId) async =>
      _unavailable();

  @override
  Future<List<Patient>> searchPatients({String query = ''}) async =>
      _unavailable();
}
