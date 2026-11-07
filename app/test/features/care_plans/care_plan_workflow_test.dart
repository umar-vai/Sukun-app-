import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sukun_life/features/care_plans/data/bulk_prescription_repository.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_providers.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_builder_screen.dart';
import 'package:sukun_life/features/care_plans/presentation/care_plan_preview_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'Studio sends the existing plan notice only after a successful publish',
    () async {
      final requests = <http.Request>[];
      var rejectPublish = true;
      final client = SupabaseClient(
        'https://synthetic.supabase.test',
        'synthetic-public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/publish_prescription_studio') &&
              rejectPublish) {
            return http.Response(
              '{"code":"40001","message":"The saved actions changed before publication."}',
              409,
              headers: {'Content-Type': 'application/json'},
              request: request,
            );
          }
          return http.Response(
            '{"status":"active"}',
            200,
            headers: {'Content-Type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final repository = BulkPrescriptionRepository(client);
      final actions = [_FakeCarePlansRepository().unreviewedAction];
      await expectLater(
        repository.publish('synthetic-plan', actions, 'synthetic-request'),
        throwsA(isA<CarePlanWorkflowException>()),
      );
      expect(requests, hasLength(1));

      rejectPublish = false;
      await repository.publish('synthetic-plan', actions, 'synthetic-request');
      expect(requests.map((request) => request.url.path), [
        '/rest/v1/rpc/publish_prescription_studio',
        '/rest/v1/rpc/publish_prescription_studio',
        '/functions/v1/send-notification',
      ]);
      expect(jsonDecode(requests.last.body), {
        'type': 'plan_updated',
        'care_plan_id': 'synthetic-plan',
        'request_id': 'synthetic-request',
      });
    },
  );

  for (final size in const [Size(360, 640), Size(430, 932), Size(1440, 900)]) {
    testWidgets('bulk studio fits ${size.width} x ${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            carePlansRepositoryProvider.overrideWithValue(
              _FakeCarePlansRepository(),
            ),
          ],
          child: const MaterialApp(
            home: RepaintBoundary(
              key: Key('studio-visual'),
              child: CarePlanBuilderScreen(
                patientId: 'patient-1',
                planId: 'plan-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('রোগীর পরিকল্পনা সাজান'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
              'status': 'published',
              'visibility': 'patient_only',
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

  testWidgets('100 draft actions are lazily rendered and remain reachable', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carePlansRepositoryProvider.overrideWithValue(
            _LargeCarePlansRepository(),
          ),
        ],
        child: const MaterialApp(
          home: CarePlanBuilderScreen(patientId: 'patient-1', planId: 'plan-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile).evaluate().length, lessThan(100));
    await tester.scrollUntilVisible(
      find.text('Synthetic action 99'),
      800,
      maxScrolls: 60,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Synthetic action 99'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('private preview shows the saved actions before publishing', (
    tester,
  ) async {
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
    expect(find.text('Unreviewed internal action'), findsOneWidget);
    expect(find.text('Assigned recording'), findsOneWidget);
    expect(find.textContaining('Preview only'), findsOneWidget);
  });

  testWidgets('saved actions need no individual approval control', (
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

    expect(find.text('1টি করণীয় যাচাই ও অনুমোদন বাকি।'), findsNothing);
    final publishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'রোগীর জন্য চালু করুন'),
    );
    expect(publishButton.onPressed, isNotNull);
    await tester.tap(find.text('সব করণীয় বাছুন'));
    await tester.pumpAndSettle();
    expect(find.text('2 নির্বাচিত'), findsOneWidget);
  });

  testWidgets('new plan opens its first action without another tap', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/admin/patients/patient-1/plans/plan-1?addAction=1',
      routes: [
        GoRoute(
          path: '/admin/patients/:patientId/plans/:planId',
          builder: (context, state) => CarePlanBuilderScreen(
            patientId: state.pathParameters['patientId']!,
            planId: state.pathParameters['planId']!,
            openNewAction: state.uri.queryParameters['addAction'] == '1',
          ),
          routes: [
            GoRoute(
              path: 'actions/new',
              builder: (context, state) =>
                  const Scaffold(body: Text('New action editor')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carePlansRepositoryProvider.overrideWithValue(
            _FakeCarePlansRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New action editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
        overrides: [
          carePlansRepositoryProvider.overrideWithValue(repository),
          bulkPrescriptionRepositoryProvider.overrideWithValue(
            _PublishingStudioRepository(repository),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.published, isFalse);
    await tester.tap(find.text('রোগীর জন্য চালু করুন'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.published, isTrue);
    expect(find.text('চালু'), findsOneWidget);
  });
}

class _FakeCarePlansRepository implements CarePlansRepository {
  @override
  Future<void> replaceActionQuranSurahs({
    required String actionId,
    required List<ContentResourceOption> surahs,
    required String requestId,
  }) async {}
  @override
  Future<void> replaceActionResources({
    required String actionId,
    required List<String> resourceIds,
    required String requestId,
  }) async => throw UnimplementedError();

  @override
  Future<void> archiveEmptyDraftForPrescriptionImport({
    required String patientId,
    required String planId,
    required String requestId,
  }) async => throw UnimplementedError();

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

final class _LargeCarePlansRepository extends _FakeCarePlansRepository {
  @override
  Future<List<PlanAction>> getActions(String planId) async => [
    for (var index = 0; index < 100; index++)
      PlanAction(
        id: 'synthetic-$index',
        carePlanId: plan.id,
        type: 'amal',
        title: 'Synthetic action $index',
        frequency: const ActionFrequency.daily(),
        startDate: plan.startDate,
        sortOrder: index,
        reviewStatus: ActionReviewStatus.needsReview,
        reminderEnabled: false,
      ),
  ];
}

final class _PublishingCarePlansRepository extends _FakeCarePlansRepository {
  bool published = false;

  @override
  Future<List<PlanAction>> getActions(String planId) async =>
      published ? [approvedAction] : [approvedAction, unreviewedAction];

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
}

final class _PublishingStudioRepository extends BulkPrescriptionRepository {
  const _PublishingStudioRepository(this.repository) : super(null);

  final _PublishingCarePlansRepository repository;

  @override
  Future<void> publish(
    String planId,
    List<PlanAction> actions,
    String requestId,
  ) async {
    expect(planId, repository.plan.id);
    expect(actions, [repository.approvedAction, repository.unreviewedAction]);
    repository.published = true;
  }
}
