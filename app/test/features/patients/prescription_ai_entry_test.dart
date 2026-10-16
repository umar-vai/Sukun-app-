import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_providers.dart';
import 'package:sukun_life/features/patients/data/prescription_documents_repository.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';
import 'package:sukun_life/features/patients/domain/prescription_document.dart';
import 'package:sukun_life/features/patients/presentation/create_prescription_screen.dart';

void main() {
  testWidgets(
    'typed prescription directly opens the existing AI review route',
    (tester) async {
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
      await tester.ensureVisible(
        find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
      await tester.pumpAndSettle();

      expect(prescriptions.calls, 1);
      expect(plans.calls, 1);
      expect(plans.inputs.single.patientId, 'patient-1');
      expect(plans.inputs.single.prescriptionId, 'prescription-1');
      expect(find.text('AI review: prescription-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
    await tester.ensureVisible(
      find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
    await tester.pumpAndSettle();

    expect(prescriptions.calls, 1);
    expect(plans.calls, 1);
    expect(
      find.textContaining('প্রেসক্রিপশন দ্বিতীয়বার সংরক্ষণ হবে না'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('সংরক্ষণ করে AI দিয়ে করণীয় তৈরি করুন'));
    await tester.pumpAndSettle();

    expect(prescriptions.calls, 1);
    expect(plans.calls, 2);
    expect(plans.inputs.first.requestId, plans.inputs.last.requestId);
    expect(find.text('AI review: prescription-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('preserved PDF AI retry does not create a second attachment', (
    tester,
  ) async {
    final documents = _PdfRetryRepository();
    final router = _testRouter(
      initialDocument: PrescriptionDocumentFile(
        filename: 'synthetic-prescription.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prescriptionDocumentsRepositoryProvider.overrideWithValue(documents),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.ensureVisible(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();

    expect(documents.importCalls, 1);
    expect(documents.retryCalls, 0);
    expect(find.text('সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন'), findsOneWidget);
    expect(find.text('নিজে প্রেসক্রিপশন লিখুন'), findsOneWidget);

    await tester.ensureVisible(
      find.text('সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন'));
    await tester.pumpAndSettle();

    expect(documents.importCalls, 1);
    expect(documents.retryCalls, 1);
    expect(documents.retriedAttachmentId, 'attachment-1');
    expect(find.text('AI review: prescription-1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing staging Gemini keys produce actionable Admin message', (
    tester,
  ) async {
    final documents = _PdfRetryRepository(
      initialFailureCode: 'ai_configuration_missing',
    );
    final router = _testRouter(
      initialDocument: PrescriptionDocumentFile(
        filename: 'synthetic-prescription.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]),
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prescriptionDocumentsRepositoryProvider.overrideWithValue(documents),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.ensureVisible(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gemini API key configure'), findsOneWidget);
    expect(documents.importCalls, 1);
    expect(documents.retryCalls, 0);
    expect(find.text('সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('draft conflict explains existing plan without re-uploading PDF', (
    tester,
  ) async {
    final documents = _PdfRetryRepository(
      initialFailureCode: 'draft_plan_conflict',
    );
    final router = _testRouter(
      initialDocument: PrescriptionDocumentFile(
        filename: 'synthetic-prescription.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]),
      ),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prescriptionDocumentsRepositoryProvider.overrideWithValue(documents),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.ensureVisible(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload & generate draft actions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('অন্য প্রেসক্রিপশনের Draft Plan'), findsOneWidget);
    expect(find.text('সংরক্ষিত PDF থেকে আবার AI চেষ্টা করুন'), findsOneWidget);
    expect(documents.importCalls, 1);
    expect(documents.retryCalls, 0);
    expect(tester.takeException(), isNull);
  });

}

GoRouter _testRouter({PrescriptionDocumentFile? initialDocument}) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => CreatePrescriptionScreen(
        patientId: 'patient-1',
        initialDocument: initialDocument,
      ),
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

class _PdfRetryRepository implements PrescriptionDocumentsRepository {
  _PdfRetryRepository({this.initialFailureCode});

  final String? initialFailureCode;
  int importCalls = 0;
  int retryCalls = 0;
  String? retriedAttachmentId;

  @override
  Future<PrescriptionDocumentImportResult> importDocument(
    PrescriptionDocumentImportInput input,
  ) async {
    importCalls += 1;
    return PrescriptionDocumentImportResult(
      attachmentId: 'attachment-1',
      aiResult: AiActionGenerationResult(
        requestId: input.extractionRequestId,
        status: AiActionGenerationStatus.manualRequired,
        actions: const [],
        failureCode: initialFailureCode,
      ),
    );
  }

  @override
  Future<PrescriptionDocumentImportResult> retryDocumentExtraction({
    required String attachmentId,
    required String requestId,
  }) async {
    retryCalls += 1;
    retriedAttachmentId = attachmentId;
    return PrescriptionDocumentImportResult(
      attachmentId: attachmentId,
      prescriptionId: 'prescription-1',
      carePlanId: 'plan-1',
      aiResult: AiActionGenerationResult(
        requestId: requestId,
        status: AiActionGenerationStatus.generated,
        actions: const [],
      ),
    );
  }
}
