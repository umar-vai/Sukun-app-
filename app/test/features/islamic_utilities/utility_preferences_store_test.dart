import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'starts incomplete instead of inventing a religious preference',
    () async {
      SharedPreferences.setMockInitialValues({});
      const store = SharedPreferencesUtilityPreferencesStore();

      final settings = await store.load();

      expect(settings.isComplete, isFalse);
      expect(settings.location, isNull);
      expect(settings.calculationMethod, isNull);
      expect(settings.asrConvention, isNull);
    },
  );

  test('round-trips an explicitly selected manual city and method', () async {
    SharedPreferences.setMockInitialValues({});
    const store = SharedPreferencesUtilityPreferencesStore();
    final selected = PrayerUtilitySettings(
      location: manualBangladeshCities.first,
      calculationMethod: PrayerCalculationMethodOption.karachi,
      asrConvention: AsrConvention.hanafi,
    );

    await store.save(selected);
    final restored = await store.load();

    expect(restored.isComplete, isTrue);
    expect(restored.location?.id, 'dhaka');
    expect(restored.calculationMethod, PrayerCalculationMethodOption.karachi);
    expect(restored.asrConvention, AsrConvention.hanafi);
  });
}
