import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/patient_care/domain/patient_day.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';

/// A display-only link to an RLS-visible patient task or owner-owned routine.
/// This never persists or mutates clinical plans.
class HomeNextAction {
  const HomeNextAction({
    required this.id,
    required this.title,
    required this.origin,
    required this.route,
    this.dueAt,
  });

  final String id;
  final String title;
  final String origin;
  final String route;
  final DateTime? dueAt;
}

abstract final class HomeNextActions {
  static List<HomeNextAction> select({
    required DateTime now,
    required PatientDay? patientDay,
    required List<Map<String, dynamic>> routines,
    required List<Map<String, dynamic>> actions,
    required Map<String, String> outcomes,
    required PrayerUtilitySettings settings,
    required PrayerCalculationService calculator,
  }) {
    final selected = <HomeNextAction>[];
    if (patientDay != null && patientDay.activePlan != null) {
      for (final task in patientDay.tasks) {
        if (!task.status.canUpdate) continue;
        selected.add(
          HomeNextAction(
            id: task.id,
            title: task.action.title,
            origin: 'সুকুনের অনুমোদিত পরিকল্পনা',
            route: '/patient/today?task=${Uri.encodeQueryComponent(task.id)}',
            dueAt: task.snoozedUntil ?? task.scheduledAt,
          ),
        );
      }
    }

    final enabledRoutines = <String>{
      for (final routine in routines)
        if (routine['is_active'] == true && routine['id'] is String)
          routine['id'] as String,
    };
    for (final action in actions) {
      final id = action['id'];
      final routineId = action['routine_id'];
      final title = action['title'];
      if (id is! String ||
          routineId is! String ||
          title is! String ||
          title.trim().isEmpty ||
          action['is_active'] != true ||
          !enabledRoutines.contains(routineId)) {
        continue;
      }

      final doneToday = outcomes[id] == 'done' ||
          outcomes[id] == 'completed' ||
          outcomes[id] == 'skipped';
      final kind = action['schedule_kind'] as String? ?? 'manual';
      DateTime? dueAt;

      if (kind == 'fixed') {
        dueAt = _nextFixed(
          action['local_time'] as String?,
          action['timezone_name'] as String?,
          now,
          skipToday: doneToday,
        );
        if (dueAt == null) continue;
      } else if (kind == 'fajr' || kind == 'maghrib') {
        if (!settings.isComplete) continue;
        try {
          final offset = (action['prayer_offset_minutes'] as num?)?.toInt();
          if (offset != 5 && offset != 10) continue;
          final reminder = PrayerRelativeReminder(
            anchor: kind == 'fajr'
                ? PrayerReminderAnchor.fajr
                : PrayerReminderAnchor.maghrib,
            minutesAfter: offset!,
          );
          dueAt = reminder.nextOccurrence(
            calculator: calculator,
            settings: settings,
            after: doneToday
                ? now.add(const Duration(days: 1))
                : now,
          );
        } catch (_) {
          // Never guess prayer-relative timings without compatible preferences.
          continue;
        }
      } else if (kind != 'manual' || doneToday) {
        continue;
      }

      selected.add(
        HomeNextAction(
          id: id,
          title: title.trim(),
          origin: 'আমার তৈরি রুটিন',
          route: '/my-routines/action/${Uri.encodeComponent(id)}',
          dueAt: dueAt,
        ),
      );
    }

    selected.sort((a, b) {
      if (a.dueAt == null && b.dueAt == null) {
        return a.title.compareTo(b.title);
      }
      if (a.dueAt == null) return 1;
      if (b.dueAt == null) return -1;
      final byTime = a.dueAt!.compareTo(b.dueAt!);
      return byTime == 0 ? a.title.compareTo(b.title) : byTime;
    });
    return selected;
  }

  static DateTime? _nextFixed(
    String? time,
    String? timezoneName,
    DateTime now, {
    required bool skipToday,
  }) {
    if (time == null || timezoneName == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59 ||
        hour < 0 || minute < 0) return null;

    try {
      tz_data.initializeTimeZones();
      final location = tz.getLocation(timezoneName);
      final localNow = tz.TZDateTime.from(now, location);
      var candidate = tz.TZDateTime(
        location, localNow.year, localNow.month, localNow.day, hour, minute,
      );
      if (!candidate.isAfter(now) || skipToday) {
        candidate = tz.TZDateTime(
          location, localNow.year, localNow.month, localNow.day + 1,
          hour, minute,
        );
      }
      return candidate;
    } catch (_) {
      return null;
    }
  }

  static String dueLabel(HomeNextAction action) => action.dueAt == null
      ? 'সময় নির্ধারিত নয়'
      : DateFormat('EEE, d MMM · h:mm a', 'en').format(action.dueAt!.toLocal());
}
