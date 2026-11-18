import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/power_settings_gateway.dart';
import 'package:sukun_life/core/notifications/reminder_schedule.dart';
import 'package:sukun_life/features/account/presentation/notification_health_settings_screen.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_notification_service.dart';

ReminderSchedule _at(DateTime when) => ReminderSchedule(
  notificationId: 1,
  taskId: 't',
  actionId: 'fajr',
  title: 't',
  body: 'b',
  scheduledAt: when,
  payload: 'prayer_time:fajr',
);

void main() {
  final now = DateTime(2026, 11, 1, 9);

  group('prayer renewal nudge', () {
    test('is placed lead-time before the last scheduled waqt', () {
      final nudge = planPrayerRenewalReminder(
        reminders: [
          _at(DateTime(2026, 11, 2, 5)),
          _at(DateTime(2026, 12, 1, 18)),
        ],
        now: now,
        lead: const Duration(days: 3),
      );
      expect(nudge, isNotNull);
      expect(nudge!.scheduledAt, DateTime(2026, 11, 28, 18));
      expect(nudge.payload, 'prayer_time:renew');
    });

    test('is skipped when empty or already inside the lead window', () {
      expect(
        planPrayerRenewalReminder(
          reminders: const [],
          now: now,
          lead: const Duration(days: 3),
        ),
        isNull,
      );
      expect(
        planPrayerRenewalReminder(
          reminders: [_at(DateTime(2026, 11, 2, 5))],
          now: now,
          lead: const Duration(days: 3),
        ),
        isNull,
      );
    });
  });

  test('Android horizon covers a month of five daily waqt alarms', () {
    expect(PrayerNotificationService.androidHorizonDays, 30);
    expect(PrayerNotificationService.androidMaximumPending, 150);
  });

  group('prayer diagnostics summary', () {
    test('reports failure, empty and healthy states', () {
      expect(
        prayerDiagnosticsSummary(
          const PrayerNotificationDiagnostics(
            enabled: true,
            scheduledCount: 0,
            lastRefresh: null,
            lastRefreshFailed: true,
            scheduledUntil: null,
          ),
        ),
        contains('বসানো যায়নি'),
      );
      expect(
        prayerDiagnosticsSummary(
          const PrayerNotificationDiagnostics(
            enabled: true,
            scheduledCount: 0,
            lastRefresh: null,
            lastRefreshFailed: false,
            scheduledUntil: null,
          ),
        ),
        contains('শিডিউল করা নেই'),
      );
      expect(
        prayerDiagnosticsSummary(
          PrayerNotificationDiagnostics(
            enabled: true,
            scheduledCount: 150,
            lastRefresh: now,
            lastRefreshFailed: false,
            scheduledUntil: DateTime(2026, 12, 1),
          ),
        ),
        allOf(contains('150'), contains('1/12/2026')),
      );
    });
  });

  test('vendor autostart step applies to aggressive power managers', () {
    expect(needsVendorAutostartStep('honor'), isTrue);
    expect(needsVendorAutostartStep('Huawei'), isTrue);
    expect(needsVendorAutostartStep('xiaomi'), isTrue);
    expect(needsVendorAutostartStep('google'), isFalse);
    expect(needsVendorAutostartStep(''), isFalse);
  });
}
