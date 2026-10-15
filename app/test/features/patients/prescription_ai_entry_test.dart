import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/presentation/create_prescription_screen.dart';

void main() {
  testWidgets('typed prescription directly opens the existing AI review route', (
    tester,
  ) async {
    final prescriptions = _CountingPrescriptions();
    final plans = _DraftPlans();
    final router = _testRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsRepositoryProvider.overrideWithValue(prescriptions),
          carePlansRepositoryProvider.overrideWithValue(plans),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'সকালে আয়াতুল কুরসি ৩ বার পড়বেন।',
    );
    await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
    await tester.pumpAndSettle();

    expect(prescriptions.calls, 1);
    expect(plans.calls, 1);
    expect(plans.inputs.single.patientId, 'patient-1');
    expect(plans.inputs.single.prescriptionId, 'prescription-1');
    expect(find.text('AI review: prescription-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft failure retry does not save prescription twice', (
    tester,
  ) async {
    final prescriptions = _CountingPrescriptions();
    final plans = _DraftPlans(failFirst: true);
    final router = _testRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          patientsRepositoryProvider.overrideWithValue(prescriptions),
          carePlansRepositoryProvider.overrideWithValue(plans),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'সকালে আয়াতুল কুরসি ৩ বার পড়বেন।',
    );
    await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
    await tester.pumpAndSettle();

    expect(prescriptions.calls, 1);
    expect(plans.calls, 1);
    expect(find.textContaining('প্রেসক্রিপশন দ্বিতীয়বার সংরক্ষণ হবে না'), findsOneWidget);

    await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
    await tester.pumpAndSettle();

    expect(prescriptions.calls, 1);
    expect(plans.calls, 2);
    expect(plans.inputs.first.requestId, plans.inputs.last.requestId);
    expect(find.text('AI review: prescription-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

GoRouter _testRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const CreatePrescriptionScreen(patientId: 'patient-1'),
    ),
    GoRoute(
      path: '/admin/patients/:patientId/plans/:planId/actions/suggest',
      builder: (_, state) => Scaffold(
        body: Center(
          child: Text(
            'AI review: ${state.uri.queryParameters['prescriptionId']}',
          ),
        ),
      ),
    ),
  ],
);

class _CountingPrescriptions implements PatientsRepository {
  int calls = 0;

  @override
  Future<Prescription> createPrescription(CreatePrescriptionInput input) async {
    calls += 1;
    return Prescription(
      id: 'prescription-1',
      patientId: input.patientId,
      rawText: input.rawText,
      visibility: input.visibility,
      createdAt: DateTime(2026, 10, 15),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DraftPlans implements CarePlansRepository {
  _DraftPlans({this.failFirst = false});

  final bool failFirst;
  int calls = 0;
  final List<CreateCarePlanInput> inputs = [];

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) async {
    calls += 1;
    inputs.add(input);
    if (failFirst && calls == 1) {
      throw const CarePlanWorkflowException('Simulated draft failure');
    }
    return CarePlan(
      id: 'plan-1',
      patientId: input.patientId,
      prescriptionId: input.prescriptionId,
      version: 1,
      name: input.name,
      startDate: input.startDate,
      status: CarePlanStatus.draft,
      createdAt: DateTime(2026, 10, 15),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
