import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for handling file downloads with proper permissions and MediaStore integration
class DownloadService {
  static const _mediaScanner = MethodChannel('com.amrut.aethrops/media_scanner');

  /// Request storage permissions on Android
  /// Returns true if permission is granted, false otherwise
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // No permission needed on other platforms
    }

    print('Checking Android storage permissions...');

    // Try manageExternalStorage first (for Android 11+)
    PermissionStatus status = await Permission.manageExternalStorage.status;
    print('manageExternalStorage status: $status');

    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      print('manageExternalStorage after request: $status');

      if (!status.isGranted) {
        // Fallback to regular storage permission for older Android versions
        status = await Permission.storage.status;
        print('storage status: $status');

        if (!status.isGranted) {
          status = await Permission.storage.request();
          print('storage after request: $status');
        }

        if (!status.isGranted) {
          print('Storage permission denied');
          return false;
        }
      }
    }

    print('Storage permission granted');
    return true;
  }

  /// Save bytes to Downloads folder and make it visible in file manager
  /// Returns a map with 'success', 'path', and 'displayPath' keys
  static Future<Map<String, dynamic>> saveToDownloads({
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      String filePath;
      String displayPath;

      if (Platform.isAndroid) {
        // Save to public Downloads directory
        const publicDownloadsPath = '/storage/emulated/0/Download';
        filePath = '$publicDownloadsPath/$fileName';
        displayPath = 'Downloads/$fileName';
        print('Attempting to save to: $filePath');

        try {
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          print('Successfully saved to public Downloads');

          // Scan the file to make it visible in gallery/file manager
          await _scanFile(filePath);

          return {
            'success': true,
            'path': filePath,
            'displayPath': displayPath,
          };
        } catch (e) {
          print('Failed to save to public Downloads: $e');
          // Fallback to app storage
          final directory = await getExternalStorageDirectory();
          if (directory == null) {
            throw Exception('Could not access storage');
          }
          filePath = '${directory.path}/$fileName';
          displayPath = 'App storage/$fileName (not visible in file manager)';
          print('Saving to app storage instead: $filePath');

          final file = File(filePath);
          await file.writeAsBytes(bytes);

          return {
            'success': true,
            'path': filePath,
            'displayPath': displayPath,
          };
        }
      } else {
        // For other platforms (Linux, Windows, macOS)
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads folder');
        }
        filePath = '${directory.path}/$fileName';
        displayPath = fileName;
        print('Saving to: $filePath');

        final file = File(filePath);
        await file.writeAsBytes(bytes);

        return {
          'success': true,
          'path': filePath,
          'displayPath': displayPath,
        };
      }
    } catch (e) {
      print('Error saving file: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Scan file to make it visible in Android's MediaStore
  static Future<void> _scanFile(String filePath) async {
    if (Platform.isAndroid) {
      try {
        print('Scanning file for MediaStore: $filePath');
        await _mediaScanner.invokeMethod('scanFile', {'path': filePath});
        print('File scanned successfully');
      } catch (e) {
        print('Failed to scan file: $e');
        // Not critical, file is still saved
      }
    }
  }

  /// Get error message for permission denial
  static String getPermissionDeniedMessage() {
    return 'Storage permission required. Please grant "All files access" in:\n'
        'Settings > Apps > AethrOps > Permissions';
  }
}
