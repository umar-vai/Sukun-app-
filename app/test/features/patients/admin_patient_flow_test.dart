import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/presentation/create_patient_screen.dart';
import 'package:sukun_life/features/patients/presentation/patients_list_screen.dart';

void main() {
  testWidgets('admin patient list renders repository results', (tester) async {
    final repository = _FakePatientsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [patientsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PatientsListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amina Rahman'), findsOneWidget);
    expect(find.textContaining('SL-TEST-01'), findsOneWidget);
  });

  testWidgets('create patient submits validated temporary credentials', (
    tester,
  ) async {
    final repository = _FakePatientsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [patientsRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: CreatePatientScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Amina Rahman');
    await tester.enterText(fields.at(1), '+8801712345678');
    await tester.enterText(fields.at(2), 'SL-TEST-02');
    await tester.enterText(fields.at(3), 'Temporary-123');
    final submit = find.widgetWithText(FilledButton, 'রোগী যোগ করুন');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(repository.createdPatientInput?.fullName, 'Amina Rahman');
    expect(repository.createdPatientInput?.temporaryPassword, 'Temporary-123');
    expect(find.text('রোগীর অ্যাকাউন্ট তৈরি হয়েছে'), findsOneWidget);
    expect(find.textContaining('SL-TEST-01'), findsOneWidget);
  });
}

final class _FakePatientsRepository implements PatientsRepository {
  static final patient = Patient(
    id: '10000000-0000-4000-8000-000000000001',
    userId: '00000000-0000-4000-8000-000000000001',
    patientCode: 'SL-TEST-01',
    fullName: 'Amina Rahman',
    phone: '+8801712345678',
    status: PatientStatus.active,
    createdAt: DateTime.utc(2026, 10),
  );

  CreatePatientInput? createdPatientInput;

  @override
  Future<Patient> createPatient(CreatePatientInput input) async {
    createdPatientInput = input;
    return patient;
  }

  @override
  Future<Prescription> createPrescription(CreatePrescriptionInput input) async {
    throw UnimplementedError();
  }

  @override
  Future<Patient?> getPatient(String patientId) async => patient;

  @override
  Future<List<Prescription>> getPrescriptions(String patientId) async => [];

  @override
  Future<List<Patient>> searchPatients({String query = ''}) async => [patient];
}
