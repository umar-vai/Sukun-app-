import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/widgets/sukun_design.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action_approval.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_builder_screen.dart';

final _plan = CarePlan(
  id: 'plan-1',
  patientId: 'patient-1',
  version: 1,
  name: 'Test care plan',
  startDate: DateTime(2026, 11, 1),
  status: CarePlanStatus.draft,
  createdAt: DateTime(2026, 11, 1),
);

PlanAction _action({
  ActionReviewStatus status = ActionReviewStatus.needsReview,
  List<LinkedResource> resources = const [],
}) => PlanAction(
  id: 'action-1',
  carePlanId: 'plan-1',
  type: 'listening',
  title: 'Evening listening',
  instruction: 'Listen calmly',
  countTarget: 3,
  durationMinutes: 20,
  frequency: const ActionFrequency.weekly({1, 3, 5}),
  timeWindow: 'evening',
  exactTime: DateTime(2000, 1, 1, 21, 15),
  startDate: DateTime(2026, 11, 2),
  endDate: DateTime(2026, 12, 2),
  sortOrder: 0,
  reviewStatus: status,
  reminderEnabled: true,
  resources: resources,
);

const _audioA = LinkedResource(
  id: 'cms-a',
  title: 'Audio A',
  type: 'audio',
  usageNote: 'Play first',
);
const _audioB = LinkedResource(
  id: 'cms-b',
  title: 'Audio B',
  type: 'audio',
  sortOrder: 1,
);
const _surah = LinkedResource(
  id: 'quran:2',
  title: 'Al-Baqarah',
  type: 'quran',
  sortOrder: 2,
);

void main() {
  test('approval keeps every field and only changes the review status', () {
    final action = _action(resources: const [_audioA, _audioB, _surah]);
    final input = approvalInputFor(action, requestId: 'req-1');
    expect(input.reviewStatus, ActionReviewStatus.approved);
    expect(input.actionId, action.id);
    expect(input.carePlanId, action.carePlanId);
    expect(input.type, action.type);
    expect(input.title, action.title);
    expect(input.instruction, action.instruction);
    expect(input.countTarget, 3);
    expect(input.durationMinutes, 20);
    expect(input.frequency.weekdays, {1, 3, 5});
    expect(input.timeWindow, 'evening');
    expect(input.exactTime, action.exactTime);
    expect(input.startDate, action.startDate);
    expect(input.endDate, action.endDate);
    expect(input.reminderEnabled, isTrue);
    // Same primary-resource rule as the action editor.
    expect(input.contentItemId, 'cms-a');
    expect(input.resourceUsageNote, 'Play first');
    // Never sent as an AI suggestion: approval is a human decision.
    expect(input.isAiSuggestion, isFalse);
  });

  test('approval restores every linked CMS resource after saving', () async {
    final repository = _FakeRepository(
      _action(resources: const [_audioA, _audioB, _surah]),
    );
    await approvePlanAction(repository, repository.actions.single);
    expect(repository.saved.single.reviewStatus, ActionReviewStatus.approved);
    // Qur'an links live in their own table and are not resent.
    expect(repository.replacedResourceIds, ['cms-a', 'cms-b']);
  });

  test('a single resource needs no extra relink call', () async {
    final repository = _FakeRepository(_action(resources: const [_audioA]));
    await approvePlanAction(repository, repository.actions.single);
    expect(repository.replacedResourceIds, isNull);
  });

  testWidgets('builder approves an action in one tap after confirming', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeRepository(_action());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [carePlansRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CarePlanBuilderScreen(patientId: 'patient-1', planId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Step 2 (review) is current while an action still needs approval.
    expect(find.byType(SukunStepper), findsOneWidget);
    expect(tester.widget<SukunStepper>(find.byType(SukunStepper)).current, 1);
    expect(find.text('1টি করণীয় যাচাই ও অনুমোদন বাকি।'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('approve-action-action-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-action-action-1')));
    await tester.pumpAndSettle();
    // The confirmation shows what is being approved.
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.textContaining('Listen calmly'),
      ),
      findsOneWidget,
    );
    expect(repository.saved, isEmpty);
    await tester.tap(find.text('অনুমোদন করুন'));
    await tester.pumpAndSettle();

    expect(repository.saved.single.reviewStatus, ActionReviewStatus.approved);
    expect(find.text('করণীয়টি অনুমোদিত হয়েছে।'), findsOneWidget);
    expect(find.byKey(const Key('approve-action-action-1')), findsNothing);
    expect(tester.widget<SukunStepper>(find.byType(SukunStepper)).current, 2);
    final publish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'রোগীর জন্য চালু করুন'),
    );
    expect(publish.onPressed, isNotNull);
  });

  testWidgets('cancelling the confirmation changes nothing', (tester) async {
    final repository = _FakeRepository(_action());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [carePlansRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(
          home: CarePlanBuilderScreen(patientId: 'patient-1', planId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('approve-action-action-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('approve-action-action-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('বাতিল'));
    await tester.pumpAndSettle();
    expect(repository.saved, isEmpty);
    expect(find.byKey(const Key('approve-action-action-1')), findsOneWidget);
  });
}

final class _FakeRepository implements CarePlansRepository {
  _FakeRepository(PlanAction action) : actions = [action];

  List<PlanAction> actions;
  final saved = <SavePlanActionInput>[];
  List<String>? replacedResourceIds;

  @override
  Future<CarePlan?> getPlan(String planId) async => _plan;

  @override
  Future<List<PlanAction>> getActions(String planId) async => actions;

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) async {
    saved.add(input);
    final old = actions.single;
    final updated = PlanAction(
      id: old.id,
      carePlanId: old.carePlanId,
      type: input.type,
      title: input.title,
      instruction: input.instruction,
      countTarget: input.countTarget,
      durationMinutes: input.durationMinutes,
      frequency: input.frequency,
      timeWindow: input.timeWindow,
      exactTime: input.exactTime,
      startDate: input.startDate,
      endDate: input.endDate,
      sortOrder: old.sortOrder,
      reviewStatus: input.reviewStatus,
      reminderEnabled: input.reminderEnabled,
      resources: old.resources,
    );
    actions = [updated];
    return updated;
  }

  @override
  Future<void> replaceActionResources({
    required String actionId,
    required List<String> resourceIds,
    required String requestId,
  }) async {
    replacedResourceIds = resourceIds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
