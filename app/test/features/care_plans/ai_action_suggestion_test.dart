import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/data/ai_actions_providers.dart';
import 'package:sukun_life/features/care_plans/data/ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/data/supabase_ai_actions_repository.dart';
import 'package:sukun_life/features/care_plans/domain/ai_action_suggestion.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/resource_matcher.dart';
import 'package:sukun_life/features/care_plans/presentation/ai_action_review_screen.dart';
import 'package:sukun_life/features/patients/data/patients_providers.dart';
import 'package:sukun_life/features/patients/data/patients_repository.dart';
import 'package:sukun_life/features/patients/domain/patient.dart';
import 'package:sukun_life/features/patients/domain/patient_inputs.dart';
import 'package:sukun_life/features/patients/domain/prescription.dart';

void main() {
  group('AI action response parsing', () {
    test(
      'preserves Bangla and mixed-language content without inventing fields',
      () {
        final result = AiActionGenerationResult.fromJson({
          'request_id': 'request-1',
          'status': 'generated',
          'actions': [
            {
              'type': 'recitation',
              'title': 'আয়াতুল কুরসি recitation',
              'instruction': 'সকাল-সন্ধ্যা পড়বেন',
              'count_target': 3,
              'duration_minutes': null,
              'frequency': null,
              'time_window': 'morning',
              'exact_time': null,
              'resource_match_query': 'Ayatul Kursi আয়াতুল কুরসি',
              'source_evidence': 'সকাল-সন্ধ্যা পড়বেন',
              'confidence': 0.76,
              'needs_review': false,
              'ambiguities': ['Frequency was not explicit'],
            },
          ],
        }, expectedRequestId: 'request-1');

        final action = result.actions.single;
        expect(action.title, 'আয়াতুল কুরসি recitation');
        expect(action.countTarget, 3);
        expect(action.frequency, isNull);
        expect(action.needsReview, isTrue);
      },
    );

    test('rejects malformed or mismatched responses', () {
      expect(
        () => AiActionGenerationResult.fromJson({
          'request_id': 'another-request',
          'status': 'generated',
          'actions': const [],
        }, expectedRequestId: 'request-1'),
        throwsA(isA<AiActionSchemaException>()),
      );
    });

    test('accepts the neutral manual fallback contract', () {
      final result = AiActionGenerationResult.fromJson({
        'request_id': 'request-1',
        'status': 'manual_required',
        'actions': const [],
        'message': aiManualFallbackMessage,
      }, expectedRequestId: 'request-1');

      expect(result.requiresManualBuilder, isTrue);
    });

    test('imports suggestions only as draft or needs-review work', () {
      const reviewed = SuggestedPlanAction(
        index: 0,
        type: 'recitation',
        title: 'Reviewed suggestion',
        frequency: ActionFrequency.daily(),
        confidence: 0.9,
        needsReview: false,
        ambiguities: [],
      );
      const ambiguous = SuggestedPlanAction(
        index: 1,
        type: 'recitation',
        title: 'Ambiguous suggestion',
        frequency: null,
        confidence: 0.5,
        needsReview: true,
        ambiguities: ['Frequency is missing.'],
      );

      expect(importedReviewStatus(reviewed), ActionReviewStatus.draft);
      expect(importedReviewStatus(ambiguous), ActionReviewStatus.needsReview);
      expect(
        importedReviewStatus(reviewed),
        isNot(ActionReviewStatus.approved),
      );
      expect(
        importedReviewStatus(ambiguous),
        isNot(ActionReviewStatus.approved),
      );
    });
  });

  group('resource matching', () {
    const resources = [
      ContentResourceOption(
        id: 'resource-1',
        title: 'Ayatul Kursi Audio',
        titleBn: 'আয়াতুল কুরসি অডিও',
        type: 'audio',
        visibility: 'public',
        status: 'published',
      ),
      ContentResourceOption(
        id: 'resource-2',
        title: 'Sleep Guide',
        type: 'article',
        visibility: 'patient_only',
        status: 'published',
      ),
    ];

    test('matches English and Bangla labels deterministically', () {
      expect(
        matchResources('Ayatul Kursi', resources).first.resource.id,
        'resource-1',
      );
      expect(
        matchResources('আয়াতুল কুরসি', resources).first.resource.id,
        'resource-1',
      );
      expect(matchResources(null, resources), isEmpty);
    });
  });

  test('unknown provider failures map to the neutral manual message', () {
    final message = safeAiGenerationError(429);
    expect(message, aiManualFallbackMessage);
    expect(message.toLowerCase(), isNot(contains('quota')));
    expect(message, isNot(contains('429')));
  });

  testWidgets('manual fallback keeps the Manual Action Builder available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiActionsRepositoryProvider.overrideWithValue(
            const _ManualAiActionsRepository(),
          ),
          carePlansRepositoryProvider.overrideWithValue(
            _ReviewCarePlansRepository(),
          ),
          patientsRepositoryProvider.overrideWithValue(
            const _ReviewPatientsRepository(),
          ),
        ],
        child: const MaterialApp(
          home: AiActionReviewScreen(
            patientId: 'patient-1',
            planId: 'plan-1',
            prescriptionId: 'prescription-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(aiManualFallbackMessage), findsOneWidget);
    expect(find.text('Open Manual Action Builder'), findsOneWidget);
    expect(find.textContaining('quota'), findsNothing);
  });

  testWidgets(
    'review shows the original prescription and editable suggestion',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiActionsRepositoryProvider.overrideWithValue(
              const _GeneratedAiActionsRepository(),
            ),
            carePlansRepositoryProvider.overrideWithValue(
              _ReviewCarePlansRepository(),
            ),
            patientsRepositoryProvider.overrideWithValue(
              const _ReviewPatientsRepository(),
            ),
          ],
          child: const MaterialApp(
            home: AiActionReviewScreen(
              patientId: 'patient-1',
              planId: 'plan-1',
              prescriptionId: 'prescription-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Original prescription'), findsOneWidget);
      expect(
        find.text('সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।'),
        findsOneWidget,
      );
      expect(find.text('আয়াতুল কুরসি'), findsWidgets);
      expect(find.textContaining('Source evidence:'), findsOneWidget);
      expect(find.text('Check these ambiguities:'), findsOneWidget);
      expect(find.text('Possible resource matches'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Import selected as drafts'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Import selected as drafts'), findsOneWidget);
    },
  );
}

