import 'dart:async';

import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'browser_notification_bridge_stub.dart'
    if (dart.library.html) 'browser_notification_bridge_web.dart' as browser;

/// Browser-only active-tab fallback. It does NOT claim background or
/// closed-browser reminder delivery and does not request any patient data.
final class WebCareRemindersGateway implements LocalNotificationsGateway {
  WebCareRemindersGateway({required this.onNotificationOpened});

  final void Function(String?) onNotificationOpened;
  final Map<int, Timer> _scheduled = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() => browser.requestPermission();

  @override
  Future<bool> isPermissionGranted() async => browser.granted;

  @override
  Future<bool> requestPreciseSchedulingPermission() async => false;

  @override
  Future<bool> canSchedulePrecisely() async => false;

  @override
  Future<String> configureTimezone() async => DateTime.now().timeZoneName;

  @override
  Future<void> schedule(
    ReminderSchedule reminder, {
    required bool precise,
  }) async {
    await cancel(reminder.notificationId);
    if (!browser.granted || !browser.supported) return;
    _arm(reminder);
  }

  void _arm(ReminderSchedule reminder) {
    final remaining = reminder.scheduledAt.difference(DateTime.now());
    if (remaining <= Duration.zero) return;
    // Browser setTimeout may overflow at > 2^31 milliseconds. Recheck a
    // short horizon to tolerate tab throttling and keep scheduled times exact
    // *while the page remains running*, without claiming background support.
    const horizon = Duration(hours:6);
    final delay = remaining > horizon ? horizon : remaining;
    _scheduled[reminder.notificationId] = Timer(delay, () {
      _scheduled.remove(reminder.notificationId);
      final lateBy = DateTime.now().difference(reminder.scheduledAt);
      if (lateBy < Duration.zero) {
        _arm(reminder);
      } else if (lateBy <= const Duration(minutes: 10)) {
        browser.show(
          title: reminder.title,
          body: reminder.body,
          onClick: () => onNotificationOpened(reminder.payload),
        );
      }
    });
  }

  @override
  Future<void> cancel(int notificationId) async {
    _scheduled.remove(notificationId)?.cancel();
  }

  @override
  Future<void> showRemote({
    required String title,
    required String body,
  }) async {
    browser.show(title: title, body: body, onClick: () {});
  }

  void dispose() {
    for (final timer in _scheduled.values) {
      timer.cancel();
    }
    _scheduled.clear();
  }
}
