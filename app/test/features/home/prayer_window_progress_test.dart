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

  test('Fajr ends at sunrise; the gap until Dhuhr is not Fajr waqt', () {
    final fajr = prayer('fajr', DateTime(2026, 11, 1, 5));
    final sunrise = prayer('sunrise', DateTime(2026, 11, 1, 6, 15));
    final dhuhr = prayer('dhuhr', DateTime(2026, 11, 1, 12));
    final schedule = PrayerDaySchedule(
      date: DateTime(2026, 11, 1),
      entries: [fajr, sunrise, dhuhr],
      currentPrayer: fajr,
      nextPrayer: dhuhr,
      qiblaBearing: 0,
    );

    final beforeSunrise = DateTime(2026, 11, 1, 5, 30);
    final afterSunrise = DateTime(2026, 11, 1, 7);
    expect(prayerWindowEnd(schedule, beforeSunrise).id, 'sunrise');
    expect(isSunriseBreak(schedule, beforeSunrise), isFalse);
    expect(prayerWindowEnd(schedule, afterSunrise).id, 'dhuhr');
    expect(isSunriseBreak(schedule, afterSunrise), isTrue);
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
