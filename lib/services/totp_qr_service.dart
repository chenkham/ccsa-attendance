import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrValidationResult {
  final bool isValid;
  final String? subjectId;
  final String? sessionId;
  final bool geofenceEnabled;
  final double? targetLat;
  final double? targetLng;
  final double radiusMeters;
  final String? errorMessage;

  QrValidationResult({
    required this.isValid,
    this.subjectId,
    this.sessionId,
    this.geofenceEnabled = false,
    this.targetLat,
    this.targetLng,
    this.radiusMeters = 50.0,
    this.errorMessage,
  });

  factory QrValidationResult.success({
    required String subjectId,
    required String sessionId,
    bool geofenceEnabled = false,
    double? targetLat,
    double? targetLng,
    double radiusMeters = 50.0,
  }) {
    return QrValidationResult(
      isValid: true,
      subjectId: subjectId,
      sessionId: sessionId,
      geofenceEnabled: geofenceEnabled,
      targetLat: targetLat,
      targetLng: targetLng,
      radiusMeters: radiusMeters,
    );
  }

  factory QrValidationResult.fail(String message) {
    return QrValidationResult(
      isValid: false,
      errorMessage: message,
    );
  }
}

class TotpQrService {
  static final TotpQrService instance = TotpQrService._init();
  TotpQrService._init();

  static const int timeStepSeconds = 3; // Rotates every 3 seconds
  static const String _secretKey = 'CCSA_DIBRUGARH_UNIV_ATTENDANCE_SECRET_KEY_2026';

  /// Generates the payload encoded into the dynamic QR code for a given session
  String generateDynamicPayload({
    required String subjectId,
    required String sessionId,
    bool geofenceEnabled = false,
    double? targetLat,
    double? targetLng,
    double radiusMeters = 50.0,
    int? timestampMs,
  }) {
    final int now = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final int epochSlice = now ~/ (timeStepSeconds * 1000);

    // Compute HMAC-SHA256
    final message = '$subjectId:$sessionId:$epochSlice';
    final hmac = Hmac(sha256, utf8.encode(_secretKey));
    final digest = hmac.convert(utf8.encode(message));
    final token = digest.toString().substring(0, 12); // 12-char compact hash

    // JSON encoded payload with optional Layer 5 Geofence parameters
    final Map<String, dynamic> payloadMap = {
      'sub': subjectId,
      'ses': sessionId,
      'ts': epochSlice,
      'tok': token,
      'geo': geofenceEnabled ? 1 : 0,
    };

    if (geofenceEnabled && targetLat != null && targetLng != null) {
      payloadMap['lat'] = targetLat;
      payloadMap['lng'] = targetLng;
      payloadMap['rad'] = radiusMeters;
    }

    return jsonEncode(payloadMap);
  }

  /// Validates the scanned QR payload against the current and adjacent time slices
  QrValidationResult validatePayload(String rawPayload) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawPayload);
      final String? subjectId = data['sub'];
      final String? sessionId = data['ses'];
      final int? qrSlice = data['ts'];
      final String? scannedToken = data['tok'];
      final bool geofenceEnabled = data['geo'] == 1 || data['geo'] == true;
      final double? targetLat = data['lat'] != null ? (data['lat'] as num).toDouble() : null;
      final double? targetLng = data['lng'] != null ? (data['lng'] as num).toDouble() : null;
      final double radiusMeters = data['rad'] != null ? (data['rad'] as num).toDouble() : 50.0;

      if (subjectId == null || sessionId == null || qrSlice == null || scannedToken == null) {
        return QrValidationResult.fail('Invalid or corrupted QR format.');
      }

      final int currentSlice = DateTime.now().millisecondsSinceEpoch ~/ (timeStepSeconds * 1000);

      // Allow current slice and previous slice (tolerance of 3 to 6 seconds)
      bool matchFound = false;
      for (int offset = -1; offset <= 1; offset++) {
        final testSlice = currentSlice + offset;
        if (testSlice == qrSlice) {
          final message = '$subjectId:$sessionId:$testSlice';
          final hmac = Hmac(sha256, utf8.encode(_secretKey));
          final digest = hmac.convert(utf8.encode(message));
          final expectedToken = digest.toString().substring(0, 12);

          if (expectedToken == scannedToken) {
            matchFound = true;
            break;
          }
        }
      }

      if (!matchFound) {
        return QrValidationResult.fail('QR code has expired or is invalid. Please scan the live screen.');
      }

      return QrValidationResult.success(
        subjectId: subjectId,
        sessionId: sessionId,
        geofenceEnabled: geofenceEnabled,
        targetLat: targetLat,
        targetLng: targetLng,
        radiusMeters: radiusMeters,
      );
    } catch (e) {
      return QrValidationResult.fail('Could not parse QR data: $e');
    }
  }

  /// Remaining fraction (0.0 to 1.0) of the current 3-second cycle for the countdown dial
  double get cycleProgress {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int elapsedInCycle = now % (timeStepSeconds * 1000);
    return elapsedInCycle / (timeStepSeconds * 1000);
  }

  /// Remaining seconds in current slice
  int get remainingSecondsInCycle {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int elapsedInCycle = now % (timeStepSeconds * 1000);
    final int remainingMs = (timeStepSeconds * 1000) - elapsedInCycle;
    return (remainingMs / 1000).ceil();
  }
}
