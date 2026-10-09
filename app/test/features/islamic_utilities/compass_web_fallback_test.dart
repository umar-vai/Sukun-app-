import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukun_life/features/islamic_utilities/data/compass_gateway.dart';
import 'package:sukun_life/features/islamic_utilities/data/islamic_utilities_providers.dart';
import 'package:sukun_life/features/islamic_utilities/domain/compass_reading.dart';

void main() {
  test('unsupported sensors produce an explicit unavailable reading', () async {
    final reading = await const UnavailableCompassGateway().readings().first;
    expect(reading.heading, isNull);
    expect(reading.calibrationState, CompassCalibrationState.unavailable);
    expect(reading.isAvailable, isFalse);
    expect(reading.relativeQibla(279.3), 279.3);
  });

  test('browser uses fallback instead of invoking native compass plugin', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gateway = container.read(compassGatewayProvider);
    if (kIsWeb) {
      expect(gateway, isA<UnavailableCompassGateway>());
    } else {
      expect(gateway, isA<FlutterCompassGateway>());
    }
  });
}
