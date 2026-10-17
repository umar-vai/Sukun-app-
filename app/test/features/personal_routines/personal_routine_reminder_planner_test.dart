import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/domain/personal_routine_reminder_planner.dart';

void main() {
  const actionId = 'a4ba5d60-81df-4688-81c8-b1064f7cf45e';
  const routineId = 'b4ba5d60-81df-4688-81c8-b1064f7cf45e';
  const ownerId = 'c4ba5d60-81df-4688-81c8-b1064f7cf45e';

  test('fixed-time reminder has direct safe personal action payload', () {
    final rows = [
      {
        'id': actionId,
        'routine_id': routineId,
        'is_active': true,
        'schedule_kind': 'fixed',
        'local_time': '22:00:00',
        'notification_title': 'ঘুমানোর আগের আমল',
      },
    ];
    final reminders = planPersonalRoutineReminders(
      ownerId: ownerId,
      actions: rows,
      activeRoutineIds: {routineId},
      calculator: AdhanPrayerCalculationService(),
      settings: const PrayerUtilitySettings(),
      now: DateTime(2026, 10, 17, 9),
      horizonDays: 2,
    );
    expect(reminders, hasLength(2));
    expect(reminders.first.scheduledAt, DateTime(2026, 10, 17, 22));
    expect(reminders.first.payload, 'personal_action:$actionId');
    expect(reminders.first.title, 'ঘুমানোর আগের আমল');
    expect(reminders.first.notificationId, isNot(reminders.last.notificationId));
  });

  test('inactive or paused routine and missing prayer location cannot schedule', () {
    final rows = [
      {
        'id': actionId,
        'routine_id': routineId,
        'is_active': true,
        'schedule_kind': 'maghrib',
        'timezone_name': 'Asia/Dhaka',
        'prayer_method': 'karachi',
        'prayer_offset_minutes': 10,
      },
    ];
    final withoutPrefs = planPersonalRoutineReminders(
      ownerId: ownerId,
      actions: rows,
      activeRoutineIds: {routineId},
      calculator: AdhanPrayerCalculationService(),
      settings: const PrayerUtilitySettings(),
      now: DateTime(2026, 10, 17, 9),
    );
    final paused = planPersonalRoutineReminders(
      ownerId: ownerId,
      actions: rows,
      activeRoutineIds: {},
      calculator: AdhanPrayerCalculationService(),
      settings: const PrayerUtilitySettings(),
      now: DateTime(2026, 10, 17, 9),
    );
    expect(withoutPrefs, isEmpty);
    expect(paused, isEmpty);
  });
}
