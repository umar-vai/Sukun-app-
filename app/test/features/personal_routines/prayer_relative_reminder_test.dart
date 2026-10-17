import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';
import 'package:sukun_life/features/personal_routines/domain/prayer_relative_reminder.dart';

void main() {
  const settings = PrayerUtilitySettings(
    location: UtilityLocation(
      id: 'dhaka',
      name: 'Dhaka',
      latitude: 23.8103,
      longitude: 90.4125,
      timezone: 'Asia/Dhaka',
      source: UtilityLocationSource.manual,
    ),
    calculationMethod: PrayerCalculationMethodOption.karachi,
    asrConvention: AsrConvention.hanafi,
  );
  final calculator = AdhanPrayerCalculationService();

  test("Fajr +10 is calculated for tomorrow if today\'s prayer has passed", () {
    final after = DateTime.utc(2026, 10, 3, 2);
    const rule = PrayerRelativeReminder(
      anchor: PrayerReminderAnchor.fajr,
      minutesAfter: 10,
    );
    final next = rule.nextOccurrence(
      calculator: calculator,
      settings: settings,
      after: after,
    );
    final nextFajr = calculator
        .calculate(settings: settings, now: after.add(const Duration(days: 1)))
        .entries
        .firstWhere((entry) => entry.id == 'fajr')
        .time;
    expect(next, nextFajr.add(const Duration(minutes: 10)));
    expect(next.isAfter(after), isTrue);
  });

  test("Maghrib +5 uses today\'s calculated Maghrib, not a fixed clock", () {
    final after = DateTime.utc(2026, 10, 3, 4);
    const rule = PrayerRelativeReminder(
      anchor: PrayerReminderAnchor.maghrib,
      minutesAfter: 5,
    );
    final next = rule.nextOccurrence(
      calculator: calculator,
      settings: settings,
      after: after,
    );
    final today = calculator
        .calculate(settings: settings, now: after)
        .entries
        .firstWhere((entry) => entry.id == 'maghrib')
        .time;
    expect(next, today.add(const Duration(minutes: 5)));
  });

  test('missing prayer preferences never silently default to Dhaka', () {
    const rule = PrayerRelativeReminder(
      anchor: PrayerReminderAnchor.fajr,
      minutesAfter: 10,
    );
    expect(
      () => rule.nextOccurrence(
        calculator: calculator,
        settings: const PrayerUtilitySettings(),
        after: DateTime.utc(2026, 10, 3),
      ),
      throwsStateError,
    );
  });
}
