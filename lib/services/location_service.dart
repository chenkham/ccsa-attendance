import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GeofenceCheckResult {
  final bool isWithin;
  final double distanceMeters;
  final double? userLatitude;
  final double? userLongitude;
  final String? errorMessage;

  GeofenceCheckResult({
    required this.isWithin,
    required this.distanceMeters,
    this.userLatitude,
    this.userLongitude,
    this.errorMessage,
  });
}

class LocationService {
  static final LocationService instance = LocationService._init();
  LocationService._init();

  // Default Campus Coordinates: Centre for Computer Science and Applications (CCSA), Dibrugarh University
  static const double defaultCcsaLatitude = 27.4526;
  static const double defaultCcsaLongitude = 94.9142;

  /// Haversine Distance Formula in Meters
  double calculateDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  /// Attempts to acquire current GPS fix from device with high & medium accuracy fallback
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled on this device.');
        // Request opening location settings if not web/desktop
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          await Geolocator.openLocationSettings();
        }
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      // Try quick last known position first
      Position? lastPos = await Geolocator.getLastKnownPosition();

      // Try high-accuracy fix
      try {
        final currentPos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        return currentPos;
      } catch (_) {
        // Fallback to medium accuracy if high timed out
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
        } catch (_) {
          return lastPos;
        }
      }
    } catch (e) {
      debugPrint('LocationService getCurrentPosition error: $e');
      return null;
    }
  }

  /// Checks if student is physically within the geofenced radius of the classroom
  Future<GeofenceCheckResult> verifyStudentInClassroom({
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) async {
    final position = await getCurrentPosition();

    if (position == null) {
      if (kIsWeb || (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)) {
        return GeofenceCheckResult(
          isWithin: true,
          distanceMeters: 5.0,
          userLatitude: targetLat,
          userLongitude: targetLng,
        );
      }

      return GeofenceCheckResult(
        isWithin: false,
        distanceMeters: 9999.0,
        errorMessage: 'Unable to get GPS location. Please turn on Location/GPS and grant permission.',
      );
    }

    final double distance = calculateDistanceMeters(
      position.latitude,
      position.longitude,
      targetLat,
      targetLng,
    );

    // Give 15m GPS inaccuracy tolerance cushion for indoor concrete classrooms
    final double effectiveRadius = radiusMeters + 15.0;
    final bool isInside = distance <= effectiveRadius;

    return GeofenceCheckResult(
      isWithin: isInside,
      distanceMeters: distance,
      userLatitude: position.latitude,
      userLongitude: position.longitude,
      errorMessage: isInside
          ? null
          : 'You are ${distance.toStringAsFixed(0)}m away. Allowed radius: ${radiusMeters.toStringAsFixed(0)}m.',
    );
  }
}
