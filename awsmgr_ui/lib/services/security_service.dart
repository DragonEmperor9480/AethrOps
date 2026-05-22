import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Storage keys
  static const _pinHashKey = 'app_pin_hash';
  static const _securityEnabledKey = 'security_enabled';
  static const _biometricEnabledKey = 'biometric_enabled';

  /// Check if security (PIN) is enabled
  static Future<bool> isSecurityEnabled() async {
    final enabled = await _storage.read(key: _securityEnabledKey);
    return enabled == 'true';
  }

  /// Check if biometric authentication is enabled
  static Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: _biometricEnabledKey);
    return enabled == 'true';
  }

  /// Check if device supports biometric authentication
  static Future<bool> canUseBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric support: $e');
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Hash PIN using SHA-256
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set up PIN security
  static Future<void> setupPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _securityEnabledKey, value: 'true');
  }

  /// Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) return false;

    final inputHash = _hashPin(pin);
    return inputHash == storedHash;
  }

  /// Enable/disable biometric authentication
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  /// Authenticate with biometrics (includes Windows Hello, Face ID, Touch ID, Fingerprint)
  static Future<bool> authenticateWithBiometric() async {
    if (!await canUseBiometric()) {
      return false;
    }

    try {
      return await _localAuth.authenticate(
        localizedReason: Platform.isWindows
            ? 'Verify your identity to access AethrOps'
            : 'Authenticate to access AethrOps',
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }

  /// Disable security (remove PIN)
  static Future<void> disableSecurity() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _securityEnabledKey);
    await _storage.delete(key: _biometricEnabledKey);
  }

  /// Change PIN
  static Future<void> changePin(String oldPin, String newPin) async {
    final isValid = await verifyPin(oldPin);
    if (!isValid) {
      throw Exception('Invalid current PIN');
    }
    await setupPin(newPin);
  }
}
