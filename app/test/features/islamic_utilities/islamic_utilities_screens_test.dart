import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/islamic_utilities/data/compass_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_location_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/islamic_utilities/domain/compass_reading.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/prayer_settings_screen.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/prayer_times_screen.dart';
import 'package:sukun_life/features/islamic_utilities/presentation/qibla_screen.dart';

void main() {
  testWidgets('prayer times requires explicit setup', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const PrayerTimesScreen(),
        settings: const PrayerUtilitySettings(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set up prayer times'), findsOneWidget);
    expect(find.text('Choose settings'), findsOneWidget);
    expect(find.text('Fajr'), findsNothing);
  });

  testWidgets('configured prayer screen shows next and daily times', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const PrayerTimesScreen(), settings: _configuredSettings),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEXT PRAYER'), findsOneWidget);
    expect(find.text("Today's times"), findsOneWidget);
    expect(find.text('Fajr'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Dhaka'), 300);
    expect(find.text('Dhaka'), findsOneWidget);
  });

  testWidgets('manual city fallback remains available after denial', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const PrayerSettingsScreen(),
        settings: const PrayerUtilitySettings(),
        locationGateway: const _DeniedLocationGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use current location'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Location permission was not granted. You can select a city manually.',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Or select a Bangladesh city'),
      250,
    );
    expect(find.text('Or select a Bangladesh city'), findsOneWidget);
  });

  testWidgets('Qibla keeps a bearing fallback without a compass sensor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const QiblaScreen(),
        settings: _configuredSettings,
        compassGateway: const _UnavailableCompassGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Compass sensor unavailable'),
      250,
    );
    expect(find.text('Compass sensor unavailable'), findsOneWidget);
    expect(find.textContaining('from North'), findsOneWidget);
    expect(find.textContaining('another trusted compass'), findsOneWidget);
  });

  testWidgets('Qibla explains how to calibrate an unreliable compass', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const QiblaScreen(),
        settings: _configuredSettings,
        compassGateway: const _CalibrationCompassGateway(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Calibrate the compass'), 250);
    expect(find.text('Calibrate the compass'), findsOneWidget);
    expect(find.textContaining('figure-eight pattern'), findsOneWidget);
    expect(find.textContaining('from North'), findsOneWidget);
  });
}

const _configuredSettings = PrayerUtilitySettings(
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

Widget _testApp(
  Widget home, {
  required PrayerUtilitySettings settings,
  UtilityLocationGateway locationGateway = const _DeniedLocationGateway(),
  CompassGateway compassGateway = const _UnavailableCompassGateway(),
}) {
  return ProviderScope(
    overrides: [
      utilityPreferencesStoreProvider.overrideWithValue(
        _MemorySettingsStore(settings),
      ),
      utilityLocationGatewayProvider.overrideWithValue(locationGateway),
      compassGatewayProvider.overrideWithValue(compassGateway),
      prayerCalculationServiceProvider.overrideWithValue(
        AdhanPrayerCalculationService(),
      ),
    ],
    child: MaterialApp(home: home),
  );
}

final class _MemorySettingsStore implements UtilityPreferencesStore {
  _MemorySettingsStore(this.settings);

  PrayerUtilitySettings settings;

  @override
  Future<PrayerUtilitySettings> load() async => settings;

  @override
  Future<void> save(PrayerUtilitySettings settings) async {
    this.settings = settings;
  }
}

final class _DeniedLocationGateway implements UtilityLocationGateway {
  const _DeniedLocationGateway();

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> openLocationSettings() async {}

  @override
  Future<UtilityLocation> requestCurrentLocation() {
    throw const LocationAccessException(LocationAccessFailure.denied);
  }
}

final class _UnavailableCompassGateway implements CompassGateway {
  const _UnavailableCompassGateway();

  @override
  Stream<CompassReading> readings() => Stream.value(
    const CompassReading(
      heading: null,
      calibrationState: CompassCalibrationState.unavailable,
    ),
  );
}

final class _CalibrationCompassGateway implements CompassGateway {
  const _CalibrationCompassGateway();

  @override
  Stream<CompassReading> readings() => Stream.value(
    const CompassReading(
      heading: 125,
      calibrationState: CompassCalibrationState.needsCalibration,
    ),
  );
}
