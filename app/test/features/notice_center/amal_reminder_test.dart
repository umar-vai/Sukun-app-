import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/care_plans/domain/plan_action.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/notice_center/domain/amal_reminder.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';

void main() {
  final now = DateTime(2026, 11, 20, 18, 0);

  group('care amal reminders', () {
    test('lists only open tasks whose reminder time has passed', () {
      final due = dueCareReminders([
        _task('rang', hour: 9),
        _task('later', hour: 21),
        _task('done', hour: 8, status: PatientTaskStatus.completed),
        _task('skipped', hour: 8, status: PatientTaskStatus.skipped),
        _task('no-reminder', hour: 8, reminderEnabled: false),
      ], now: now);

      expect(due.map((item) => item.id), ['rang']);
      expect(due.single.kind, AmalReminderKind.care);
      expect(due.single.route, '/patient/today?task=rang');
      expect(due.single.task, isNotNull);
    });

    test('a snoozed task waits for its snooze time', () {
      final snoozed = _task(
        'snoozed',
        hour: 9,
        status: PatientTaskStatus.snoozed,
        snoozedUntil: DateTime(2026, 11, 20, 18, 30),
      );

      expect(dueCareReminders([snoozed], now: now), isEmpty);
      expect(
        dueCareReminders([snoozed], now: DateTime(2026, 11, 20, 18, 31)),
        hasLength(1),
      );
    });

    test('shows the admin-set reminder name when there is one', () {
      final due = dueCareReminders([
        _task('named', hour: 9, notificationTitle: 'সকালের আমল'),
      ], now: now);

      expect(due.single.title, 'সকালের আমল');
    });
  });

  group('personal amal reminders', () {
    final calculator = AdhanPrayerCalculationService();
    const settings = PrayerUtilitySettings();

    List<AmalReminder> due(
      List<Map<String, dynamic>> actions, {
      Map<String, String> outcomes = const {},
      Set<String> routines = const {'routine-1'},
    }) => duePersonalReminders(
      actions: actions,
      activeRoutineIds: routines,
      todaysOutcomes: outcomes,
      calculator: calculator,
      settings: settings,
      now: now,
    );

    test('lists fixed-time actions that rang today without a check-in', () {
      final result = due([_action('a1', '07:30'), _action('a2', '20:00')]);

      expect(result.map((item) => item.id), ['a1']);
      expect(result.single.kind, AmalReminderKind.personal);
      expect(result.single.dueAt, DateTime(2026, 11, 20, 7, 30));
      expect(result.single.route, '/my-routines/action/a1?fromReminder=1');
    });

    test('done or skipped actions and paused routines are left out', () {
      expect(due([_action('a1', '07:30')], outcomes: {'a1': 'done'}), isEmpty);
      expect(
        due([_action('a1', '07:30')], outcomes: {'a1': 'skipped'}),
        isEmpty,
      );
      expect(due([_action('a1', '07:30')], routines: const {}), isEmpty);
      expect(due([_action('a1', '07:30', active: false)]), isEmpty);
    });
  });

  test('most recent reminder is listed first', () {
    final sorted = sortAmalReminders([
      AmalReminder(
        kind: AmalReminderKind.personal,
        id: 'early',
        title: 'early',
        dueAt: DateTime(2026, 11, 20, 7),
        route: '/a',
      ),
      AmalReminder(
        kind: AmalReminderKind.personal,
        id: 'late',
        title: 'late',
        dueAt: DateTime(2026, 11, 20, 17),
        route: '/b',
      ),
    ]);

    expect(sorted.map((item) => item.id), ['late', 'early']);
  });
}

Map<String, dynamic> _action(String id, String time, {bool active = true}) => {
  'id': id,
  'routine_id': 'routine-1',
  'title': 'রুটিন $id',
  'schedule_kind': 'fixed',
  'local_time': time,
  'is_active': active,
};

PatientTask _task(
  String id, {
  required int hour,
  PatientTaskStatus status = PatientTaskStatus.pending,
  bool reminderEnabled = true,
  DateTime? snoozedUntil,
  String? notificationTitle,
}) {
  final date = DateTime(2026, 11, 20);
  return PatientTask(
    id: id,
    patientId: 'patient-id',
    occurrenceDate: date,
    scheduledAt: DateTime(2026, 11, 20, hour),
    status: status,
    snoozedUntil: snoozedUntil,
    action: PlanAction(
      id: 'action-$id',
      carePlanId: 'plan-id',
      type: 'recitation',
      title: 'Approved care action',
      frequency: const ActionFrequency.daily(),
      startDate: date,
      sortOrder: 0,
      reviewStatus: ActionReviewStatus.approved,
      reminderEnabled: reminderEnabled,
      exactTime: DateTime(2000, 1, 1, hour),
      notificationTitle: notificationTitle,
    ),
  );
}
