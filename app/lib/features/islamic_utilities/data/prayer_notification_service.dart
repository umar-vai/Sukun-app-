import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/notification_providers.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

final prayerNotificationServiceProvider = Provider<PrayerNotificationService>((
  ref,
) => PrayerNotificationService(
  local: ref.watch(localNotificationsGatewayProvider),
  calculator: ref.watch(prayerCalculationServiceProvider),
  settingsStore: ref.watch(utilityPreferencesStoreProvider),
));

/// Personal, device-only, opt-in alerts. Does not read patient data or
/// silently register a push token. On Web delivery requires an active tab.
class PrayerNotificationService {
  const PrayerNotificationService({
    required this.local,
    required this.calculator,
    required this.settingsStore,
  });

  final LocalNotificationsGateway local;
  final PrayerCalculationService calculator;
  final UtilityPreferencesStore settingsStore;

  static const _enabledKey = 'prayer_waqt_notifications_enabled_v1';
  static const _idsKey = 'prayer_waqt_notification_ids_v1';

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<bool> enable() async {
    final settings = await settingsStore.load();
    if (!settings.isComplete) {
      throw StateError('Prayer location and method must be configured first');
    }
    await local.initialize();
    if (!await local.requestPermission()) return false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android &&
        !await local.canSchedulePrecisely()) {
      await local.requestPreciseSchedulingPermission();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    try {
      await refresh();
      return true;
    } on Object {
      await prefs.setBool(_enabledKey, false);
      await _cancelExisting();
      rethrow;
    }
  }

  Future<void> disable() async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
    await _cancelExisting();
  }

  Future<void> _cancelExisting() async {
    await local.initialize();
    final prefs = await SharedPreferences.getInstance();
    for (final rawId in prefs.getStringList(_idsKey) ?? const <String>[]) {
      final id = int.tryParse(rawId);
      if (id != null) await local.cancel(id);
    }
    await prefs.remove(_idsKey);
  }

  Future<int> refresh() async {
    if (!await isEnabled()) return 0;
    await local.initialize();
    if (!await local.isPermissionGranted()) {
      await _cancelExisting();
      return 0;
    }
    final settings = await settingsStore.load();
    if (!settings.isComplete) {
      await _cancelExisting();
      return 0;
    }
    final reminders = planPrayerWaqtReminders(
      calculator: calculator,
      settings: settings,
      now: DateTime.now(),
    );
    await local.configureTimezone();
    await _cancelExisting();
    final precise = await local.canSchedulePrecisely();
    final ids = <int>[];
    try {
      for (final reminder in reminders) {
        await local.schedule(reminder, precise: precise);
        ids.add(reminder.notificationId);
      }
      await (await SharedPreferences.getInstance()).setStringList(
        _idsKey,
        ids.map((id) => '$id').toList(),
      );
      return ids.length;
    } on Object {
      for (final id in ids) {
        try {
          await local.cancel(id);
        } on Object {
          // Preserve original scheduling failure.
        }
      }
      rethrow;
    }
  }
}

const prayerNamesBn = <String, String>{
  'fajr': 'ফজর',
  'dhuhr': 'যোহর',
  'asr': 'আসর',
  'maghrib': 'মাগরিব',
  'isha': 'ইশা',
};

/// Calculates each day's five start times in the location's own timezone.
/// Namespaced stable IDs keep care/personal reminders untouched.
List<ReminderSchedule> planPrayerWaqtReminders({
  required PrayerCalculationService calculator,
  required PrayerUtilitySettings settings,
  required DateTime now,
  int horizonDays = 14,
}) {
  if (!settings.isComplete || horizonDays < 1) return const [];
  tz_data.initializeTimeZones();
  final zone = tz.getLocation(settings.location!.timezone);
  final today = tz.TZDateTime.from(now, zone);
  final reminders = <ReminderSchedule>[];
  for (var day = 0; day < horizonDays; day++) {
    final noon = tz.TZDateTime(
      zone, today.year, today.month, today.day + day, 12,
    );
    final schedule = calculator.calculate(settings: settings, now: noon);
    for (final entry in schedule.entries.where((e) => e.isPrayer)) {
      if (!entry.time.isAfter(now)) continue;
      final label = prayerNamesBn[entry.id] ?? entry.label;
      final localDate = tz.TZDateTime.from(entry.time, zone);
      final dateKey = '${localDate.year}-${localDate.month}-${localDate.day}';
      reminders.add(
        ReminderSchedule(
          notificationId: stableNotificationId('prayer:$dateKey:${entry.id}'),
          taskId: 'prayer:$dateKey:${entry.id}',
          actionId: entry.id,
          title: '$label নামাজের ওয়াক্ত',
          body: '$label নামাজের ওয়াক্ত শুরু হয়েছে।',
          scheduledAt: entry.time,
          payload: 'prayer_time:${entry.id}',
        ),
      );
    }
  }
  reminders.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return List.unmodifiable(reminders.take(70));
}
