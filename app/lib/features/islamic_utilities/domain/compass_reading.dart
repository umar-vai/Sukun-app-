enum CompassCalibrationState { ready, needsCalibration, unavailable }

class CompassReading {
  const CompassReading({required this.heading, required this.calibrationState});

  final double? heading;
  final CompassCalibrationState calibrationState;

  bool get isAvailable => heading != null;

  double relativeQibla(double bearing) {
    if (heading == null) return bearing;
    return (bearing - heading! + 360) % 360;
  }
}