final class _ReviewPatientsRepository implements PatientsRepository {
  const _ReviewPatientsRepository();

  @override
  Future<List<Prescription>> getPrescriptions(String patientId) async => [
    Prescription(
      id: 'prescription-1',
      patientId: patientId,
      rawText: 'সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।',
      visibility: PrescriptionVisibility.patient,
      createdAt: DateTime(2026, 10, 2),
    ),
  ];

  @override
  Future<Patient> createPatient(CreatePatientInput input) =>
      throw UnimplementedError();

  @override
  Future<Prescription> createPrescription(CreatePrescriptionInput input) =>
      throw UnimplementedError();

  @override
  Future<Patient?> getPatient(String patientId) => throw UnimplementedError();

  @override
  Future<List<Patient>> searchPatients({String query = ''}) =>
      throw UnimplementedError();
}

final class _ManualAiActionsRepository implements AiActionsRepository {
  const _ManualAiActionsRepository();

  @override
  Future<AiActionGenerationResult> generateActions({
    required String prescriptionId,
    required String carePlanId,
    required String requestId,
  }) async => AiActionGenerationResult(
    requestId: requestId,
    status: AiActionGenerationStatus.manualRequired,
    actions: const [],
  );
}

final class _GeneratedAiActionsRepository implements AiActionsRepository {
  const _GeneratedAiActionsRepository();

  @override
  Future<AiActionGenerationResult> generateActions({
    required String prescriptionId,
    required String carePlanId,
    required String requestId,
  }) async => AiActionGenerationResult(
    requestId: requestId,
    status: AiActionGenerationStatus.generated,
    actions: const [
      SuggestedPlanAction(
        index: 0,
        type: 'recitation',
        title: 'আয়াতুল কুরসি',
        countTarget: 3,
        frequency: ActionFrequency.daily(),
        timeWindow: 'morning',
        resourceMatchQuery: 'আয়াতুল কুরসি',
        sourceEvidence: 'সকাল-সন্ধ্যা আয়াতুল কুরসি ৩ বার পড়বেন।',
        confidence: 0.8,
        needsReview: true,
        ambiguities: ['Confirm whether this is also required in the evening.'],
      ),
    ],
  );
}

final class _ReviewCarePlansRepository implements CarePlansRepository {
  final plan = CarePlan(
    id: 'plan-1',
    patientId: 'patient-1',
    prescriptionId: 'prescription-1',
    version: 1,
    name: 'Draft plan',
    startDate: DateTime(2026, 10, 2),
    status: CarePlanStatus.draft,
    createdAt: DateTime(2026, 10, 2),
  );

  @override
  Future<CarePlan?> getPlan(String planId) async => plan;

  @override
  Future<List<ContentResourceOption>> getAvailableResources() async => const [
    ContentResourceOption(
      id: 'resource-1',
      title: 'Ayatul Kursi Audio',
      titleBn: 'আয়াতুল কুরসি অডিও',
      type: 'audio',
      visibility: 'public',
      status: 'published',
    ),
  ];

  @override
  Future<CarePlan> archivePlan(String planId, String requestId) =>
      throw UnimplementedError();

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) =>
      throw UnimplementedError();

  @override
  Future<List<PlanAction>> getActions(String planId) =>
      throw UnimplementedError();

  @override
  Future<List<CarePlan>> getPatientPlans(String patientId) =>
      throw UnimplementedError();

  @override
  Future<CarePlan> publishPlan(String planId, String requestId) =>
      throw UnimplementedError();

  @override
  Future<void> rejectAction(String actionId, String requestId) =>
      throw UnimplementedError();

  @override
  Future<List<PlanAction>> reorderActions(
    String planId,
    List<String> actionIds,
    String requestId,
  ) => throw UnimplementedError();

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) =>
      throw UnimplementedError();
}
