import 'package:flutter_test/flutter_test.dart';
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

  test('calculates an ordered daily schedule and Qibla bearing', () {
    final schedule = AdhanPrayerCalculationService().calculate(
      settings: settings,
      now: DateTime.utc(2026, 10, 3, 10),
    );

    expect(schedule.entries.map((entry) => entry.id), [
      'fajr',
      'sunrise',
      'dhuhr',
      'asr',
      'maghrib',
      'isha',
    ]);
    for (var index = 1; index < schedule.entries.length; index++) {
      expect(
        schedule.entries[index].time.isAfter(schedule.entries[index - 1].time),
        isTrue,
      );
    }
    expect(schedule.qiblaBearing, inInclusiveRange(270, 290));
    expect(schedule.nextPrayer.isPrayer, isTrue);
  });

  test('requires explicit location, calculation method and Asr convention', () {
    final service = AdhanPrayerCalculationService();

    expect(
      () => service.calculate(
        settings: const PrayerUtilitySettings(),
        now: DateTime.utc(2026, 10, 3),
      ),
      throwsArgumentError,
    );
  });
}
