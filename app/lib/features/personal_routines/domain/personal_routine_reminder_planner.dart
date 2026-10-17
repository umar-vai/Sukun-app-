import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';

/// Bounded schedule of future reminders. This does not claim background
/// delivery on Web; that depends on the gateway and active-tab state.
List<ReminderSchedule> planPersonalRoutineReminders({
  required String ownerId,
  required Iterable<Map<String, dynamic>> actions,
  required Set<String> activeRoutineIds,
  required PrayerCalculationService calculator,
  required PrayerUtilitySettings settings,
  required DateTime now,
  int horizonDays = 14,
  int maximumPending = 48,
}) {
  final reminders = <ReminderSchedule>[];
  for (final action in actions) {
    if (action['is_active'] != true ||
        !activeRoutineIds.contains(action['routine_id'])) {
      continue;
    }
    final id = action['id'] as String?;
    if (id == null || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) continue;
    final kind = action['schedule_kind'] as String?;
    if (!['fixed', 'fajr', 'maghrib'].contains(kind)) continue;

    for (var day = 0; day < horizonDays; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      DateTime? time;
      if (kind == 'fixed') {
        final parts = (action['local_time'] as String? ?? '').split(':');
        if (parts.length < 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null ||
            hour > 23 ||
            hour < 0 ||
            minute == null ||
            minute > 59 ||
            minute < 0) {
          continue;
        }
        time = DateTime(date.year, date.month, date.day, hour, minute);
      } else {
        // Do not guess city or method. If the saved schedule no longer matches
        // the device's prayer preferences, require an explicit reconfiguration.
        if (!settings.isComplete ||
            action['timezone_name'] != settings.location?.timezone ||
            action['prayer_method'] != settings.calculationMethod?.id) {
          continue;
        }
        final offset = action['prayer_offset_minutes'] as int? ?? 10;
        if (offset < 0 || offset > 120) continue;
        try {
          time =
              PrayerRelativeReminder(
                anchor: kind == 'fajr'
                    ? PrayerReminderAnchor.fajr
                    : PrayerReminderAnchor.maghrib,
                minutesAfter: offset,
              ).nextOccurrence(
                calculator: calculator,
                settings: settings,
                after: date.subtract(const Duration(seconds: 1)),
              );
        } catch (_) {
          continue;
        }
        if (time.year != date.year ||
            time.month != date.month ||
            time.day != date.day) {
          continue;
        }
      }

      if (!time.isAfter(now)) continue;
      final dateKey = '${date.year}-${date.month}-${date.day}';
      reminders.add(
        ReminderSchedule(
          notificationId: stableNotificationId(
            'personal:$ownerId:$id:$dateKey',
          ),
          taskId: '',
          actionId: id,
          title: action['notification_title'] as String? ?? 'সুকুন লাইফ',
          body: 'আপনার রুটিন খুলে আজকের করণীয় সম্পন্ন করুন।',
          scheduledAt: time,
          payload: 'personal_action:$id',
        ),
      );
    }
  }
  reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return List.unmodifiable(reminders.take(maximumPending));
}
