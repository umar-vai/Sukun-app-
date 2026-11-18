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

final prayerNotificationServiceProvider = Provider<PrayerNotificationService>(
  (ref) => PrayerNotificationService(
    local: ref.watch(localNotificationsGatewayProvider),
    calculator: ref.watch(prayerCalculationServiceProvider),
    settingsStore: ref.watch(utilityPreferencesStoreProvider),
  ),
);

/// Personal, device-only, opt-in alerts. Does not read patient data or
/// silently register a push token. On Web delivery requires an active tab.
class PrayerNotificationService {
  PrayerNotificationService({
    required this.local,
    required this.calculator,
    required this.settingsStore,
  });

  final LocalNotificationsGateway local;
  final PrayerCalculationService calculator;
  final UtilityPreferencesStore settingsStore;

  // App startup and resume can request a refresh concurrently. Never let
  // one pass cancel another pass's pending OS alarms.
  Future<int>? _activeRefresh;

  static const _enabledKey = 'prayer_waqt_notifications_enabled_v1';
  static const _idsKey = 'prayer_waqt_notification_ids_v1';
  static const _lastRefreshKey = 'prayer_waqt_last_refresh_ms_v1';
  static const _lastFailureKey = 'prayer_waqt_last_refresh_failed_v1';
  static const _lastEndKey = 'prayer_waqt_last_scheduled_end_ms_v1';

  /// Android keeps alarms across reboots, so a month of waqt (150 alarms) is
  /// scheduled. A user who rarely opens the app still hears every prayer.
  static const androidHorizonDays = 30;
  static const androidMaximumPending = 5 * androidHorizonDays;

  /// A reminder to open the app is scheduled this long before the last waqt
  /// alarm, so the schedule is renewed before it runs out.
  static const renewalLead = Duration(days: 3);

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  /// What the device was last told, for the notification health screen.
  Future<PrayerNotificationDiagnostics> diagnostics() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshed = prefs.getInt(_lastRefreshKey);
    final end = prefs.getInt(_lastEndKey);
    final ids = prefs.getStringList(_idsKey) ?? const <String>[];
    return PrayerNotificationDiagnostics(
      enabled: prefs.getBool(_enabledKey) ?? false,
      scheduledCount: ids.length,
      lastRefresh: refreshed == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(refreshed),
      lastRefreshFailed: prefs.getBool(_lastFailureKey) ?? false,
      scheduledUntil: end == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(end),
    );
  }

  Future<bool> enable() async {
    final settings = await settingsStore.load();
    if (!settings.isComplete) {
      throw StateError('Prayer location and method must be configured first');
    }
    await local.initialize();
    if (!await local.requestPermission()) return false;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
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
    // A refresh already in progress must finish before the opt-out removes
    // its alarms; otherwise late scheduling could revive disabled alerts.
    final active = _activeRefresh;
    if (active != null) {
      try {
        await active;
      } on Object {
        // Opt-out must proceed even after a failed refresh.
      }
    }
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

  Future<int> refresh() {
    final active = _activeRefresh;
    if (active != null) return active;
    final pending = _refreshOnce();
    _activeRefresh = pending;
    return pending.whenComplete(() {
      if (identical(_activeRefresh, pending)) _activeRefresh = null;
    });
  }

  Future<int> _refreshOnce() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final count = await _scheduleAll();
      await prefs.setInt(
        _lastRefreshKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      await prefs.setBool(_lastFailureKey, false);
      return count;
    } on Object {
      await prefs.setBool(_lastFailureKey, true);
      rethrow;
    }
  }

  Future<int> _scheduleAll() async {
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
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final reminders = planPrayerWaqtReminders(
      calculator: calculator,
      settings: settings,
      now: DateTime.now(),
      // iOS retains at most 64 pending notifications across every feature.
      // Reserve room for patient-care and personal-routine reminders.
      horizonDays: ios || kIsWeb ? 3 : androidHorizonDays,
      maximumPending: ios ? 12 : androidMaximumPending,
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
      final prefs = await SharedPreferences.getInstance();
      final renewal = planPrayerRenewalReminder(
        reminders: reminders,
        now: DateTime.now(),
        lead: renewalLead,
      );
      if (renewal != null && !ios && !kIsWeb) {
        await local.schedule(renewal, precise: precise);
        ids.add(renewal.notificationId);
      }
      if (reminders.isEmpty) {
        await prefs.remove(_lastEndKey);
      } else {
        await prefs.setInt(
          _lastEndKey,
          reminders.last.scheduledAt.millisecondsSinceEpoch,
        );
      }
      await prefs.setStringList(_idsKey, ids.map((id) => '$id').toList());
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

class PrayerNotificationDiagnostics {
  const PrayerNotificationDiagnostics({
    required this.enabled,
    required this.scheduledCount,
    required this.lastRefresh,
    required this.lastRefreshFailed,
    required this.scheduledUntil,
  });

  final bool enabled;
  final int scheduledCount;
  final DateTime? lastRefresh;
  final bool lastRefreshFailed;

  /// The last prayer alarm currently on the device.
  final DateTime? scheduledUntil;
}

/// One quiet "open the app to renew your prayer alerts" notice placed before
/// the schedule ends. Null when the schedule is empty or already near its end.
ReminderSchedule? planPrayerRenewalReminder({
  required List<ReminderSchedule> reminders,
  required DateTime now,
  required Duration lead,
}) {
  if (reminders.isEmpty) return null;
  final at = reminders.last.scheduledAt.subtract(lead);
  if (!at.isAfter(now)) return null;
  return ReminderSchedule(
    notificationId: stableNotificationId('prayer:renew'),
    taskId: 'prayer:renew',
    actionId: 'renew',
    title: 'নামাজের নোটিফিকেশন চালু রাখুন',
    body: 'ওয়াক্তের নোটিফিকেশন শীঘ্রই শেষ হবে। অ্যাপটি একবার খুলুন।',
    scheduledAt: at,
    payload: 'prayer_time:renew',
  );
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
  int maximumPending = 70,
}) {
  if (!settings.isComplete || horizonDays < 1 || maximumPending < 1) {
    return const [];
  }
  tz_data.initializeTimeZones();
  final zone = tz.getLocation(settings.location!.timezone);
  final today = tz.TZDateTime.from(now, zone);
  final reminders = <ReminderSchedule>[];
  for (var day = 0; day < horizonDays; day++) {
    final noon = tz.TZDateTime(
      zone,
      today.year,
      today.month,
      today.day + day,
      12,
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
  return List.unmodifiable(reminders.take(maximumPending));
}
