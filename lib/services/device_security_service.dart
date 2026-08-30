import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

class DeviceSecurityService {
  static final DeviceSecurityService instance = DeviceSecurityService._init();
  DeviceSecurityService._init();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final LocalAuthentication _localAuth = LocalAuthentication();
  String? _cachedDeviceId;

  /// Retrieves a persistent hardware identifier for 1-student = 1-device binding
  Future<String> getHardwareDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      if (kIsWeb) {
        _cachedDeviceId = 'web_client';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _cachedDeviceId = androidInfo.id; // Persistent Android build ID
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _cachedDeviceId = iosInfo.identifierForVendor ?? 'ios_device';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        _cachedDeviceId = windowsInfo.deviceId;
      } else {
        _cachedDeviceId = 'generic_device';
      }
    } catch (e) {
      debugPrint('DeviceSecurityService error: $e');
      _cachedDeviceId = 'fallback_device_id';
    }

    return _cachedDeviceId!;
  }

  /// Checks if device has biometric hardware support
  Future<bool> isBiometricSupported() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      return canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Triggers a 0.1s instant native biometric prompt (Fingerprint / Face ID)
  Future<bool> authenticateBiometric({String reason = 'Confirm physical presence for attendance'}) async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        // Device doesn't have biometric hardware enrolled; permit pass
        return true;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: false,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication skipped/error: $e');
      return true; // Fallback permit on hardware failure
    }
  }
}
