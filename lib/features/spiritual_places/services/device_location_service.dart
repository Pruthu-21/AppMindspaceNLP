import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/permission_service.dart';

enum LocationPrerequisiteStatus {
  ready,
  permissionDenied,
  permissionDeniedForever,
  gpsDisabled,
}

class DeviceLocationService {
  /// Developer-only mock location mode for emulator testing.
  /// Disabled by default so normal users always use real GPS.
  static bool isDeveloperMockEnabled = false;
  static Position? mockPosition;

  static void setMockLocation({
    required double latitude,
    required double longitude,
  }) {
    isDeveloperMockEnabled = true;
    mockPosition = Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  static void clearMockLocation() {
    isDeveloperMockEnabled = false;
    mockPosition = null;
  }

  /// Checks device location prerequisites (permission and GPS service).
  Future<LocationPrerequisiteStatus> checkPrerequisites() async {
    if (isDeveloperMockEnabled && mockPosition != null) {
      return LocationPrerequisiteStatus.ready;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return LocationPrerequisiteStatus.permissionDenied;
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationPrerequisiteStatus.permissionDeniedForever;
    }

    final isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      return LocationPrerequisiteStatus.gpsDisabled;
    }

    return LocationPrerequisiteStatus.ready;
  }

  /// Requests permission using the existing MindSpaceNLP explanation UI.
  Future<bool> requestPermissionWithUI(BuildContext context) async {
    return await PermissionService.requestLocationPermission(context);
  }

  Future<Position?> getCurrentPosition() async {
    // Return mock position if developer mode is explicitly enabled
    if (isDeveloperMockEnabled && mockPosition != null) {
      return mockPosition;
    }

    final prereq = await checkPrerequisites();
    if (prereq != LocationPrerequisiteStatus.ready) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Geolocator location error / timeout: $e');
      return null;
    }
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
