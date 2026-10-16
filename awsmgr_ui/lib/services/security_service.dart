import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Outcome of a PIN check. [lockedFor] is set when further attempts are
/// blocked, either by this failure or by an earlier lockout.
class PinCheckResult {
  final bool success;
  final Duration? lockedFor;

  const PinCheckResult({required this.success, this.lockedFor});
}

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // Storage keys
  static const _pinHashKey = 'app_pin_hash';
  static const _securityEnabledKey = 'security_enabled';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _failedAttemptsKey = 'pin_failed_attempts';
  static const _lockedUntilKey = 'pin_locked_until';

  // PIN hashing: PBKDF2-HMAC-SHA256 with a random per-PIN salt
  static const _hashScheme = 'pbkdf2-sha256';
  static const _hashIterations = 50000;

  // Attempts allowed before lockouts start; each further failure doubles
  // the lockout, up to the maximum
  static const _freeAttempts = 5;
  static const _baseLockout = Duration(seconds: 30);
  static const _maxLockout = Duration(hours: 1);

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

  /// PBKDF2-HMAC-SHA256 with a single 32-byte output block
  static List<int> _pbkdf2(List<int> password, List<int> salt, int rounds) {
    final hmac = Hmac(sha256, password);
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = List<int>.from(u);
    for (var i = 1; i < rounds; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < out.length; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  static List<int> _pbkdf2Isolate((String, List<int>, int) args) =>
      _pbkdf2(utf8.encode(args.$1), args.$2, args.$3);

  /// Hash a PIN as "pbkdf2-sha256$iterations$salt$hash" (base64 fields)
  static Future<String> _hashPin(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final hash = await compute(_pbkdf2Isolate, (pin, salt, _hashIterations));
    return '$_hashScheme\$$_hashIterations\$${base64.encode(salt)}\$${base64.encode(hash)}';
  }

  /// Check a PIN against a stored hash. Hashes from older builds are
  /// unsalted SHA-256 hex digests.
  static Future<bool> _matches(String pin, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length == 4 && parts[0] == _hashScheme) {
      final rounds = int.tryParse(parts[1]);
      if (rounds == null || rounds <= 0) return false;
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final actual = await compute(_pbkdf2Isolate, (pin, salt, rounds));
      return _constantTimeEquals(actual, expected);
    }
    final legacy = sha256.convert(utf8.encode(pin)).toString();
    return _constantTimeEquals(utf8.encode(legacy), utf8.encode(stored));
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Set up PIN security
  static Future<void> setupPin(String pin) async {
    final hash = await _hashPin(pin);
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _securityEnabledKey, value: 'true');
    await _resetFailedAttempts();
  }

  /// Time left before another PIN attempt is allowed, or null if none
  static Future<Duration?> pinLockoutRemaining() async {
    final until = int.tryParse(await _storage.read(key: _lockedUntilKey) ?? '');
    if (until == null) return null;
    final remaining = DateTime.fromMillisecondsSinceEpoch(
      until,
    ).difference(DateTime.now());
    // Also guards against a clock moved back far past the lockout
    if (remaining <= Duration.zero || remaining > _maxLockout) return null;
    return remaining;
  }

  /// Verify PIN. Failed attempts are counted in secure storage, so
  /// restarting the app does not reset them; after [_freeAttempts]
  /// failures each further one locks PIN entry for an increasing time.
  static Future<PinCheckResult> verifyPin(String pin) async {
    final locked = await pinLockoutRemaining();
    if (locked != null) {
      return PinCheckResult(success: false, lockedFor: locked);
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) return const PinCheckResult(success: false);

    if (await _matches(pin, storedHash)) {
      await _resetFailedAttempts();
      // Upgrade a legacy unsalted hash now that the PIN is known
      if (!storedHash.startsWith('$_hashScheme\$')) {
        await _storage.write(key: _pinHashKey, value: await _hashPin(pin));
      }
      return const PinCheckResult(success: true);
    }

    final failures =
        (int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ??
            0) +
        1;
    await _storage.write(key: _failedAttemptsKey, value: '$failures');
    if (failures < _freeAttempts) return const PinCheckResult(success: false);

    final lockout = _lockoutFor(failures);
    await _storage.write(
      key: _lockedUntilKey,
      value: '${DateTime.now().add(lockout).millisecondsSinceEpoch}',
    );
    return PinCheckResult(success: false, lockedFor: lockout);
  }

  static Duration _lockoutFor(int failures) {
    final doublings = min(failures - _freeAttempts, 20);
    final lockout = _baseLockout * pow(2, doublings).toInt();
    return lockout > _maxLockout ? _maxLockout : lockout;
  }

  /// Clear the failed-attempt counter, e.g. after a biometric unlock
  static Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockedUntilKey);
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
      final success = await _localAuth.authenticate(
        localizedReason: Platform.isWindows
            ? 'Verify your identity to access AethrOps'
            : 'Authenticate to access AethrOps',
      );
      if (success) await _resetFailedAttempts();
      return success;
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
    await _resetFailedAttempts();
  }

  /// Change PIN
  static Future<void> changePin(String oldPin, String newPin) async {
    final result = await verifyPin(oldPin);
    if (!result.success) {
      throw Exception('Invalid current PIN');
    }
    await setupPin(newPin);
  }
}
