import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

enum PrayerCalculationMethodOption {
  karachi(
    'karachi',
    'ইউনিভার্সিটি অব ইসলামিক সায়েন্সেস, করাচি',
    'ফজর 18° · ইশা 18°',
  ),
  muslimWorldLeague(
    'muslim_world_league',
    'মুসলিম ওয়ার্ল্ড লীগ',
    'ফজর 18° · ইশা 17°',
  ),
  ummAlQura(
    'umm_al_qura',
    'উম্মুল কুরা বিশ্ববিদ্যালয়, মক্কা',
    'ফজর ১৮.৫° · ইশা নির্দিষ্ট বিরতিতে',
  ),
  egyptian('egyptian', 'মিশরীয় জরিপ কর্তৃপক্ষ', 'ফজর 19.5° · ইশা 17.5°'),
  singapore('singapore', 'সিঙ্গাপুর', 'ফজর 20° · ইশা 18°'),
  northAmerica('north_america', 'উত্তর আমেরিকা (ISNA)', 'ফজর 15° · ইশা 15°');

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
  hanafi('hanafi', 'হানাফি', 'আসরের সময় একটু পরে'),
  standard('standard', 'শাফেয়ি, মালিকি, হাম্বলি', 'আসরের সময় একটু আগে');

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
