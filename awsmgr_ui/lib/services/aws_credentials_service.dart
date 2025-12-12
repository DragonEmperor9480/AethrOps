import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class AWSCredentialsService {
  static const _storage = FlutterSecureStorage();

  static const _keyAccessKey = 'aws_access_key_id';
  static const _keySecretKey = 'aws_secret_access_key';
  static const _keyRegion = 'aws_region';

  // Save AWS credentials securely
  static Future<void> saveCredentials({
    required String accessKey,
    required String secretKey,
    required String region,
  }) async {
    await _storage.write(key: _keyAccessKey, value: accessKey);
    await _storage.write(key: _keySecretKey, value: secretKey);
    await _storage.write(key: _keyRegion, value: region);
  }

  // Get AWS credentials
  static Future<Map<String, String?>> getCredentials() async {
    final accessKey = await _storage.read(key: _keyAccessKey);
    final secretKey = await _storage.read(key: _keySecretKey);
    final region = await _storage.read(key: _keyRegion);

    return {'accessKey': accessKey, 'secretKey': secretKey, 'region': region};
  }

  // Check if credentials exist
  static Future<bool> hasCredentials() async {
    final accessKey = await _storage.read(key: _keyAccessKey);
    final secretKey = await _storage.read(key: _keySecretKey);
    return accessKey != null && secretKey != null;
  }

  // Delete all credentials
  static Future<void> deleteCredentials() async {
    // Delete from secure storage
    await _storage.delete(key: _keyAccessKey);
    await _storage.delete(key: _keySecretKey);
    await _storage.delete(key: _keyRegion);

    // Also delete from filesystem via backend API
    try {
      final response = await http.delete(
        Uri.parse('${BackendService.baseUrl}/api/aws/config'),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Warning: Failed to delete credential files: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Warning: Failed to call backend delete endpoint: $e');
    }
  }
}
