import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/bulk_template_import.dart';
import 'package:sukun_life/features/care_plans/domain/official_prescription_template_catalog.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/care_plans/presentation/ghusl_calendar_screen.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';
import 'package:sukun_life/features/personal_routines/domain/routine_calendar.dart';

const _detoxTemplate = OfficialPrescriptionTemplate(
  id: 'b03',
  category: 'bath',
  title: 'ডিটক্স গোসল',
  instruction: 'ডিটক্স গোসল করবেন।',
  actionType: 'bath',
  defaultTimes: [ReminderClock(10, 0)],
  resourceRefs: [],
);

void main() {
  group('calendar frequency', () {
    test('dates round-trip through JSON with the ghusl kind', () {
      final frequency = ActionFrequency.dates({
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 14),
      }, ghusl: GhuslKind.detox);
      final json = frequency.toJson();
      expect(json, {
        'type': 'dates',
        'dates': ['2026-11-14', '2026-11-20'],
        'ghusl': 'detox',
      });
      final parsed = ActionFrequency.fromJson(json);
      expect(parsed.type, ActionFrequencyType.dates);
      expect(parsed.ghusl, GhuslKind.detox);
      expect(parsed.sortedDates.first, DateTime(2026, 11, 14));
    });

    test('only b01, b02 and b03 are calendar baths', () {
      expect(GhuslKind.forTemplate('b01'), GhuslKind.nazar);
      expect(GhuslKind.forTemplate('b02'), GhuslKind.boroi);
      expect(GhuslKind.forTemplate('b03'), GhuslKind.detox);
      expect(GhuslKind.forTemplate('b04'), isNull);
    });
  });

  group('bulk import rows', () {
    test('a calendar bath is not ready until dates are chosen', () {
      final item = BulkImportItem.template(_detoxTemplate);
      expect(item.ghuslKind, GhuslKind.detox);
      expect(item.isReady, isFalse);
      expect(item.problem, isNotNull);
      item.calendarDates.add(DateTime(2026, 11, 20));
      expect(item.isReady, isTrue);
      final draft = item.expand().single;
      expect(draft.dates, {DateTime(2026, 11, 20)});
      expect(draft.toRoutineJson()['active_dates'], ['2026-11-20']);
      expect(draft.toRoutineJson()['ghusl_kind'], 'detox');
    });
  });

  test('a calendar bath fills its day count from the chosen dates', () {
    const nazar = OfficialPrescriptionTemplate(
      id: 'b01',
      category: 'bath',
      title: 'বদনজরের গোসল',
      instruction: '{দিন} দিন গোসল করবেন।',
      actionType: 'bath',
      defaultTimes: [ReminderClock(10, 0)],
      resourceRefs: [],
    );
    final item = BulkImportItem.template(nazar);
    expect(item.missingVariables, isNotEmpty);
    item.calendarDates.addAll({DateTime(2026, 11, 14), DateTime(2026, 11, 21)});
    expect(item.missingVariables, isEmpty);
    expect(item.instruction, '২ দিন গোসল করবেন।');
  });

  group('routine detox days', () {
    final daily = {
      'id': '11111111-1111-4111-8111-111111111111',
      'routine_id': 'r',
      'title': 'সকালের আমল',
      'notification_title': 'সকালের আমল',
      'schedule_kind': 'fixed',
      'local_time': '11:00:00',
      'is_active': true,
    };
    final detox = {
      'id': '22222222-2222-4222-8222-222222222222',
      'routine_id': 'r',
      'title': 'ডিটক্স গোসল',
      'notification_title': 'ডিটক্স গোসল',
      'schedule_kind': 'fixed',
      'local_time': '10:00:00',
      'is_active': true,
      'active_dates': ['2026-11-14'],
      'ghusl_kind': 'detox',
    };

    test('a detox day pauses every other step', () {
      final detoxDates = routineDetoxDates([daily, detox]);
      expect(detoxDates, {'2026-11-14'});
      final day = DateTime(2026, 11, 14);
      expect(routineActionRunsOn(daily, day, detoxDates: detoxDates), isFalse);
      expect(routineActionRunsOn(detox, day, detoxDates: detoxDates), isTrue);
      final next = DateTime(2026, 11, 15);
      expect(routineActionRunsOn(daily, next, detoxDates: detoxDates), isTrue);
      expect(routineActionRunsOn(detox, next, detoxDates: detoxDates), isFalse);
    });

    test('reminders skip other steps on the detox day', () {
      final reminders = planPersonalRoutineReminders(
        ownerId: 'owner',
        actions: [daily, detox],
        activeRoutineIds: {'r'},
        calculator: AdhanPrayerCalculationService(),
        settings: const PrayerUtilitySettings(),
        now: DateTime(2026, 11, 13, 12),
        horizonDays: 3,
      );
      final byDay = [
        for (final r in reminders) '${r.scheduledAt.day}:${r.title}',
      ];
      expect(byDay, ['14:ডিটক্স গোসল', '15:সকালের আমল']);
    });
  });

  testWidgets('calendar marks days per bath and returns them', (tester) async {
    Map<GhuslKind, Set<DateTime>>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showGhuslCalendar(
                context,
                initial: const {},
                today: DateTime(2026, 11, 13),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ghusl-day-2026-11-14')));
    await tester.tap(find.byKey(const Key('ghusl-kind-detox')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('ghusl-day-2026-11-20')));
    await tester.tap(find.byKey(const Key('ghusl-day-2026-11-20')));
    await tester.pump();
    // Past days cannot be picked.
    await tester.tap(
      find.byKey(const Key('ghusl-day-2026-11-01')),
      warnIfMissed: false,
    );
    await tester.tap(find.byKey(const Key('ghusl-calendar-save')));
    await tester.pumpAndSettle();

    expect(result![GhuslKind.nazar], {DateTime(2026, 11, 14)});
    expect(result![GhuslKind.detox], {DateTime(2026, 11, 20)});
    expect(result![GhuslKind.boroi], isEmpty);
  });
}
