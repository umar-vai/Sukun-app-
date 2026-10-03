import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class LocalNotificationsGateway {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> isPermissionGranted();
  Future<bool> requestPreciseSchedulingPermission();
  Future<bool> canSchedulePrecisely();
  Future<String> configureTimezone();
  Future<void> schedule(ReminderSchedule reminder, {required bool precise});
  Future<void> cancel(int notificationId);
  Future<void> showRemote({required String title, required String body});
}

final class PluginLocalNotificationsGateway
    implements LocalNotificationsGateway {
  PluginLocalNotificationsGateway([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'care_reminders';
  static const _channelName = 'Care plan reminders';
  static const _updatesChannelId = 'care_updates';
  static const _updatesChannelName = 'Care plan updates';
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Approved Sukun Life care plan reminders',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _updatesChannelId,
        _updatesChannelName,
        description: 'Updates to an assigned Sukun Life care plan',
        importance: Importance.high,
      ),
    );
    await configureTimezone();
    _initialized = true;
  }

  @override
  Future<String> configureTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
      return timezone.identifier;
    } on Object {
      tz.setLocalLocation(tz.UTC);
      return 'UTC';
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return (await _plugin
                  .resolvePlatformSpecificImplementation<
                    IOSFlutterLocalNotificationsPlugin
                  >()
                  ?.checkPermissions())
              ?.isEnabled ??
          false;
    }
    return false;
  }

  @override
  Future<bool> requestPreciseSchedulingPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestExactAlarmsPermission() ??
        false;
  }

  @override
  Future<bool> canSchedulePrecisely() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  @override
  Future<void> schedule(
    ReminderSchedule reminder, {
    required bool precise,
  }) async {
    final local = reminder.scheduledAt.toLocal();
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      title: reminder.title,
      body: reminder.body,
      scheduledDate: tz.TZDateTime(
        tz.local,
        local.year,
        local.month,
        local.day,
        local.hour,
        local.minute,
      ),
      notificationDetails: _details,
      androidScheduleMode: precise
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);

  @override
  Future<void> showRemote({required String title, required String body}) =>
      _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
        title: title,
        body: body,
        notificationDetails: _details,
      );

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Approved Sukun Life care plan reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
