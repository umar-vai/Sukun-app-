import 'dart:async';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sukun_life/features/islamic_utilities/domain/utility_location.dart';

enum LocationAccessFailure { serviceDisabled, denied, deniedForever, timedOut }

class LocationAccessException implements Exception {
  const LocationAccessException(this.failure);

  final LocationAccessFailure failure;

  String get userMessage => switch (failure) {
    LocationAccessFailure.serviceDisabled => 'Location services are turned off. Enable them or select a city manually.',
    LocationAccessFailure.denied =>
      'Location permission was not granted. You can select a city manually.',
    LocationAccessFailure.deniedForever => 'Location access is blocked in system settings. Open settings or select a city manually.',
    LocationAccessFailure.timedOut => 'Your location could not be found in time. Try again or select a city manually.',
  };

  @override
  String toString() => userMessage;
}

abstract interface class UtilityLocationGateway {
  Future<UtilityLocation> requestCurrentLocation();
  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

final class GeolocatorUtilityLocationGateway implements UtilityLocationGateway {
  const GeolocatorUtilityLocationGateway();

  @override
  Future<UtilityLocation> requestCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationAccessException(
        LocationAccessFailure.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationAccessException(LocationAccessFailure.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationAccessException(LocationAccessFailure.deniedForever);
    }
    try {
      final results = await Future.wait<Object>([
        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        ),
        FlutterTimezone.getLocalTimezone(),
      ]);
      final position = results[0] as Position;
      final timezone = results[1] as TimezoneInfo;
      return UtilityLocation(
        id: 'device',
        name: 'Current location',
        latitude: position.latitude,
        longitude: position.longitude,
        timezone: timezone.identifier,
        source: UtilityLocationSource.device,
      );
    } on TimeoutException {
      throw const LocationAccessException(LocationAccessFailure.timedOut);
    }
  }

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
