import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';

enum PrayerReminderAnchor { fajr, maghrib }

/// Computes each occurrence from the user's selected location/timezone and
/// prayer convention. Never freezes Fajr/Maghrib at yesterday's clock time.
/// This is schedule computation, not browser-closed push delivery.
class PrayerRelativeReminder {
  const PrayerRelativeReminder({
    required this.anchor,
    required this.minutesAfter,
  }) : assert(minutesAfter >= 0 && minutesAfter <= 120);

  final PrayerReminderAnchor anchor;
  final int minutesAfter;

  DateTime nextOccurrence({
    required PrayerCalculationService calculator,
    required PrayerUtilitySettings settings,
    required DateTime after,
  }) {
    if (!settings.isComplete) {
      throw StateError(
        'Choose a city, prayer calculation method and Asr convention.',
      );
    }
    // Search today and subsequent dates; DST-safe dates/clock values are
    // returned by the shared Adhan + timezone utility, not by a fixed clock.
    for (var day = 0; day < 4; day += 1) {
      final schedule = calculator.calculate(
        settings: settings,
        now: after.add(Duration(days: day)),
      );
      final entry = schedule.entries.firstWhere(
        (prayer) => prayer.id == anchor.name,
      );
      final reminderAt = entry.time.add(Duration(minutes: minutesAfter));
      if (reminderAt.isAfter(after)) return reminderAt;
    }
    throw StateError('Could not calculate the next prayer reminder.');
  }
}
