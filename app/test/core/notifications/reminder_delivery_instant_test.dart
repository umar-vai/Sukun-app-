import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/core/notifications/local_notifications_gateway.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  test('Bangladesh local reminder preserves the requested instant', () {
    final instant = DateTime.parse('2026-10-30T18:32:00Z');
    final dhaka = reminderDeliveryInstant(
      instant,
      timezone: tz.getLocation('Asia/Dhaka'),
    );
    expect(dhaka.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
    expect(dhaka.year, 2026);
    expect(dhaka.month, 10);
    expect(dhaka.day, 31);
    expect(dhaka.hour, 0);
    expect(dhaka.minute, 32);
  });

  test('unknown device timezone fallback to UTC cannot shift an alarm', () {
    final instant = DateTime.parse('2026-10-30T18:32:00Z');
    final fallback = reminderDeliveryInstant(instant, timezone: tz.UTC);
    expect(fallback.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
    expect(fallback.hour, 18);
    expect(fallback.minute, 32);
  });
}
