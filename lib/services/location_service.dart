import 'dart:async';
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

  /// Ensures location service is on and permission granted. Returns false if
  /// access is impossible.
  Future<bool> _ensureLocationAccess() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled on this device.');
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await Geolocator.openLocationSettings();
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return false;
    }
    return true;
  }

  /// Attempts to acquire current GPS fix from device with high & medium accuracy fallback
  Future<Position?> getCurrentPosition() async {
    try {
      if (!await _ensureLocationAccess()) return null;

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

  /// High-accuracy capture: listens to the location stream for up to [window]
  /// and returns the reading with the smallest accuracy radius.
  ///
  /// Quality rules (mirrors how map apps treat fixes):
  ///  - readings worse than [maxAcceptableAccuracy] are WiFi/cell-grade noise;
  ///    they are tracked only as a last-resort fallback and never win.
  ///  - early exit once a fix meets [targetAccuracy] AND at least
  ///    [minStableSeconds] have elapsed (guards against lucky first blips).
  ///  - otherwise runs the full window and returns the best GNSS-grade fix.
  /// Falls back to [getCurrentPosition] when nothing usable arrives.
  Future<Position?> getHighAccuracyPosition({
    Duration window = const Duration(seconds: 15),
    double targetAccuracy = 12.0,
    double maxAcceptableAccuracy = 50.0,
    int minStableSeconds = 3,
    void Function(Position? best, int elapsedSeconds)? onProgress,
  }) async {
    try {
      if (!await _ensureLocationAccess()) return null;

      Position? best;      // best GNSS-grade fix (<= maxAcceptableAccuracy)
      Position? fallback;  // best of the noisy readings, only if nothing better
      int stableReadings = 0;
      final completer = Completer<Position?>();
      final startedAt = DateTime.now();

      Timer? ticker;
      Timer? timeout;
      StreamSubscription<Position>? sub;

      void finish() {
        ticker?.cancel();
        timeout?.cancel();
        if (!completer.isCompleted) completer.complete(best ?? fallback);
      }

      sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).listen(
        (pos) {
          final elapsed = DateTime.now().difference(startedAt).inSeconds;

          if (pos.accuracy > maxAcceptableAccuracy) {
            // WiFi/cell-grade noise — never displace a GNSS-grade fix
            fallback ??= pos;
            if (pos.accuracy < fallback!.accuracy) fallback = pos;
            onProgress?.call(best ?? fallback, elapsed);
            return;
          }

          final prev = best?.accuracy;
          if (best == null || pos.accuracy < best!.accuracy) {
            best = pos;
            onProgress?.call(best, elapsed);
          }

          // Convergence detection: accuracy has stopped improving
          if (prev != null && (prev - best!.accuracy).abs() < 1.0) {
            stableReadings++;
          } else {
            stableReadings = 0;
          }

          // Early finish: on-target fix that has held steady for 3+ readings
          if (best != null &&
              best!.accuracy <= targetAccuracy &&
              elapsed >= minStableSeconds &&
              stableReadings >= 2 &&
              !completer.isCompleted) {
            finish();
          }
        },
        onError: (_) => finish(),
      );

      timeout = Timer(window, finish);
      ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        onProgress?.call(best ?? fallback, DateTime.now().difference(startedAt).inSeconds);
      });

      final result = await completer.future;
      await sub.cancel();
      ticker.cancel();
      timeout.cancel();

      return result ?? await getCurrentPosition();
    } catch (e) {
      debugPrint('LocationService getHighAccuracyPosition error: $e');
      return getCurrentPosition();
    }
  }

  /// Checks if student is physically within the geofenced radius of the classroom.
  /// Uses the stream-based high-accuracy capture (best fix within a short
  /// window) instead of the first GPS blip — first fixes can be 100–300m off,
  /// which caused false "too far away" rejections. The device-reported
  /// accuracy is added to the allowed radius as tolerance (like Google Maps).
  Future<GeofenceCheckResult> verifyStudentInClassroom({
    required double targetLat,
    required double targetLng,
    required double radiusMeters,
  }) async {
    final position = await getHighAccuracyPosition(
      window: const Duration(seconds: 7),
      targetAccuracy: 20.0,
    );

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

    // Tolerance = reported GPS accuracy (min 15m cushion for indoor concrete).
    // If the phone itself says "±20m", a 20m error is not the student's fault.
    final double tolerance = (position.accuracy > 15.0 ? position.accuracy : 15.0).clamp(15.0, 80.0);
    final double effectiveRadius = radiusMeters + tolerance;
    final bool isInside = distance <= effectiveRadius;

    return GeofenceCheckResult(
      isWithin: isInside,
      distanceMeters: distance,
      userLatitude: position.latitude,
      userLongitude: position.longitude,
      errorMessage: isInside
          ? null
          : 'You are ${distance.toStringAsFixed(0)}m away (GPS accuracy ±${position.accuracy.toStringAsFixed(0)}m). Allowed radius: ${radiusMeters.toStringAsFixed(0)}m. Move closer and scan again.',
    );
  }
}
