import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sukun_life/features/islamic_utilities/data/compass_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/prayer_calculation_service.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_location_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/utility_preferences_store.dart';

final utilityPreferencesStoreProvider = Provider<UtilityPreferencesStore>(
  (ref) => const SharedPreferencesUtilityPreferencesStore(),
);

final utilityLocationGatewayProvider = Provider<UtilityLocationGateway>(
  (ref) => const GeolocatorUtilityLocationGateway(),
);

final prayerCalculationServiceProvider = Provider<PrayerCalculationService>(
  (ref) => AdhanPrayerCalculationService(),
);

final compassGatewayProvider = Provider<CompassGateway>(
  (ref) => const FlutterCompassGateway(),
);
