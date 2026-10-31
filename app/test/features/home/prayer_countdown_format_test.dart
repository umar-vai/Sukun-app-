import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/home/presentation/unified_home_screen.dart';

void main() {
  test('countdown shows 50 minutes and decrements every second', () {
    expect(formatPrayerCountdown(const Duration(minutes: 50)), '00:50:00');
    expect(
      formatPrayerCountdown(const Duration(minutes: 49, seconds: 59)),
      '00:49:59',
    );
    expect(formatPrayerCountdown(Duration.zero), '00:00:00');
    expect(formatPrayerCountdown(const Duration(seconds: -2)), '00:00:00');
    expect(
      formatPrayerCountdown(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '02:03:04',
    );
  });
}
