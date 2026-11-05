import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricSetupResult { enabled, unavailable, canceled }

/// Device-local presentation preferences. These never enter settings.json,
/// app-managed backups or iCloud sync, and do not change the exchange Keychain policy.
class PrivacyService {
  PrivacyService._();

  static final PrivacyService instance = PrivacyService._();
  static const MethodChannel _channel = MethodChannel(
    'org.bitlap.assets/privacy',
  );

  final ValueNotifier<bool> hideAmounts = ValueNotifier(false);
  final ValueNotifier<bool> biometricLock = ValueNotifier(false);
  LocalAuthentication authenticator = LocalAuthentication();

  Future<void> initialize() async {
    try {
      final values = await _channel.invokeMapMethod<String, bool>('read');
      hideAmounts.value = values?['hideAmounts'] ?? false;
      biometricLock.value = values?['biometricLock'] ?? false;
    } on PlatformException catch (error) {
      debugPrint('[PrivacyService] Could not load preferences: $error');
    }
  }

  Future<void> setHideAmounts(bool value) async {
    await _channel.invokeMethod<void>('setHideAmounts', value);
    hideAmounts.value = value;
  }

  /// Enrollment is required before enabling; the system passcode remains an
  /// unlock fallback if biometrics become unavailable later.
  Future<BiometricSetupResult> enableBiometricLock(String reason) async {
    if (!await authenticator.canCheckBiometrics ||
        (await authenticator.getAvailableBiometrics()).isEmpty) {
      return BiometricSetupResult.unavailable;
    }
    if (!await authenticator.authenticate(
      localizedReason: reason,
      biometricOnly: true,
    )) {
      return BiometricSetupResult.canceled;
    }
    await _channel.invokeMethod<void>('setBiometricLock', true);
    biometricLock.value = true;
    return BiometricSetupResult.enabled;
  }

  Future<void> disableBiometricLock() async {
    await _channel.invokeMethod<void>('setBiometricLock', false);
    biometricLock.value = false;
  }

  Future<bool> authenticate(String reason) =>
      authenticator.authenticate(localizedReason: reason, biometricOnly: false);
}
