import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// FFI function signatures
typedef StartBackendNative = Int32 Function();
typedef StartBackendDart = int Function();

typedef StopBackendNative = Int32 Function();
typedef StopBackendDart = int Function();

typedef SetDataDirectoryNative = Int32 Function(Pointer<Utf8>);
typedef SetDataDirectoryDart = int Function(Pointer<Utf8>);

typedef SetAWSCredentialsNative =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef SetAWSCredentialsDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

class BackendService {
  static Process? _process;
  static DynamicLibrary? _lib;
  static const String baseUrl = 'http://127.0.0.1:9480';

  static Future<void> start() async {
    try {
      // Check if backend is already running
      if (await isRunning()) {
        return;
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await _startMobile();
      } else {
        await _startDesktop();
      }

      // Wait for backend to be ready
      await _waitForBackend();
    } catch (e) {
      debugPrint('Failed to start backend: $e');
      rethrow;
    }
  }

  static Future<void> _startMobile() async {
    try {
      // Load the native library
      if (Platform.isAndroid) {
        _lib = DynamicLibrary.open('libbackend.so');
      } else if (Platform.isIOS) {
        _lib = DynamicLibrary.process();
      }

      if (_lib == null) {
        throw Exception('Failed to load native library');
      }

      // Get app data directory
      final appDir = await getApplicationDocumentsDirectory();

      // Set data directory
      final setDataDir = _lib!
          .lookupFunction<SetDataDirectoryNative, SetDataDirectoryDart>(
            'SetDataDirectory',
          );
      
      final dirPtr = appDir.path.toNativeUtf8();
      final setDirResult = setDataDir(dirPtr);
      calloc.free(dirPtr);

      // Start backend
      final startBackend = _lib!
          .lookupFunction<StartBackendNative, StartBackendDart>('StartBackend');
      
      final result = startBackend();

      if (result != 0) {
        throw Exception('Backend failed to start (code: $result)');
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _startMobile: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<void> _startDesktop() async {
    final backend = _getBackendPath();

    // Start backend process
    _process = await Process.start(
      backend,
      [],
      workingDirectory: _getBackendDir(),
    );

    // Listen to output
    _process!.stdout.listen((data) {
      debugPrint('Backend: ${String.fromCharCodes(data)}');
    });

    _process!.stderr.listen((data) {
      debugPrint('Backend Error: ${String.fromCharCodes(data)}');
    });
  }

  static String _getBackendPath() {
    // Get the executable directory
    final exePath = Platform.resolvedExecutable;
    final exeDir = exePath.substring(
      0,
      exePath.lastIndexOf(Platform.pathSeparator),
    );

    if (Platform.isWindows) {
      return '$exeDir${Platform.pathSeparator}awsmgr_backend.exe';
    } else if (Platform.isMacOS) {
      return '$exeDir${Platform.pathSeparator}awsmgr_backend_macos';
    } else {
      return '$exeDir${Platform.pathSeparator}awsmgr_backend';
    }
  }

  static String _getBackendDir() {
    final exePath = Platform.resolvedExecutable;
    return exePath.substring(0, exePath.lastIndexOf(Platform.pathSeparator));
  }

  static Future<bool> isRunning() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> _waitForBackend() async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (await isRunning()) {
        return;
      }
    }
    throw Exception('Backend failed to start within 15 seconds');
  }

  static Future<bool> setAWSCredentials(
    String accessKey,
    String secretKey,
    String region,
  ) async {
    // Try FFI first (for mobile)
    if (_lib != null) {
      try {
        final setCredentials = _lib!
            .lookupFunction<SetAWSCredentialsNative, SetAWSCredentialsDart>(
              'SetAWSCredentials',
            );

        final accessKeyPtr = accessKey.toNativeUtf8();
        final secretKeyPtr = secretKey.toNativeUtf8();
        final regionPtr = region.toNativeUtf8();

        final result = setCredentials(accessKeyPtr, secretKeyPtr, regionPtr);

        calloc.free(accessKeyPtr);
        calloc.free(secretKeyPtr);
        calloc.free(regionPtr);

        return result == 0;
      } catch (e) {
        debugPrint('Error setting credentials via FFI: $e');
        return false;
      }
    }

    // Use HTTP API for desktop
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/aws/config'),
        headers: {'Content-Type': 'application/json'},
        body:
            '{"access_key_id":"$accessKey","secret_access_key":"$secretKey","region":"$region"}',
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error configuring credentials via API: $e');
      return false;
    }
  }

  static void stop() {
    if (_lib != null) {
      try {
        final stopBackend = _lib!
            .lookupFunction<StopBackendNative, StopBackendDart>('StopBackend');
        stopBackend();
      } catch (e) {
        debugPrint('Error stopping backend: $e');
      }
    }

    _process?.kill();
    _process = null;
  }
}
