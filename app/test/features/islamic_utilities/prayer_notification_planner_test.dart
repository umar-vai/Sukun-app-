import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_notification_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

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

  test('five daily waqt notifications use unique, future, bounded IDs', () {
    final now = DateTime.utc(2026, 11, 1, 0);
    final planned = planPrayerWaqtReminders(
      calculator: AdhanPrayerCalculationService(),
      settings: settings,
      now: now,
      horizonDays: 3,
    );
    expect(planned.length, inInclusiveRange(10, 15));
    expect(
      planned.map((reminder) => reminder.notificationId).toSet().length,
      planned.length,
    );
    expect(planned.every((r) => r.scheduledAt.isAfter(now)), isTrue);
    expect(planned.every((r) => r.payload.startsWith('prayer_time:')), isTrue);
    expect(planned.every((r) => r.title.contains('ওয়াক্ত')), isTrue);
  });

  test('incomplete settings never create notifications', () {
    expect(
      planPrayerWaqtReminders(
        calculator: AdhanPrayerCalculationService(),
        settings: const PrayerUtilitySettings(),
        now: DateTime.utc(2026, 11, 1),
      ),
      isEmpty,
    );
  });
}
