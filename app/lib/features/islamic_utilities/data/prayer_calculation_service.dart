import 'package:adhan_dart/adhan_dart.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract interface class PrayerCalculationService {
  PrayerDaySchedule calculate({
    required PrayerUtilitySettings settings,
    required DateTime now,
  });
}

final class AdhanPrayerCalculationService implements PrayerCalculationService {
  AdhanPrayerCalculationService() {
    tz_data.initializeTimeZones();
  }

  @override
  PrayerDaySchedule calculate({
    required PrayerUtilitySettings settings,
    required DateTime now,
  }) {
    if (!settings.isComplete) {
      throw ArgumentError('Prayer utility settings must be complete.');
    }
    final location = settings.location!;
    final timezone = tz.getLocation(location.timezone);
    final localNow = tz.TZDateTime.from(now, timezone);
    final coordinates = Coordinates(location.latitude, location.longitude);
    final parameters = _parameters(settings.calculationMethod!)
      ..madhab = settings.asrConvention == AsrConvention.hanafi
          ? Madhab.hanafi
          : Madhab.shafi;
    final times = PrayerTimes(
      coordinates: coordinates,
      date: localNow,
      calculationParameters: parameters,
    );
    final entries = _entries(times, timezone);
    final elapsedPrayers = entries
        .where((entry) => entry.isPrayer && !entry.time.isAfter(localNow))
        .toList();
    final current = elapsedPrayers.isNotEmpty
        ? elapsedPrayers.last
        : PrayerTimeEntry(
            id: 'isha',
            label: 'Isha',
            time: tz.TZDateTime.from(times.ishaBefore, timezone),
          );
    final next = entries
        .where((entry) => entry.isPrayer)
        .firstWhere(
          (entry) => entry.time.isAfter(localNow),
          orElse: () {
            final tomorrow = localNow.add(const Duration(days: 1));
            final nextTimes = PrayerTimes(
              coordinates: coordinates,
              date: tomorrow,
              calculationParameters: parameters,
            );
            return _entries(nextTimes, timezone).first;
          },
        );
    return PrayerDaySchedule(
      date: localNow,
      entries: entries,
      currentPrayer: current,
      nextPrayer: next,
      qiblaBearing: Qibla.qibla(coordinates),
    );
  }

  List<PrayerTimeEntry> _entries(PrayerTimes times, tz.Location timezone) => [
    PrayerTimeEntry(
      id: 'fajr',
      label: 'Fajr',
      time: tz.TZDateTime.from(times.fajr, timezone),
    ),
    PrayerTimeEntry(
      id: 'sunrise',
      label: 'Sunrise',
      time: tz.TZDateTime.from(times.sunrise, timezone),
      isPrayer: false,
    ),
    PrayerTimeEntry(
      id: 'dhuhr',
      label: 'Dhuhr',
      time: tz.TZDateTime.from(times.dhuhr, timezone),
    ),
    PrayerTimeEntry(
      id: 'asr',
      label: 'Asr',
      time: tz.TZDateTime.from(times.asr, timezone),
    ),
    PrayerTimeEntry(
      id: 'maghrib',
      label: 'Maghrib',
      time: tz.TZDateTime.from(times.maghrib, timezone),
    ),
    PrayerTimeEntry(
      id: 'isha',
      label: 'Isha',
      time: tz.TZDateTime.from(times.isha, timezone),
    ),
  ];

  CalculationParameters _parameters(PrayerCalculationMethodOption method) =>
      switch (method) {
        PrayerCalculationMethodOption.karachi =>
          CalculationMethodParameters.karachi(),
        PrayerCalculationMethodOption.muslimWorldLeague =>
          CalculationMethodParameters.muslimWorldLeague(),
        PrayerCalculationMethodOption.ummAlQura =>
          CalculationMethodParameters.ummAlQura(),
        PrayerCalculationMethodOption.egyptian =>
          CalculationMethodParameters.egyptian(),
        PrayerCalculationMethodOption.singapore =>
          CalculationMethodParameters.singapore(),
        PrayerCalculationMethodOption.northAmerica =>
          CalculationMethodParameters.northAmerica(),
      };
}
