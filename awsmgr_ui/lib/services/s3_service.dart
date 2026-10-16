import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';

class S3Service {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${BackendService.baseUrl}/api',
      headers: BackendService.authHeaders,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 10),
      // Optimize for large file transfers
      receiveDataWhenStatusError: false,
      // Accept every status so callers can surface the backend's error message
      validateStatus: (status) => status != null,
    ),
  );

  // Dedicated, persistent Dio instance for direct S3 transfers.
  // This keeps TCP/TLS socket connections alive, completely bypassing TLS handshake overhead.
  static final Dio _s3Dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      sendTimeout: const Duration(minutes: 10),
    ),
  );

  /// Error text from a failed backend response (`{"error"}` or `{"message"}`).
  static String _errorMessage(Response response, String fallback) {
    var data = response.data;
    if (data is String) {
      try {
        data = json.decode(data);
      } catch (_) {
        return fallback;
      }
    }
    if (data is Map) {
      final message = data['error'] ?? data['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  /// Get secure presigned download URL for an S3 object
  static Future<String> getPresignedDownloadUrl(
    String bucketName,
    String objectKey, {
    bool download = false,
  }) async {
    try {
      final urlResponse = await _dio.get(
        '/s3/buckets/${Uri.encodeComponent(bucketName)}/objects/${Uri.encodeComponent(objectKey)}',
        queryParameters: download ? {'download': 'true'} : null,
      );

      String? presignedUrl;
      if (urlResponse.data is Map) {
        presignedUrl = urlResponse.data['url'] as String?;
      } else if (urlResponse.data is String) {
        final data = json.decode(urlResponse.data as String);
        presignedUrl = data['url'] as String?;
      }

      if (presignedUrl == null) {
        throw Exception(
          _errorMessage(urlResponse, 'Failed to get presigned download URL'),
        );
      }

      return presignedUrl;
    } catch (e) {
      throw Exception('Failed to fetch presigned URL: $e');
    }
  }

  /// Upload S3 object with progress tracking (direct PUT to S3)
  static Future<void> uploadWithProgress(
    String bucketName,
    String objectKey,
    File file,
    Function(int sent, int total) onProgress,
  ) async {
    try {
      debugPrint('Starting upload: $bucketName/$objectKey');
      final fileSize = await file.length();
      debugPrint('File size: $fileSize bytes');

      // 1. Get presigned PUT URL from backend
      final response = await _dio.post(
        '/s3/buckets/${Uri.encodeComponent(bucketName)}/upload',
        data: {'key': objectKey},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      String? presignedUrl;
      if (response.data is Map) {
        presignedUrl = response.data['url'] as String?;
      } else if (response.data is String) {
        final data = json.decode(response.data as String);
        presignedUrl = data['url'] as String?;
      }

      if (presignedUrl == null) {
        throw Exception(
          _errorMessage(response, 'Failed to get presigned upload URL'),
        );
      }

      debugPrint('Uploading directly to S3: $presignedUrl');

      int lastUpdate = 0;
      double lastProgress = 0.0;

      // 2. Direct PUT upload to S3 using the persistent _s3Dio client
      await _s3Dio.put(
        presignedUrl,
        data: file.openRead(),
        options: Options(headers: {Headers.contentLengthHeader: fileSize}),
        onSendProgress: (sent, total) {
          final actualTotal = total > 0 ? total : fileSize;
          final progress = sent / actualTotal;
          final now = DateTime.now().millisecondsSinceEpoch;

          // Throttle progress events to prevent event loop saturation
          if (sent == actualTotal ||
              (now - lastUpdate) > 100 ||
              (progress - lastProgress).abs() > 0.02) {
            lastUpdate = now;
            lastProgress = progress;
            onProgress(sent, actualTotal);
          }
        },
      );

      debugPrint('Upload complete');
    } catch (e) {
      debugPrint('Upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }
}
