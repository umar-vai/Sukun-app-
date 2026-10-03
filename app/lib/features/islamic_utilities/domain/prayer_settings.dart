import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

enum PrayerCalculationMethodOption {
  karachi(
    'karachi',
    'University of Islamic Sciences, Karachi',
    'Fajr 18° · Isha 18°',
  ),
  muslimWorldLeague(
    'muslim_world_league',
    'Muslim World League',
    'Fajr 18° · Isha 17°',
  ),
  ummAlQura(
    'umm_al_qura',
    'Umm al-Qura University, Makkah',
    'Fajr 18.5° · fixed Isha interval',
  ),
  egyptian(
    'egyptian',
    'Egyptian General Authority of Survey',
    'Fajr 19.5° · Isha 17.5°',
  ),
  singapore('singapore', 'Singapore', 'Fajr 20° · Isha 18°'),
  northAmerica('north_america', 'North America (ISNA)', 'Fajr 15° · Isha 15°');

  const PrayerCalculationMethodOption(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static PrayerCalculationMethodOption? fromId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

enum AsrConvention {
  hanafi('hanafi', 'Hanafi', 'Later Asr time'),
  standard('standard', 'Standard (Shafi, Maliki, Hanbali)', 'Earlier Asr time');

  const AsrConvention(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static AsrConvention? fromId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

class PrayerUtilitySettings {
  const PrayerUtilitySettings({
    this.location,
    this.calculationMethod,
    this.asrConvention,
  });

  final UtilityLocation? location;
  final PrayerCalculationMethodOption? calculationMethod;
  final AsrConvention? asrConvention;

  bool get isComplete =>
      location != null && calculationMethod != null && asrConvention != null;

  PrayerUtilitySettings copyWith({
    UtilityLocation? location,
    PrayerCalculationMethodOption? calculationMethod,
    AsrConvention? asrConvention,
  }) {
    return PrayerUtilitySettings(
      location: location ?? this.location,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrConvention: asrConvention ?? this.asrConvention,
    );
  }
}
