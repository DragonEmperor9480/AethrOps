import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ec2_launch_request.dart';
import 'backend_service.dart';

class Ec2Service {
  static String get baseUrl => '${BackendService.baseUrl}/api';

  static Future<Map<String, dynamic>> launchInstance(
    Ec2LaunchRequest request,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ec2/instances'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to launch instance');
    }
  }

  static Future<List<dynamic>> listSecurityGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/ec2/security-groups'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['security_groups'] ?? [];
    }
    throw Exception('Failed to load security groups');
  }

  static Future<List<dynamic>> listKeyPairs() async {
    final response = await http.get(Uri.parse('$baseUrl/ec2/key-pairs'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['key_pairs'] ?? [];
    }
    throw Exception('Failed to load key pairs');
  }

  static Future<List<dynamic>> listSubnets() async {
    final response = await http.get(Uri.parse('$baseUrl/ec2/subnets'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['subnets'] ?? [];
    }
    throw Exception('Failed to load subnets');
  }

  static Future<List<dynamic>> listVpcs() async {
    final response = await http.get(Uri.parse('$baseUrl/ec2/vpcs'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['vpcs'] ?? [];
    }
    throw Exception('Failed to load VPCs');
  }
}
