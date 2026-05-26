import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_service.dart';

class AWSProfileService {
  // Check auth status on startup
  static Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendService.baseUrl}/api/aws/auth-status'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'no_accounts', 'message': 'Failed to load status'};
    } catch (e) {
      debugPrint('Error getting AWS auth status: $e');
      return {'status': 'no_accounts', 'message': e.toString()};
    }
  }

  // List all profiles
  static Future<List<dynamic>> listAccounts() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendService.baseUrl}/api/aws/accounts'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error listing AWS accounts: $e');
      return [];
    }
  }

  // Create new profile
  static Future<Map<String, dynamic>> createAccount({
    required String profileName,
    required String accessKey,
    required String secretKey,
    required String region,
    String output = 'json',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${BackendService.baseUrl}/api/aws/accounts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'profile_name': profileName,
          'access_key_id': accessKey,
          'secret_access_key': secretKey,
          'region': region,
          'output': output,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'], 'account': data['account']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to create account'};
    } catch (e) {
      debugPrint('Error creating AWS account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Activate an existing profile
  static Future<Map<String, dynamic>> activateAccount(int id) async {
    try {
      final response = await http.post(
        Uri.parse('${BackendService.baseUrl}/api/aws/accounts/activate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': id}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to activate account'};
    } catch (e) {
      debugPrint('Error activating AWS account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete an existing profile
  static Future<Map<String, dynamic>> deleteAccount(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('${BackendService.baseUrl}/api/aws/accounts/$id'),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Failed to delete account'};
    } catch (e) {
      debugPrint('Error deleting AWS account: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
