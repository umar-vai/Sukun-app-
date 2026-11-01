import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/app/theme/sukun_colors.dart';
import 'package:sukun_life/app/theme/sukun_theme.dart';
import 'package:sukun_life/features/islamic_utilities/data/compass_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_location_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';
import 'package:sukun_life/features/islamic_utilities/domain/compass_reading.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_settings.dart';
import 'package:sukun_life/features/islamic_utilities/domain/prayer_schedule.dart';
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

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets('selected Dhuhr row remains readable in ${brightness.name}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theme = brightness == Brightness.dark
          ? SukunTheme.dark()
          : SukunTheme.light();
      await tester.pumpWidget(
        _testApp(
          const PrayerTimesScreen(),
          settings: _configuredSettings,
          theme: theme,
          calculationService: const _FixedDhuhrSchedule(),
        ),
      );
      await tester.pumpAndSettle();

      final selected = find.byKey(const Key('prayer-time-row-dhuhr'));
      await tester.scrollUntilVisible(selected, 250);
      await tester.pumpAndSettle();

      final tile = tester.widget<Container>(selected);
      expect(tile.color, SukunColors.deepTide);
      final selectedTexts = tester
          .widgetList<Text>(
            find.descendant(of: selected, matching: find.byType(Text)),
          )
          .toList();
      expect(selectedTexts.map((text) => text.data), contains('Dhuhr'));
      expect(selectedTexts.length, 2);
      for (final text in selectedTexts) {
        expect(text.style?.color, Colors.white);
      }
      final selectedIcon = tester.widget<Icon>(
        find.descendant(of: selected, matching: find.byType(Icon)),
      );
      expect(selectedIcon.icon, Icons.wb_sunny_outlined);
      expect(selectedIcon.color, Colors.white);

      final normal = find.byKey(const Key('prayer-time-row-fajr'));
      final normalTile = tester.widget<Container>(normal);
      expect(normalTile.color, Colors.transparent);
      final normalTexts = tester.widgetList<Text>(
        find.descendant(of: normal, matching: find.byType(Text)),
      );
      for (final text in normalTexts) {
        expect(text.style?.color, theme.colorScheme.onSurface);
      }
      expect(tester.takeException(), isNull);
    });
  }

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
  PrayerCalculationService? calculationService,
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: [
      utilityPreferencesStoreProvider.overrideWithValue(
        _MemorySettingsStore(settings),
      ),
      utilityLocationGatewayProvider.overrideWithValue(locationGateway),
      compassGatewayProvider.overrideWithValue(compassGateway),
      prayerCalculationServiceProvider.overrideWithValue(
        calculationService ?? AdhanPrayerCalculationService(),
      ),
    ],
    child: MaterialApp(theme: theme, home: home),
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

final class _FixedDhuhrSchedule implements PrayerCalculationService {
  const _FixedDhuhrSchedule();

  @override
  PrayerDaySchedule calculate({
    required PrayerUtilitySettings settings,
    required DateTime now,
  }) {
    final day = DateTime(2026, 11, 1);
    final fajr = PrayerTimeEntry(
      id: 'fajr',
      label: 'Fajr',
      time: day.add(const Duration(hours: 5)),
    );
    final sunrise = PrayerTimeEntry(
      id: 'sunrise',
      label: 'Sunrise',
      time: day.add(const Duration(hours: 6)),
      isPrayer: false,
    );
    final dhuhr = PrayerTimeEntry(
      id: 'dhuhr',
      label: 'Dhuhr',
      time: day.add(const Duration(hours: 12)),
    );
    final asr = PrayerTimeEntry(
      id: 'asr',
      label: 'Asr',
      time: day.add(const Duration(hours: 16)),
    );
    final maghrib = PrayerTimeEntry(
      id: 'maghrib',
      label: 'Maghrib',
      time: day.add(const Duration(hours: 18)),
    );
    final isha = PrayerTimeEntry(
      id: 'isha',
      label: 'Isha',
      time: day.add(const Duration(hours: 20)),
    );
    return PrayerDaySchedule(
      date: day,
      entries: [fajr, sunrise, dhuhr, asr, maghrib, isha],
      currentPrayer: dhuhr,
      nextPrayer: asr,
      qiblaBearing: 270,
    );
  }
}
