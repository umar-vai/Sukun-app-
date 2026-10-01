import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

abstract interface class PatientsRepository {
  Future<List<Patient>> searchPatients({String query = ''});

  Future<Patient?> getPatient(String patientId);

  Future<Patient> createPatient(CreatePatientInput input);

  Future<List<Prescription>> getPrescriptions(String patientId);

  Future<Prescription> createPrescription(CreatePrescriptionInput input);
}

class PatientWorkflowException implements Exception {
  const PatientWorkflowException(this.message);

  final String message;

  @override
  String toString() => message;
}
