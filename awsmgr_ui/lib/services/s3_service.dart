import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'backend_service.dart';

class S3Service {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: '${BackendService.baseUrl}/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 10),
      // Optimize for large file transfers
      receiveDataWhenStatusError: false,
      validateStatus: (status) => status != null && status < 500,
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

  /// Get secure presigned download URL for an S3 object
  static Future<String> getPresignedDownloadUrl(
    String bucketName,
    String objectKey, {
    bool download = false,
  }) async {
    try {
      final urlResponse = await _dio.get(
        '/s3/buckets/$bucketName/objects/$objectKey',
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
        throw Exception('Failed to get presigned download URL');
      }

      return presignedUrl;
    } catch (e) {
      throw Exception('Failed to fetch presigned URL: $e');
    }
  }

  /// Download S3 object with progress tracking
  static Future<List<int>> downloadWithProgress(
    String bucketName,
    String objectKey,
    Function(int received, int total) onProgress,
  ) async {
    try {
      // 1. Get presigned GET URL
      final presignedUrl = await getPresignedDownloadUrl(bucketName, objectKey);

      debugPrint('Downloading directly from S3 to temporary file: $presignedUrl');

      // 2. Create a temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/s3_download_${DateTime.now().millisecondsSinceEpoch}.tmp');

      int lastUpdate = 0;
      double lastProgress = 0.0;

      // 3. Download directly from S3 using the persistent _s3Dio client
      await _s3Dio.download(
        presignedUrl,
        tempFile.path,
        options: Options(
          // Disable compression for binary data
          headers: {'Accept-Encoding': 'identity'},
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            final now = DateTime.now().millisecondsSinceEpoch;

            // Throttle UI stream updates to prevent event loop saturation (at most once every 100ms or 2% progress)
            if (received == total ||
                (now - lastUpdate) > 100 ||
                (progress - lastProgress).abs() > 0.02) {
              lastUpdate = now;
              lastProgress = progress;
              onProgress(received, total);
            }
          }
        },
      );

      // 4. Read bytes from temporary file
      final bytes = await tempFile.readAsBytes();

      // 5. Clean up temporary file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      debugPrint('Download complete: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      debugPrint('Download error: $e');
      throw Exception('Download failed: $e');
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
        '/s3/buckets/$bucketName/upload',
        data: {'key': objectKey},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      String? presignedUrl;
      if (response.data is Map) {
        presignedUrl = response.data['url'] as String?;
      } else if (response.data is String) {
        final data = json.decode(response.data as String);
        presignedUrl = data['url'] as String?;
      }

      if (presignedUrl == null) {
        throw Exception('Failed to get presigned upload URL');
      }

      debugPrint('Uploading directly to S3: $presignedUrl');

      int lastUpdate = 0;
      double lastProgress = 0.0;

      // 2. Direct PUT upload to S3 using the persistent _s3Dio client
      await _s3Dio.put(
        presignedUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            Headers.contentLengthHeader: fileSize,
          },
        ),
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
