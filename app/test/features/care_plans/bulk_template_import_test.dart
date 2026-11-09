import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/data/bulk_care_plan_importer.dart';
import 'package:sukun_life/features/care_plans/data/care_plans_repository.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan.dart';
import 'package:sukun_life/features/care_plans/domain/care_plan_inputs.dart';
import 'package:sukun_life/features/care_plans/domain/content_resource_option.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/bulk_template_import_screen.dart';

const _audio = ContentResourceOption(
  id: '11111111-1111-4111-8111-111111111111',
  title: 'Sihr Hibshi Ruqyah',
  titleBn: 'সিহর হিবশী রুকইয়াহ',
  type: 'audio',
  visibility: 'public',
  status: 'published',
);

void main() {
  group('defaults', () {
    test('every official template has at least one editable time', () {
      for (final template in officialPrescriptionTemplates) {
        expect(defaultTimesForTemplate(template), isNotEmpty);
      }
      final morningEvening = defaultTimesForTemplate(
        findOfficialTemplate('a01')!,
      );
      expect(morningEvening.map((t) => t.timeWindow), ['morning', 'evening']);
    });

    test('reminder clock maps to plan time windows and Bangla labels', () {
      expect(const ReminderClock(6, 30).timeWindow, 'morning');
      expect(const ReminderClock(13, 0).timeWindow, 'afternoon');
      expect(const ReminderClock(18, 0).timeWindow, 'evening');
      expect(const ReminderClock(22, 0).timeWindow, 'night');
      expect(const ReminderClock(6, 30).label, 'সকাল ৬:৩০');
      expect(const ReminderClock(21, 5).databaseValue, '21:05:00');
    });
  });

  group('items', () {
    test('counts are never guessed: placeholders block until chosen', () {
      final item = BulkImportItem.template(findOfficialTemplate('a08')!);
      expect(item.missingVariables, ['বার']);
      expect(item.isReady, isFalse);
      item.variables['বার'] = 100;
      expect(item.isReady, isTrue);
      expect(item.instruction, contains('১০০'));
    });

    test('audio template needs a resource; suggestion fills it', () {
      final template = findOfficialTemplate('u07')!;
      final item = BulkImportItem.template(template)..variables['মিনিট'] = 30;
      expect(item.needsResource, isTrue);
      expect(suggestResourceForTemplate(template, const [_audio]), _audio);
      item.resourceIds.add(_audio.id);
      expect(item.isReady, isTrue);
    });

    test('two times become two titled actions', () {
      final item = BulkImportItem.template(findOfficialTemplate('a01')!);
      final drafts = item.expand();
      expect(drafts, hasLength(2));
      expect(drafts.first.title, 'সকাল–সন্ধ্যার মাসনুন আমল (সকাল)');
      expect(drafts.last.title, 'সকাল–সন্ধ্যার মাসনুন আমল (সন্ধ্যা)');
      expect(drafts.first.toRoutineJson()['local_time'], '06:30:00');
      expect(drafts.first.toRoutineJson()['official_template_id'], 'a01');
    });

    test('library resources link themselves, surahs use canonical refs', () {
      const surah = ContentResourceOption(
        id: 'quran:36',
        title: 'Ya-Sin',
        type: 'quran',
        visibility: 'public',
        status: 'published',
      );
      final draft = BulkImportItem.resource(surah).expand().single;
      expect(draft.quranSurahNumbers, [36]);
      expect(draft.cmsResourceIds, isEmpty);
      expect(draft.toRoutineJson()['resources'], [
        {'provider': 'quran', 'external_resource_ref': 'quran:36'},
      ]);
    });
  });

  group('patient importer', () {
    test(
      'no plan yet: creates, approves with reminders and publishes',
      () async {
        final repo = _FakeRepo();
        final item = BulkImportItem.template(findOfficialTemplate('a02')!);
        final result = await BulkCarePlanImporter(repo).import(
          patientId: 'p1',
          items: [item, BulkImportItem.resource(_audio)],
          resourceLookup: const {},
          now: DateTime(2026, 11, 9, 10),
        );
        expect(repo.created.single.copyFromPlanId, isNull);
        expect(repo.saved, hasLength(2));
        expect(
          repo.saved.every(
            (s) =>
                s.reviewStatus == ActionReviewStatus.approved &&
                s.reminderEnabled &&
                s.exactTime != null,
          ),
          isTrue,
        );
        expect(repo.saved.first.timeWindow, 'night');
        expect(repo.linked[repo.saved.last.title], [_audio.id]);
        expect(result.published, isTrue);
        expect(result.actionsAdded, 2);
      },
    );

    test('live plan: new version keeps old actions approved', () async {
      final repo = _FakeRepo()
        ..plans.add(_plan('live', CarePlanStatus.active))
        ..copyOnCreate = true;
      final result = await BulkCarePlanImporter(repo).import(
        patientId: 'p1',
        items: [BulkImportItem.template(findOfficialTemplate('a03')!)],
        resourceLookup: const {},
        now: DateTime(2026, 11, 9),
      );
      expect(repo.created.single.copyFromPlanId, 'live');
      expect(
        repo.saved.where((s) => s.actionId == 'copied-1').single.reviewStatus,
        ActionReviewStatus.approved,
      );
      expect(result.published, isTrue);
    });

    test('open draft with unreviewed AI rows is not auto-published', () async {
      final repo = _FakeRepo()
        ..plans.add(_plan('draft', CarePlanStatus.draft))
        ..actions.add(_action('ai-1', ActionReviewStatus.needsReview));
      final result = await BulkCarePlanImporter(repo).import(
        patientId: 'p1',
        items: [
          BulkImportItem.template(findOfficialTemplate('a03')!)
            ..durationDays = 7,
        ],
        resourceLookup: const {},
        now: DateTime(2026, 11, 9),
      );
      expect(repo.created, isEmpty);
      expect(result.published, isFalse);
      expect(repo.publishCount, 0);
      expect(repo.saved.single.endDate, DateTime(2026, 11, 15));
      // The AI row was not silently approved.
      expect(repo.saved.any((s) => s.actionId == 'ai-1'), isFalse);
    });
  });

  testWidgets('select a whole category and confirm in one tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    List<BulkImportItem>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showBulkTemplateImport(
                  context,
                  recipientLabel: 'রোগী: Test',
                  resources: Future.value(const [_audio]),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('গোসল'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('সব বাছুন').first);
    await tester.pumpAndSettle();
    // Bath templates need day counts, so the import is blocked with a reason.
    await tester.tap(find.byKey(const Key('bulk-import-confirm')));
    await tester.pump();
    expect(find.textContaining('সংখ্যা বাছুন'), findsWidgets);
    expect(result, isNull);

    await tester.tap(find.text('বাদ দিন').first);
    await tester.tap(find.text('আমল'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bulk-template-a01')));
    await tester.tap(find.byKey(const Key('bulk-template-a02')));
    await tester.pumpAndSettle();
    expect(find.textContaining('৩টি দৈনিক রিমাইন্ডার'), findsOneWidget);
    await tester.tap(find.byKey(const Key('bulk-import-confirm')));
    await tester.pumpAndSettle();
    expect(result!.map((i) => i.templateId), ['a01', 'a02']);
    expect(tester.takeException(), isNull);
  });
}

CarePlan _plan(String id, CarePlanStatus status) => CarePlan(
  id: id,
  patientId: 'p1',
  version: 1,
  name: 'Plan',
  startDate: DateTime(2026, 11),
  status: status,
  createdAt: DateTime(2026, 11),
);

PlanAction _action(String id, ActionReviewStatus status) => PlanAction(
  id: id,
  carePlanId: 'draft',
  type: 'amal',
  title: 'Row $id',
  frequency: const ActionFrequency.daily(),
  startDate: DateTime(2026, 11),
  sortOrder: 0,
  reviewStatus: status,
  reminderEnabled: true,
);

final class _FakeRepo implements CarePlansRepository {
  final plans = <CarePlan>[];
  final actions = <PlanAction>[];
  final created = <CreateCarePlanInput>[];
  final saved = <SavePlanActionInput>[];
  final linked = <String, List<String>>{};
  bool copyOnCreate = false;
  int publishCount = 0;
  int _ids = 0;

  @override
  Future<List<CarePlan>> getPatientPlans(String patientId) async => plans;

  @override
  Future<CarePlan> createDraft(CreateCarePlanInput input) async {
    created.add(input);
    if (copyOnCreate) {
      actions.add(_action('copied-1', ActionReviewStatus.needsReview));
    }
    return _plan('new-draft', CarePlanStatus.draft);
  }

  @override
  Future<List<PlanAction>> getActions(String planId) async => List.of(actions);

  @override
  Future<PlanAction> saveAction(SavePlanActionInput input) async {
    saved.add(input);
    final id = input.actionId ?? 'new-${_ids++}';
    actions.removeWhere((a) => a.id == id);
    final action = _action(id, input.reviewStatus);
    actions.add(action);
    _titles[id] = input.title;
    return action;
  }

  final _titles = <String, String>{};

  @override
  Future<void> replaceActionResources({
    required String actionId,
    required List<String> resourceIds,
    required String requestId,
  }) async {
    linked[_titles[actionId]!] = resourceIds;
  }

  @override
  Future<CarePlan> publishPlan(String planId, String requestId) async {
    publishCount++;
    return _plan(planId, CarePlanStatus.active);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
