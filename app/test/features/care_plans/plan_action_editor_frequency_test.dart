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
import 'package:sukun_life/features/care_plans/presentation/plan_action_editor_screen.dart';

void main() {
  testWidgets('editing a title keeps the existing every-three-days interval', (
    tester,
  ) async {
    final repo = _EditorRepository(const ActionFrequency.daily(interval: 3));
    await _openEditor(tester, repo);

    final interval = find.byKey(const Key('daily-interval-field'));
    expect(interval, findsOneWidget);
    expect(tester.widget<TextFormField>(interval).controller?.text, '3');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Updated instruction',
    );
    await _save(tester);

    expect(repo.saved, isNotNull);
    expect(repo.saved!.title, 'Updated instruction');
    expect(repo.saved!.frequency.type, ActionFrequencyType.daily);
    expect(repo.saved!.frequency.interval, 3);
    expect(repo.saved!.reviewStatus, ActionReviewStatus.approved);
  });

  testWidgets('admin can explicitly change the number of days', (tester) async {
    final repo = _EditorRepository(const ActionFrequency.daily(interval: 7));
    await _openEditor(tester, repo);
    await tester.enterText(find.byKey(const Key('daily-interval-field')), '2');
    await _save(tester);

    expect(repo.saved?.frequency.toJson(), {'type': 'daily', 'interval': 2});
  });

  testWidgets(
    'zero or missing recurrence interval cannot silently become daily',
    (tester) async {
      final repo = _EditorRepository(const ActionFrequency.daily(interval: 2));
      await _openEditor(tester, repo);

      await tester.enterText(
        find.byKey(const Key('daily-interval-field')),
        '0',
      );
      await _save(tester);
      expect(repo.saved, isNull);
      expect(find.text('১ বা তার বেশি একটি সংখ্যা লিখুন।'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('daily-interval-field')), '');
      await _save(tester);
      expect(repo.saved, isNull);
    },
  );

  testWidgets('weekly dates remain unchanged on a title-only edit', (
    tester,
  ) async {
    final repo = _EditorRepository(const ActionFrequency.weekly({2, 4}));
    await _openEditor(tester, repo);
    expect(find.byKey(const Key('daily-interval-field')), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Updated weekly action',
    );
    await _save(tester);
    expect(repo.saved?.frequency.toJson(), {
      'type': 'weekly',
      'weekdays': [2, 4],
    });
  });
}

Future<void> _openEditor(WidgetTester tester, _EditorRepository repo) async {
  // This suite asserts save semantics, not short-viewport scroll behavior.
  // Keep the full form visible so test taps are genuine hits.
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/edit'),
            child: const Text('Open editor'),
          ),
        ),
      ),
      GoRoute(
        path: '/edit',
        builder: (context, state) => const PlanActionEditorScreen(
          planId: 'plan-1',
          actionId: 'action-1',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [carePlansRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final button = find.text('Save action');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

final class _EditorRepository implements CarePlansRepository {
  _EditorRepository(this.frequency);

  final ActionFrequency frequency;
  SavePlanActionInput? saved;

  final plan = CarePlan(
    id: 'plan-1',
    patientId: 'patient-1',
    version: 1,
    name: 'Test plan',
    startDate: DateTime(2026, 10, 1),
    status: CarePlanStatus.draft,
    createdAt: DateTime(2026, 10, 1),
  );

  PlanAction get action => PlanAction(
    id: 'action-1',
    carePlanId: 'plan-1',
    type: 'recitation',
    title: 'Existing action',
    frequency: frequency,
    startDate: plan.startDate,
    sortOrder: 0,
    reviewStatus: ActionReviewStatus.approved,
    reminderEnabled: false,
  );

  @override
  Future<CarePlan?> getPlan(String planId) async => plan;

  @override
  Future<List<PlanAction>> getActions(String planId) async => [action];

  @override
  Future<List<ContentResourceOption>> getAvailableResources() async => [];

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) async {
    saved = input;
    return action;
  }

  @override
  Future<CarePlan> archivePlan(String planId, String requestId) =>
      throw UnimplementedError();

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) =>
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
}
