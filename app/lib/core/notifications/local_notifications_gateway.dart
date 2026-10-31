import 'package:flutter/foundation.dart';
import 'package:sukun_life/core/config/app_environment.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Convert a scheduled instant to the timezone used by the notification
/// plugin. Rebuilding a wall clock in a fallback UTC timezone can shift a
/// reminder by hours (e.g. Asia/Dhaka +06), so preserve the original instant.
tz.TZDateTime reminderDeliveryInstant(
  DateTime scheduledAt, {
  required tz.Location timezone,
}) => tz.TZDateTime.from(scheduledAt, timezone);

/// Accept only public notice artwork on our configured production or staging
/// Supabase project. This must never fetch a patient asset or an arbitrary FCM
/// supplied URL (including redirect-like query strings or host lookalikes).
bool isApprovedUniversalNoticeImageUrl(
  String? rawUrl, {
  String backendUrl = AppEnvironment.supabaseUrl,
}) {
  if (backendUrl != AppEnvironment.productionSupabaseUrl &&
      backendUrl != AppEnvironment.stagingSupabaseUrl) {
    return false;
  }
  final url = Uri.tryParse(rawUrl ?? '');
  final backend = Uri.tryParse(backendUrl);
  if (url == null ||
      backend == null ||
      url.scheme != 'https' ||
      url.host != backend.host ||
      url.userInfo.isNotEmpty ||
      url.hasPort ||
      url.hasQuery ||
      url.hasFragment) {
    return false;
  }
  const expected = [
    'storage',
    'v1',
    'object',
    'public',
    'sukun-announcement-images',
    'notices',
  ];
  final parts = url.pathSegments;
  if (parts.length != expected.length + 1) return false;
  for (var i = 0; i < expected.length; i++) {
    if (parts[i] != expected[i]) return false;
  }
  return RegExp(
    r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,149}\.(png|jpg|jpeg|webp)$',
    caseSensitive: false,
  ).hasMatch(parts.last);
}

abstract interface class LocalNotificationsGateway {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> isPermissionGranted();
  Future<bool> requestPreciseSchedulingPermission();
  Future<bool> canSchedulePrecisely();
  Future<String> configureTimezone();
  Future<void> schedule(ReminderSchedule reminder, {required bool precise});
  Future<void> cancel(int notificationId);
  Future<void> showRemote({
    required String title,
    required String body,
    String? payload,
  });
}

final class PluginLocalNotificationsGateway
    implements LocalNotificationsGateway {
  PluginLocalNotificationsGateway([
    FlutterLocalNotificationsPlugin? plugin,
    this.onNotificationOpened,
  ]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final void Function(String?)? onNotificationOpened;

  static const _channelId = 'care_reminders';
  static const _channelName = 'Care plan reminders';
  static const _prayerChannelId = 'prayer_waqt';
  static const _prayerChannelName = 'Prayer time alerts';
  static const _updatesChannelId = 'care_updates';
  static const _updatesChannelName = 'Care plan updates';
  static const publicNoticeChannelId = 'sukun_public_notices';
  static const _publicNoticeChannelName = 'Sukun Life notices';
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
      onDidReceiveNotificationResponse: (response) {
        onNotificationOpened?.call(response.payload);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      onNotificationOpened?.call(launch?.notificationResponse?.payload);
    }
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
        _prayerChannelId,
        _prayerChannelName,
        description: 'Optional start-of-waqt prayer reminders',
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
    // FCM requires the channel to exist *before* a background public notice.
    // Guests can opt in without signing into patient care.
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        publicNoticeChannelId,
        _publicNoticeChannelName,
        description: 'Optional public Sukun Life announcements',
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
    await _plugin.zonedSchedule(
      id: reminder.notificationId,
      title: reminder.title,
      body: reminder.body,
      // Preserve the requested instant even if Android returns an unknown
      // timezone identifier and configureTimezone falls back to UTC.
      scheduledDate: reminderDeliveryInstant(
        reminder.scheduledAt,
        timezone: tz.local,
      ),
      notificationDetails: reminder.payload.startsWith('prayer_time:')
          ? _prayerDetails
          : _details,
      androidScheduleMode: precise
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.payload,
    );
  }

  @override
  Future<void> cancel(int notificationId) => _plugin.cancel(id: notificationId);

  @override
  Future<void> showRemote({
    required String title,
    required String body,
    String? payload,
  }) => _plugin.show(
    id: DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
    title: title,
    body: body,
    notificationDetails: _details,
    payload: payload,
  );

  /// Foreground Android receives a single public-only FCM notice and
  /// renders a BigPicture with the system's countdown chronometer (API 24+).
  /// Background OS-delivered FCM still uses its own standard image rendering.
  Future<void> showUniversal({
    required String noticeId,
    required String title,
    String? imageUrl,
    DateTime? countdownEndsAt,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return;
    await initialize();
    Uint8List? picture;
    final uri = Uri.tryParse(imageUrl ?? '');
    if (uri != null && isApprovedUniversalNoticeImageUrl(imageUrl)) {
      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 6));
        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            response.bodyBytes.length <= 1024 * 1024) {
          picture = response.bodyBytes;
        }
      } on Object {
        // Missing artwork must not suppress an otherwise valid public notice.
      }
    }
    final validDeadline =
        countdownEndsAt != null &&
        countdownEndsAt.isAfter(DateTime.now()) &&
        countdownEndsAt.isBefore(DateTime.now().add(const Duration(days: 30)));
    final android = AndroidNotificationDetails(
      publicNoticeChannelId,
      _publicNoticeChannelName,
      channelDescription: 'Optional public notices from Sukun Life',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      styleInformation: picture == null
          ? const BigTextStyleInformation('')
          : BigPictureStyleInformation(ByteArrayAndroidBitmap(picture)),
      when: validDeadline ? countdownEndsAt.millisecondsSinceEpoch : null,
      usesChronometer: validDeadline,
      chronometerCountDown: validDeadline,
      showWhen: validDeadline,
    );
    await _plugin.show(
      id: noticeId.hashCode & 0x7fffffff,
      title: 'সুকুন লাইফ • গুরুত্বপূর্ণ নোটিশ',
      body: title,
      notificationDetails: NotificationDetails(android: android),
      payload: 'universal_notice:$noticeId',
    );
  }

  static const _prayerDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _prayerChannelId,
      _prayerChannelName,
      channelDescription: 'Optional prayer waqt reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
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
