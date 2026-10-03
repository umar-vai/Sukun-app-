import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

abstract interface class UtilityPreferencesStore {
  Future<PrayerUtilitySettings> load();
  Future<void> save(PrayerUtilitySettings settings);
}

final class SharedPreferencesUtilityPreferencesStore
    implements UtilityPreferencesStore {
  const SharedPreferencesUtilityPreferencesStore();

  static const _locationKey = 'islamic_utilities.location.v1';
  static const _methodKey = 'islamic_utilities.calculation_method.v1';
  static const _asrKey = 'islamic_utilities.asr_convention.v1';

  @override
  Future<PrayerUtilitySettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    UtilityLocation? location;
    final encodedLocation = preferences.getString(_locationKey);
    if (encodedLocation != null) {
      try {
        location = UtilityLocation.fromJson(
          (jsonDecode(encodedLocation) as Map).cast<String, Object?>(),
        );
      } on Object {
        location = null;
      }
    }
    return PrayerUtilitySettings(
      location: location,
      calculationMethod: PrayerCalculationMethodOption.fromId(
        preferences.getString(_methodKey),
      ),
      asrConvention: AsrConvention.fromId(preferences.getString(_asrKey)),
    );
  }

  @override
  Future<void> save(PrayerUtilitySettings settings) async {
    if (!settings.isComplete) {
      throw ArgumentError('Prayer utility settings must be complete.');
    }
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(
        _locationKey,
        jsonEncode(settings.location!.toJson()),
      ),
      preferences.setString(_methodKey, settings.calculationMethod!.id),
      preferences.setString(_asrKey, settings.asrConvention!.id),
    ]);
  }
}
