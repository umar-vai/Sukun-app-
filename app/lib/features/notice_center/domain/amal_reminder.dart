import 'package:sukun_life/core/notifications/notification_tap_relay.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/patient_care/domain/patient_task.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';
import 'package:sukun_life/features/personal_routines/domain/routine_calendar.dart';

enum AmalReminderKind { care, personal }

/// One amal whose reminder time has passed today and which is still open.
/// It is derived from server data, so a missed or dismissed phone
/// notification still leaves the amal here until it is done or skipped.
class AmalReminder {
  const AmalReminder({
    required this.kind,
    required this.id,
    required this.title,
    required this.dueAt,
    required this.route,
    this.task,
  });

  final AmalReminderKind kind;

  /// Care task ID or personal routine action ID.
  final String id;
  final String title;
  final DateTime dueAt;

  /// Same destination a notification tap opens.
  final String route;

  /// The care task, for in-place completion. Null for personal actions.
  final PatientTask? task;

  String get originBn => switch (kind) {
    AmalReminderKind.care => 'সুকুনের পরিকল্পনা',
    AmalReminderKind.personal => 'আমার রুটিন',
  };
}

/// Care tasks whose reminder has rung by [now] and are still open.
List<AmalReminder> dueCareReminders(
  Iterable<PatientTask> tasks, {
  required DateTime now,
}) => [
  for (final task in tasks)
    if (careReminderTime(task) case final due? when !due.isAfter(now))
      AmalReminder(
        kind: AmalReminderKind.care,
        id: task.id,
        title: task.action.notificationTitle ?? task.action.title,
        dueAt: due,
        route: patientTodayTaskRoute(task.id),
        task: task,
      ),
];

/// Personal routine actions whose reminder rang today by [now] and have no
/// done or skipped check-in yet. Uses the same times as the phone alarms.
List<AmalReminder> duePersonalReminders({
  required Iterable<Map<String, dynamic>> actions,
  required Set<String> activeRoutineIds,
  required Map<String, String> todaysOutcomes,
  required PrayerCalculationService calculator,
  required PrayerUtilitySettings settings,
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final active = [
    for (final action in actions)
      if (action['is_active'] == true &&
          activeRoutineIds.contains(action['routine_id']))
        action,
  ];
  final detoxDates = routineDetoxDates(active);
  final due = <AmalReminder>[];
  for (final action in active) {
    final id = action['id'];
    if (id is! String) continue;
    final outcome = todaysOutcomes[id];
    if (outcome == 'done' || outcome == 'completed' || outcome == 'skipped') {
      continue;
    }
    final time = personalReminderTimeOn(
      action,
      today,
      detoxDates: detoxDates,
      calculator: calculator,
      settings: settings,
    );
    if (time == null || time.isAfter(now)) continue;
    final title =
        action['notification_title'] as String? ??
        action['title'] as String? ??
        'আমার রুটিন';
    due.add(
      AmalReminder(
        kind: AmalReminderKind.personal,
        id: id,
        title: title,
        dueAt: time,
        route: personalActionRoute(id),
      ),
    );
  }
  return due;
}

/// Most recent reminder first, so the amal just missed is on top.
List<AmalReminder> sortAmalReminders(Iterable<AmalReminder> items) =>
    List.unmodifiable(
      items.toList()..sort((a, b) => b.dueAt.compareTo(a.dueAt)),
    );
