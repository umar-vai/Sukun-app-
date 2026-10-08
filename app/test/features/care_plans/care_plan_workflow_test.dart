import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_builder_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_preview_screen.dart';

void main() {
  group('care-plan domain', () {
    test('serializes daily and selected-day frequency rules', () {
      expect(const ActionFrequency.daily(interval: 2).toJson(), {
        'type': 'daily',
        'interval': 2,
      });
      expect(const ActionFrequency.weekly({5, 1, 3}).toJson(), {
        'type': 'weekly',
        'weekdays': [1, 3, 5],
      });
    });

    test('parses an action with its canonical resource relation', () {
      final action = PlanAction.fromJson({
        'id': 'action-1',
        'care_plan_id': 'plan-1',
        'type': 'listening',
        'title': 'Listen to assigned audio',
        'frequency_rule': {'type': 'daily', 'interval': 1},
        'start_date': '2026-10-02',
        'sort_order': 0,
        'review_status': 'approved',
        'reminder_enabled': false,
        'plan_action_resources': [
          {
            'usage_note': 'Use the complete recording.',
            'content_items': {
              'id': 'resource-1',
              'title': 'Assigned recording',
              'title_bn': null,
              'type': 'audio',
            },
          },
        ],
      });

      expect(action.reviewStatus, ActionReviewStatus.approved);
      expect(action.resource?.id, 'resource-1');
      expect(action.resource?.usageNote, 'Use the complete recording.');
    });

    test('validates required text and positive optional numbers', () {
      expect(validatePlanName(' '), isNotNull);
      expect(validatePlanName('Morning plan'), isNull);
      expect(validateActionRequired('', 'Title'), 'Title is required.');
      expect(validateOptionalPositiveInteger('', 'Count'), isNull);
      expect(validateOptionalPositiveInteger('0', 'Count'), isNotNull);
      expect(validateOptionalPositiveInteger('3', 'Count'), isNull);
    });
  });

  testWidgets('patient preview hides every unapproved action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carePlansRepositoryProvider.overrideWithValue(
            _FakeCarePlansRepository(),
          ),
        ],
        child: const MaterialApp(
          home: CarePlanPreviewScreen(patientId: 'patient-1', planId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approved patient action'), findsOneWidget);
    expect(find.text('Unreviewed internal action'), findsNothing);
    expect(find.text('Assigned recording'), findsOneWidget);
    expect(find.textContaining('Preview only'), findsOneWidget);
  });

  testWidgets('publish is disabled when an action has not been approved', (
    tester,
  ) async {
    final repository = _FakeCarePlansRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [carePlansRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CarePlanBuilderScreen(patientId: 'patient-1', planId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1টি করণীয় যাচাই ও অনুমোদন বাকি।'), findsOneWidget);
    final publishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'রোগীর জন্য চালু করুন'),
    );
    expect(publishButton.onPressed, isNull);
  });

  testWidgets('publishing refreshes the builder without a setState error', (
    tester,
  ) async {
    final repository = _PublishingCarePlansRepository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const CarePlanBuilderScreen(
            patientId: 'patient-1',
            planId: 'plan-1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [carePlansRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('রোগীর জন্য চালু করুন'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'চালু করুন'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.published, isTrue);
    expect(find.text('চালু'), findsOneWidget);
  });
}

class _FakeCarePlansRepository implements CarePlansRepository {
  final plan = CarePlan(
    id: 'plan-1',
    patientId: 'patient-1',
    version: 1,
    name: 'Test care plan',
    startDate: DateTime(2026, 10, 2),
    status: CarePlanStatus.draft,
    createdAt: DateTime(2026, 10, 2),
  );

  late final approvedAction = PlanAction(
    id: 'action-1',
    carePlanId: plan.id,
    type: 'listening',
    title: 'Approved patient action',
    frequency: const ActionFrequency.daily(),
    startDate: plan.startDate,
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
    resource: const LinkedResource(
      id: 'resource-1',
      title: 'Assigned recording',
      type: 'audio',
    ),
  );

  late final unreviewedAction = PlanAction(
    id: 'action-2',
    carePlanId: plan.id,
    type: 'recitation',
    title: 'Unreviewed internal action',
    frequency: const ActionFrequency.daily(),
    startDate: plan.startDate,
    sortOrder: 1,
    reviewStatus: ActionReviewStatus.needsReview,
    reminderEnabled: false,
  );

  @override
  Future<List<PlanAction>> getActions(String planId) async => [
    approvedAction,
    unreviewedAction,
  ];

  @override
  Future<CarePlan?> getPlan(String planId) async => plan;

  @override
  Future<CarePlan> archivePlan(String planId, String requestId) =>
      throw UnimplementedError();

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) =>
      throw UnimplementedError();

  @override
  Future<List<ContentResourceOption>> getAvailableResources() =>
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

final class _PublishingCarePlansRepository extends _FakeCarePlansRepository {
  bool published = false;

  @override
  Future<List<PlanAction>> getActions(String planId) async => [approvedAction];

  @override
  Future<CarePlan?> getPlan(String planId) async => CarePlan(
    id: plan.id,
    patientId: plan.patientId,
    version: plan.version,
    name: plan.name,
    startDate: plan.startDate,
    status: published ? CarePlanStatus.active : CarePlanStatus.draft,
    createdAt: plan.createdAt,
    publishedAt: published ? DateTime(2026, 10, 3) : null,
  );

  @override
  Future<CarePlan> publishPlan(String planId, String requestId) async {
    published = true;
    return (await getPlan(planId))!;
  }
}
