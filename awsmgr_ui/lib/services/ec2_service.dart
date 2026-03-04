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

  static Future<List<dynamic>> listSecurityGroups({String? region}) async {
    final uri = region != null
        ? Uri.parse('$baseUrl/ec2/security-groups').replace(
            queryParameters: {'region': region},
          )
        : Uri.parse('$baseUrl/ec2/security-groups');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['security_groups'] ?? [];
    }
    throw Exception('Failed to load security groups');
  }

  static Future<List<dynamic>> listKeyPairs({String? region}) async {
    final uri = region != null
        ? Uri.parse('$baseUrl/ec2/key-pairs').replace(
            queryParameters: {'region': region},
          )
        : Uri.parse('$baseUrl/ec2/key-pairs');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['key_pairs'] ?? [];
    }
    throw Exception('Failed to load key pairs');
  }

  static Future<List<dynamic>> listSubnets({String? region}) async {
    final uri = region != null
        ? Uri.parse('$baseUrl/ec2/subnets').replace(
            queryParameters: {'region': region},
          )
        : Uri.parse('$baseUrl/ec2/subnets');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['subnets'] ?? [];
    }
    throw Exception('Failed to load subnets');
  }

  static Future<List<dynamic>> listVpcs({String? region}) async {
    final uri = region != null
        ? Uri.parse('$baseUrl/ec2/vpcs').replace(
            queryParameters: {'region': region},
          )
        : Uri.parse('$baseUrl/ec2/vpcs');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['vpcs'] ?? [];
    }
    throw Exception('Failed to load VPCs');
  }

  static Future<List<dynamic>> listAMIs({String? region}) async {
    final uri = region != null
        ? Uri.parse('$baseUrl/ec2/amis').replace(
            queryParameters: {'region': region},
          )
        : Uri.parse('$baseUrl/ec2/amis');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['amis'] ?? [];
    }
    throw Exception('Failed to load AMIs');
  }

  static Future<List<String>> listRegions() async {
    final response = await http.get(Uri.parse('$baseUrl/ec2/regions'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['regions'] ?? []);
    }
    throw Exception('Failed to load regions');
  }
}
