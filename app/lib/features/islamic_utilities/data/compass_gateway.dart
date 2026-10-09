import 'package:flutter_compass/flutter_compass.dart';
import 'package:sukun_life/features/islamic_utilities/domain/compass_reading.dart';

abstract interface class CompassGateway {
  Stream<CompassReading> readings();
}

/// Used by browsers and platforms without a compass plugin.
///
/// A calculated Qibla bearing still works. Never trigger an unsupported
/// native sensor channel on Flutter Web.
final class UnavailableCompassGateway implements CompassGateway {
  const UnavailableCompassGateway();

  @override
  Stream<CompassReading> readings() => Stream.value(
    const CompassReading(
      heading: null,
      calibrationState: CompassCalibrationState.unavailable,
    ),
  );
}

final class FlutterCompassGateway implements CompassGateway {
  const FlutterCompassGateway();

  @override
  Stream<CompassReading> readings() {
    final events = FlutterCompass.events;
    if (events == null) {
      return Stream.value(
        const CompassReading(
          heading: null,
          calibrationState: CompassCalibrationState.unavailable,
        ),
      );
    }
    return events.map((event) {
      final heading = event.heading;
      if (heading == null) {
        return const CompassReading(
          heading: null,
          calibrationState: CompassCalibrationState.unavailable,
        );
      }
      final accuracy = event.accuracy;
      return CompassReading(
        heading: heading,
        calibrationState: accuracy != null && accuracy < 2
            ? CompassCalibrationState.needsCalibration
            : CompassCalibrationState.ready,
      );
    });
  }
}
