import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/s3_item.dart';
import 'backend_service.dart';

class ApiService {
  static String get baseUrl => '${BackendService.baseUrl}/api';
  static const _timeout = Duration(seconds: 30);

  /// Percent-encodes a value used as a single URL path segment (IAM names,
  /// bucket names, S3 keys). S3 keys may contain `/`, `?`, `#`, `%` or spaces.
  static String _seg(String value) => Uri.encodeComponent(value);

  /// Human-readable error from a failed backend response. Understands both
  /// the old `{"error": ...}` and the envelope `{"message": ...}` formats and
  /// falls back when the body is empty or not JSON.
  static String errorMessage(http.Response response, String fallback) {
    try {
      final body = json.decode(response.body);
      if (body is Map) {
        final message = body['error'] ?? body['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Not JSON (e.g. empty 405 body); use the fallback
    }
    return fallback;
  }

  /// Payload of an endpoint using the backend's response envelope
  /// (`{"status", "message", "data"}`). Empty when `data` is absent.
  static Map<String, dynamic> _envelopeData(http.Response response) {
    final body = json.decode(response.body);
    final data = body is Map<String, dynamic> ? body['data'] : null;
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // IAM Caller Identity
  static Future<Map<String, dynamic>> getCallerIdentity() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/caller-identity'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return _envelopeData(response);
    }
    throw Exception(errorMessage(response, 'Failed to get caller identity'));
  }

  // IAM Users
  static Future<List<dynamic>> listIAMUsers() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/users'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return _envelopeData(response)['users'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to load users'));
  }

  static Future<Map<String, dynamic>> createMultipleIAMUsers(
    List<Map<String, dynamic>> users,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/batch'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'users': users}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(errorMessage(response, 'Failed to create users'));
    }
  }

  static Future<void> createIAMUser(
    String username, {
    String? password,
    bool requireReset = false,
  }) async {
    final body = <String, dynamic>{'username': username};

    if (password != null && password.isNotEmpty) {
      body['password'] = password;
      body['require_reset'] = requireReset;
    }

    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to create user'));
    }
  }

  static Future<Map<String, dynamic>> checkUserDependencies(
    String username,
  ) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/users/${_seg(username)}/dependencies'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to check dependencies'));
  }

  static Future<List<dynamic>> getUserGroups(String username) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/users/${_seg(username)}/groups'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return _envelopeData(response)['groups'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to get user groups'));
  }

  static Future<void> attachUserPolicy(
    String username,
    String policyArn,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/${_seg(username)}/policies'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'policy_arn': policyArn}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to attach policy'));
    }
  }

  static Future<Map<String, dynamic>> attachMultipleUserPolicies(
    List<Map<String, String>> attachments,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/policies/batch'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'attachments': attachments}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(errorMessage(response, 'Failed to attach policies'));
    }
  }

  static Future<Map<String, dynamic>> syncUserPolicies(
    String username,
    List<String> desiredArns,
    List<String> currentArns,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/${_seg(username)}/policies/sync'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'desired_arns': desiredArns,
            'current_arns': currentArns,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(errorMessage(response, 'Failed to sync policies'));
    }
  }

  static Future<void> sendUserCredentialsEmail({
    required String username,
    required String password,
    required String email,
  }) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/send-credentials'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'username': username,
            'password': password,
            'email': email,
            // console_url and email_config are now automatically handled by the backend
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        errorMessage(response, 'Failed to send credentials email'),
      );
    }
  }

  // Email Configuration
  static Future<Map<String, dynamic>> getEmailConfig() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/email/config'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get email config'));
  }

  static Future<void> saveEmailConfig({
    required String smtpHost,
    required int smtpPort,
    required String senderEmail,
    required String senderPass,
    required String senderName,
  }) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/email/config'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'smtp_host': smtpHost,
            'smtp_port': smtpPort,
            'sender_email': senderEmail,
            'sender_pass': senderPass,
            'sender_name': senderName,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to save email config'));
    }
  }

  static Future<void> sendTestEmail({
    required String smtpHost,
    required int smtpPort,
    required String senderEmail,
    required String senderPass,
  }) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/email/test'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'smtp_host': smtpHost,
            'smtp_port': smtpPort,
            'sender_email': senderEmail,
            'sender_pass': senderPass,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to send test email'));
    }
  }

  static Future<void> deleteEmailConfig() async {
    final response = await BackendService.client
        .delete(Uri.parse('$baseUrl/email/config'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete email config'));
    }
  }

  // MFA Device Configuration
  static Future<Map<String, dynamic>> getMFADevice() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/settings/mfa'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get MFA device'));
  }

  static Future<void> saveMFADevice({
    required String deviceName,
    required String deviceArn,
  }) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/settings/mfa'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'device_name': deviceName,
            'device_arn': deviceArn,
          }),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to save MFA device'));
    }
  }

  static Future<void> deleteMFADevice() async {
    final response = await BackendService.client
        .delete(Uri.parse('$baseUrl/settings/mfa'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete MFA device'));
    }
  }

  static Future<void> deleteIAMUser(
    String username, {
    bool force = false,
  }) async {
    final url = force
        ? '$baseUrl/iam/users/${_seg(username)}?force=true'
        : '$baseUrl/iam/users/${_seg(username)}';
    final response = await BackendService.client
        .delete(Uri.parse(url))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete user'));
    }
  }

  static Future<List<dynamic>> checkMultipleUserDependencies(
    List<String> usernames,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/batch/dependencies'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'usernames': usernames}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['dependencies'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to check dependencies'));
  }

  static Future<Map<String, dynamic>> deleteMultipleIAMUsers(
    List<Map<String, dynamic>> users,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/users/batch/delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'users': users}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(errorMessage(response, 'Failed to delete users'));
    }
  }

  // IAM Policies
  static Future<List<dynamic>> listIAMPolicies({String scope = 'All'}) async {
    final uri = Uri.parse(
      '$baseUrl/iam/policies',
    ).replace(queryParameters: {'scope': scope});
    final response = await BackendService.client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['policies'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to load policies'));
  }

  // IAM Groups
  static Future<List<dynamic>> listIAMGroups() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/groups'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return _envelopeData(response)['groups'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to load groups'));
  }

  static Future<void> createIAMGroup(String groupname) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/groups'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'groupname': groupname}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to create group'));
    }
  }

  static Future<Map<String, dynamic>> checkGroupDependencies(
    String groupname,
  ) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/groups/${_seg(groupname)}/dependencies'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return _envelopeData(response);
    }
    throw Exception(
      errorMessage(response, 'Failed to check group dependencies'),
    );
  }

  static Future<void> deleteIAMGroup(
    String groupname, {
    bool force = false,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/iam/groups/${_seg(groupname)}${force ? '?force=true' : ''}',
    );
    final response = await BackendService.client.delete(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete group'));
    }
  }

  static Future<void> addUserToGroup(String groupname, String username) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/groups/${_seg(groupname)}/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to add user to group'));
    }
  }

  static Future<List<dynamic>> listGroupPolicies(String groupname) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/iam/groups/${_seg(groupname)}/policies'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['policies'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to list group policies'));
  }

  static Future<void> attachGroupPolicy(
    String groupname,
    String policyArn,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/iam/groups/${_seg(groupname)}/policies'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'policy_arn': policyArn}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(
        errorMessage(response, 'Failed to attach policy to group'),
      );
    }
  }

  static Future<void> detachGroupPolicy(
    String groupname,
    String policyArn,
  ) async {
    final encodedArn = Uri.encodeComponent(policyArn);
    final response = await BackendService.client
        .delete(
          Uri.parse(
            '$baseUrl/iam/groups/${_seg(groupname)}/policies/$encodedArn',
          ),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(
        errorMessage(response, 'Failed to detach policy from group'),
      );
    }
  }

  // S3 Buckets
  static Future<String> listS3Buckets() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/s3/buckets'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['buckets'] ?? '';
    }
    throw Exception(errorMessage(response, 'Failed to load buckets'));
  }

  static Future<void> createS3Bucket(String bucketname) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/s3/buckets'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'bucketname': bucketname}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to create bucket'));
    }
  }

  static Future<void> deleteS3Bucket(String bucketname) async {
    final response = await BackendService.client
        .delete(Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete bucket'));
    }
  }

  static Future<Map<String, dynamic>> getBucketVersioning(
    String bucketname,
  ) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}/versioning'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get versioning status'));
  }

  static Future<void> setBucketVersioning(
    String bucketname,
    String status,
  ) async {
    final response = await BackendService.client
        .put(
          Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}/versioning'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': status}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to update versioning'));
    }
  }

  static Future<Map<String, dynamic>> getBucketMFADelete(
    String bucketname,
  ) async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}/mfa-delete'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get MFA delete status'));
  }

  static Future<void> updateBucketMFADelete(
    String bucketname,
    String status,
    String mfaToken,
  ) async {
    final response = await BackendService.client
        .put(
          Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}/mfa-delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': status, 'mfa_token': mfaToken}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to update MFA delete'));
    }
  }

  static Future<List<S3Item>> listS3ItemsWithPrefix(
    String bucketname,
    String prefix,
  ) async {
    final uri = Uri.parse(
      '$baseUrl/s3/buckets/${_seg(bucketname)}/items',
    ).replace(queryParameters: {'prefix': prefix});
    final response = await BackendService.client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final items = data['items'];
      if (items == null) {
        return [];
      }
      return (items as List).map((item) => S3Item.fromJson(item)).toList();
    }
    throw Exception(errorMessage(response, 'Failed to load items'));
  }

  static Future<void> deleteS3Object(
    String bucketname,
    String objectkey,
  ) async {
    final response = await BackendService.client
        .delete(
          Uri.parse(
            '$baseUrl/s3/buckets/${_seg(bucketname)}/objects/${_seg(objectkey)}',
          ),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to delete object'));
    }
  }

  static Future<void> createS3Folder(
    String bucketname,
    String folderPath,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/s3/buckets/${_seg(bucketname)}/folder'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'folder_path': folderPath}),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to create folder'));
    }
  }

  // EC2 Instances
  static Future<List<dynamic>> listEC2Instances({String? region}) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances');

    final response = await BackendService.client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['instances'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to load EC2 instances'));
  }

  static Future<List<dynamic>> listEC2InstancesAllRegions() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/ec2/instances/all-regions'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['instances'] ?? [];
    }
    throw Exception(
      errorMessage(response, 'Failed to load EC2 instances from all regions'),
    );
  }

  static Future<Map<String, dynamic>> getEC2Dashboard() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/ec2/dashboard'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to load EC2 dashboard'));
  }

  // REMOVED: listAWSRegions, listAMIs, listSecurityGroups, listKeyPairs, listSubnets, listVPCs
  // These duplicate Ec2Service methods. Use Ec2Service instead.

  static Future<Map<String, dynamic>> getEC2Instance(
    String instanceId, {
    String? region,
  }) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances/$instanceId',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances/$instanceId');

    final response = await BackendService.client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get instance details'));
  }

  static Future<void> startEC2Instance(
    String instanceId, {
    String? region,
  }) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances/$instanceId/start',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances/$instanceId/start');

    final response = await BackendService.client.post(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to start instance'));
    }
  }

  static Future<void> stopEC2Instance(
    String instanceId, {
    String? region,
  }) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances/$instanceId/stop',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances/$instanceId/stop');

    final response = await BackendService.client.post(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to stop instance'));
    }
  }

  static Future<void> rebootEC2Instance(
    String instanceId, {
    String? region,
  }) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances/$instanceId/reboot',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances/$instanceId/reboot');

    final response = await BackendService.client.post(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to reboot instance'));
    }
  }

  static Future<void> terminateEC2Instance(
    String instanceId, {
    String? region,
  }) async {
    final uri = region != null
        ? Uri.parse(
            '$baseUrl/ec2/instances/$instanceId/terminate',
          ).replace(queryParameters: {'region': region})
        : Uri.parse('$baseUrl/ec2/instances/$instanceId/terminate');

    final response = await BackendService.client.delete(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to terminate instance'));
    }
  }

  static Future<List<dynamic>> getEC2InstancesByState(
    String state, {
    String? region,
  }) async {
    final queryParams = {'state': state};
    if (region != null) {
      queryParams['region'] = region;
    }

    final uri = Uri.parse(
      '$baseUrl/ec2/instances/by-state',
    ).replace(queryParameters: queryParams);
    final response = await BackendService.client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['instances'] ?? [];
    }
    throw Exception(errorMessage(response, 'Failed to get instances by state'));
  }

  // AWS Configuration
  static Future<Map<String, dynamic>> getAWSConfig() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/aws/config'))
        .timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(errorMessage(response, 'Failed to get AWS config'));
  }

  static Future<void> configureAWS(
    String accessKeyId,
    String secretAccessKey,
    String region,
  ) async {
    final response = await BackendService.client
        .post(
          Uri.parse('$baseUrl/aws/config'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'access_key_id': accessKeyId,
            'secret_access_key': secretAccessKey,
            'region': region,
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception(errorMessage(response, 'Failed to configure AWS'));
    }
  }

  // ==================== CloudWatch APIs ====================

  // List all Lambda functions
  static Future<List<String>> listLambdaFunctions() async {
    final response = await BackendService.client
        .get(Uri.parse('$baseUrl/cloudwatch/lambda/functions'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['functions'] ?? []);
    }
    throw Exception(errorMessage(response, 'Failed to load Lambda functions'));
  }

  // Download logs for a session
  static Future<String> downloadLogs(String sessionId) async {
    final url = '$baseUrl/cloudwatch/logs/download/$sessionId';

    final response = await BackendService.client
        .get(Uri.parse(url))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return response.body; // Return the log file content
    }
    throw Exception(
      errorMessage(
        response,
        'Failed to download logs (${response.statusCode})',
      ),
    );
  }
}
