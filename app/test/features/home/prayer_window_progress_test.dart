import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/home/presentation/unified_home_screen.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';

PrayerTimeEntry prayer(String id, DateTime time) =>
    PrayerTimeEntry(id: id, label: id, time: time);

void main() {
  test('prayer window progress tracks actual elapsed waqt', () {
    final current = prayer('dhuhr', DateTime(2026, 11, 1, 12));
    final next = prayer('asr', DateTime(2026, 11, 1, 16));
    expect(prayerWindowProgress(current, next, DateTime(2026, 11, 1, 12)), 0);
    expect(prayerWindowProgress(current, next, DateTime(2026, 11, 1, 14)), 0.5);
    expect(prayerWindowProgress(current, next, DateTime(2026, 11, 1, 17)), 1);
  });

  test('overnight Isha to next Fajr handles the date change', () {
    final current = prayer('isha', DateTime(2026, 11, 1, 20));
    final next = prayer('fajr', DateTime(2026, 11, 2, 4));
    expect(prayerWindowProgress(current, next, DateTime(2026, 11, 2)), 0.5);
    expect(prayerWindowProgress(current, next, DateTime(2026, 11, 1, 19)), 0);
  });

  test('invalid or equal prayer boundaries never yield NaN', () {
    final current = prayer('asr', DateTime(2026, 11, 1, 16));
    final same = prayer('maghrib', DateTime(2026, 11, 1, 16));
    final earlier = prayer('maghrib', DateTime(2026, 11, 1, 15));
    expect(prayerWindowProgress(current, same, current.time), 0);
    expect(prayerWindowProgress(current, earlier, current.time), 0);
  });

  test('existing countdown format remains stable', () {
    expect(
      formatPrayerCountdown(const Duration(hours: 2, minutes: 30)),
      '02:30:00',
    );
  });
}
