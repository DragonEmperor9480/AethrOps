import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/s3_browser_screen.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:9480/api';

  // IAM Users
  static Future<List<dynamic>> listIAMUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/iam/users'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['users'] ?? [];
    }
    throw Exception('Failed to load users');
  }

  static Future<Map<String, dynamic>> createMultipleIAMUsers(
    List<Map<String, dynamic>> users,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/batch'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'users': users}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to create users');
    }
  }

  static Future<void> createIAMUser(
    String username, {
    String? password,
    bool requireReset = false,
  }) async {
    final body = <String, dynamic>{
      'username': username,
    };
    
    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['require_reset'] = requireReset;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to create user');
    }
  }

  static Future<Map<String, dynamic>> checkUserDependencies(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/iam/users/$username/dependencies'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to check dependencies');
  }

  static Future<List<dynamic>> getUserGroups(String username) async {
    final response = await http.get(
      Uri.parse('$baseUrl/iam/users/$username/groups'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['groups'] ?? [];
    }
    throw Exception('Failed to get user groups');
  }

  static Future<void> attachUserPolicy(String username, String policyArn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/$username/policies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'policy_arn': policyArn}),
    );
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to attach policy');
    }
  }

  static Future<Map<String, dynamic>> attachMultipleUserPolicies(
    List<Map<String, String>> attachments,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/policies/batch'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'attachments': attachments}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to attach policies');
    }
  }

  static Future<Map<String, dynamic>> syncUserPolicies(
    String username,
    List<String> desiredArns,
    List<String> currentArns,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/$username/policies/sync'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'desired_arns': desiredArns,
        'current_arns': currentArns,
      }),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to sync policies');
    }
  }

  static Future<void> sendUserCredentialsEmail({
    required String username,
    required String password,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/send-credentials'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
        'email': email,
        // console_url and email_config are now automatically handled by the backend
      }),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to send credentials email');
    }
  }

  // Email Configuration
  static Future<Map<String, dynamic>> getEmailConfig() async {
    final response = await http.get(Uri.parse('$baseUrl/email/config'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get email config');
  }

  static Future<void> saveEmailConfig({
    required String smtpHost,
    required int smtpPort,
    required String senderEmail,
    required String senderPass,
    required String senderName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/email/config'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'smtp_host': smtpHost,
        'smtp_port': smtpPort,
        'sender_email': senderEmail,
        'sender_pass': senderPass,
        'sender_name': senderName,
      }),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to save email config');
    }
  }

  static Future<void> deleteEmailConfig() async {
    final response = await http.delete(Uri.parse('$baseUrl/email/config'));
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete email config');
    }
  }

  // MFA Device Configuration
  static Future<Map<String, dynamic>> getMFADevice() async {
    final response = await http.get(Uri.parse('$baseUrl/settings/mfa'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get MFA device');
  }

  static Future<void> saveMFADevice({
    required String deviceName,
    required String deviceArn,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/settings/mfa'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'device_name': deviceName,
        'device_arn': deviceArn,
      }),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to save MFA device');
    }
  }

  static Future<void> deleteMFADevice() async {
    final response = await http.delete(Uri.parse('$baseUrl/settings/mfa'));
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete MFA device');
    }
  }

  static Future<void> deleteIAMUser(String username, {bool force = false}) async {
    final url = force 
        ? '$baseUrl/iam/users/$username?force=true'
        : '$baseUrl/iam/users/$username';
    final response = await http.delete(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to delete user');
    }
  }

  static Future<List<dynamic>> checkMultipleUserDependencies(List<String> usernames) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/batch/dependencies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'usernames': usernames}),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['dependencies'] ?? [];
    }
    throw Exception('Failed to check dependencies');
  }

  static Future<Map<String, dynamic>> deleteMultipleIAMUsers(List<Map<String, dynamic>> users) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/users/batch/delete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'users': users}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete users');
    }
  }

  // IAM Policies
  static Future<List<dynamic>> listIAMPolicies({String scope = 'All'}) async {
    final uri = Uri.parse('$baseUrl/iam/policies').replace(
      queryParameters: {'scope': scope},
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['policies'] ?? [];
    }
    throw Exception('Failed to load policies');
  }

  // IAM Groups
  static Future<List<dynamic>> listIAMGroups() async {
    final response = await http.get(Uri.parse('$baseUrl/iam/groups'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['groups'] ?? [];
    }
    throw Exception('Failed to load groups');
  }

  static Future<void> createIAMGroup(String groupname) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/groups'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'groupname': groupname}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create group');
    }
  }

  static Future<Map<String, dynamic>> checkGroupDependencies(String groupname) async {
    final response = await http.get(
      Uri.parse('$baseUrl/iam/groups/$groupname/dependencies'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to check group dependencies');
  }

  static Future<void> deleteIAMGroup(String groupname, {bool force = false}) async {
    final uri = Uri.parse('$baseUrl/iam/groups/$groupname${force ? '?force=true' : ''}');
    final response = await http.delete(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete group');
    }
  }

  static Future<void> addUserToGroup(String groupname, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/groups/$groupname/users'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add user to group');
    }
  }

  static Future<List<dynamic>> listGroupPolicies(String groupname) async {
    final response = await http.get(
      Uri.parse('$baseUrl/iam/groups/$groupname/policies'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['policies'] ?? [];
    }
    throw Exception('Failed to list group policies');
  }

  static Future<void> attachGroupPolicy(String groupname, String policyArn) async {
    final response = await http.post(
      Uri.parse('$baseUrl/iam/groups/$groupname/policies'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'policy_arn': policyArn}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to attach policy to group');
    }
  }

  static Future<void> detachGroupPolicy(String groupname, String policyArn) async {
    final encodedArn = Uri.encodeComponent(policyArn);
    final response = await http.delete(
      Uri.parse('$baseUrl/iam/groups/$groupname/policies/$encodedArn'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to detach policy from group');
    }
  }

  // S3 Buckets
  static Future<String> listS3Buckets() async {
    final response = await http.get(Uri.parse('$baseUrl/s3/buckets'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['buckets'] ?? '';
    }
    throw Exception('Failed to load buckets');
  }

  static Future<void> createS3Bucket(String bucketname) async {
    final response = await http.post(
      Uri.parse('$baseUrl/s3/buckets'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'bucketname': bucketname}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create bucket');
    }
  }

  static Future<void> deleteS3Bucket(String bucketname) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/s3/buckets/$bucketname'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete bucket');
    }
  }

  static Future<String> listS3Objects(String bucketname) async {
    final response = await http.get(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/objects'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['objects'] ?? '';
    }
    throw Exception('Failed to load objects');
  }

  static Future<Map<String, dynamic>> getBucketVersioning(String bucketname) async {
    final response = await http.get(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/versioning'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get versioning status');
  }

  static Future<void> setBucketVersioning(String bucketname, String status) async {
    final response = await http.put(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/versioning'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update versioning');
    }
  }

  static Future<Map<String, dynamic>> getBucketMFADelete(String bucketname) async {
    final response = await http.get(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/mfa-delete'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get MFA delete status');
  }

  static Future<void> updateBucketMFADelete(
    String bucketname,
    String status,
    String mfaToken,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/mfa-delete'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'status': status,
        'mfa_token': mfaToken,
      }),
    );
    
    if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update MFA delete');
    }
  }

  static Future<List<int>> downloadS3Object(
    String bucketname,
    String objectkey, {
    Function(int received, int total)? onProgress,
  }) async {
    final request = http.Request(
      'GET',
      Uri.parse('$baseUrl/s3/buckets/$bucketname/objects/$objectkey'),
    );

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to download object');
    }

    final contentLength = response.contentLength ?? 0;
    final bytes = <int>[];
    int received = 0;

    await for (var chunk in response.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received, contentLength);
    }

    return bytes;
  }

  static Future<List<S3Item>> listS3ItemsWithPrefix(String bucketname, String prefix) async {
    final uri = Uri.parse('$baseUrl/s3/buckets/$bucketname/items').replace(
      queryParameters: {'prefix': prefix},
    );
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'];
      if (items == null) {
        return [];
      }
      return (items as List).map((item) => S3Item.fromJson(item)).toList();
    }
    throw Exception('Failed to load items');
  }

  static Future<void> uploadS3Object(String bucketname, String key, dynamic file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/s3/buckets/$bucketname/upload'),
    );
    request.fields['key'] = key;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Failed to upload file');
    }
  }

  static Future<void> deleteS3Object(String bucketname, String objectkey) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/objects/$objectkey'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete object');
    }
  }

  static Future<void> createS3Folder(String bucketname, String folderPath) async {
    final response = await http.post(
      Uri.parse('$baseUrl/s3/buckets/$bucketname/folder'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'folder_path': folderPath}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to create folder');
    }
  }

  // AWS Configuration
  static Future<Map<String, dynamic>> getAWSConfig() async {
    final response = await http.get(Uri.parse('$baseUrl/aws/config'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to get AWS config');
  }

  static Future<void> configureAWS(String accessKeyId, String secretAccessKey, String region) async {
    final response = await http.post(
      Uri.parse('$baseUrl/aws/config'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'access_key_id': accessKeyId,
        'secret_access_key': secretAccessKey,
        'region': region,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to configure AWS: ${response.body}');
    }
  }
}
