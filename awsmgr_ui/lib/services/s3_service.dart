import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';

class S3Service {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:9480/api',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  /// Download S3 object with progress tracking
  static Future<List<int>> downloadWithProgress(
    String bucketName,
    String objectKey,
    Function(int received, int total) onProgress,
  ) async {
    try {
      print('Starting download: $bucketName/$objectKey');
      
      final response = await _dio.get<List<int>>(
        '/s3/buckets/$bucketName/objects/$objectKey',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 5),
        ),
        onReceiveProgress: (received, total) {
          print('Progress: $received / $total bytes');
          if (total != -1) {
            onProgress(received, total);
          }
        },
      );

      print('Download complete');
      return response.data ?? [];
    } catch (e) {
      print('Download error: $e');
      throw Exception('Download failed: $e');
    }
  }

  /// Upload S3 object with progress tracking (streaming from backend)
  static Future<void> uploadWithProgress(
    String bucketName,
    String objectKey,
    File file,
    Function(int sent, int total) onProgress,
  ) async {
    try {
      print('Starting upload: $bucketName/$objectKey');
      final fileSize = await file.length();
      print('File size: $fileSize bytes');

      final fileName = objectKey.split('/').last;
      final formData = FormData.fromMap({
        'key': objectKey,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
      });

      // Use streaming response to get progress updates from backend
      final response = await _dio.post<ResponseBody>(
        '/s3/buckets/$bucketName/upload',
        data: formData,
        options: Options(
          responseType: ResponseType.stream,
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      // Parse streaming JSON responses
      final stream = response.data!.stream;
      final buffer = StringBuffer();
      
      await for (final chunk in stream) {
        final text = String.fromCharCodes(chunk);
        buffer.write(text);
        
        // Split by newlines to get individual JSON objects
        final lines = buffer.toString().split('\n');
        
        // Process all complete lines
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isNotEmpty) {
            try {
              final data = json.decode(line);
              if (data['progress'] != null && data['total'] != null) {
                final progress = data['progress'] as int;
                final total = data['total'] as int;
                print('Upload progress: $progress / $total');
                onProgress(progress, total);
              }
              if (data['error'] != null) {
                throw Exception(data['error']);
              }
            } catch (e) {
              print('Failed to parse progress: $e');
            }
          }
        }
        
        // Keep the last incomplete line in buffer
        buffer.clear();
        if (lines.isNotEmpty) {
          buffer.write(lines.last);
        }
      }

      print('Upload complete');
    } catch (e) {
      print('Upload error: $e');
      throw Exception('Upload failed: $e');
    }
  }
}
