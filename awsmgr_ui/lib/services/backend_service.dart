import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'dart:math';
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

typedef SetAuthTokenNative = Int32 Function(Pointer<Utf8>);
typedef SetAuthTokenDart = int Function(Pointer<Utf8>);

typedef SetAWSCredentialsNative =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef SetAWSCredentialsDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

class BackendService {
  static Process? _process;
  static DynamicLibrary? _lib;
  static const String baseUrl = 'http://127.0.0.1:9480';

  // Per-launch secret shared with the backend. The local API is reachable by
  // browsers and other apps on the device, so every request must carry it.
  static final String _authToken = _generateAuthToken();

  static Map<String, String> get authHeaders => {
    'Authorization': 'Bearer $_authToken',
  };

  /// HTTP client for backend calls; adds the auth header to every request.
  static final http.Client client = _BackendAuthClient();

  static String _generateAuthToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

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
      setDataDir(dirPtr);
      calloc.free(dirPtr);

      // Hand the auth token to the backend before it starts serving
      final setAuthToken = _lib!
          .lookupFunction<SetAuthTokenNative, SetAuthTokenDart>('SetAuthToken');

      final tokenPtr = _authToken.toNativeUtf8();
      final tokenResult = setAuthToken(tokenPtr);
      calloc.free(tokenPtr);

      if (tokenResult != 0) {
        throw Exception('Failed to set backend auth token');
      }

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
      environment: {'AETHROPS_AUTH_TOKEN': _authToken},
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
      return '$exeDir${Platform.pathSeparator}aethrops_core.exe';
    } else if (Platform.isMacOS) {
      return '$exeDir${Platform.pathSeparator}aethrops_core_macos';
    } else {
      return '$exeDir${Platform.pathSeparator}aethrops_core';
    }
  }

  static String _getBackendDir() {
    final exePath = Platform.resolvedExecutable;
    return exePath.substring(0, exePath.lastIndexOf(Platform.pathSeparator));
  }

  /// True only when our own backend (one that accepts our token) is up.
  static Future<bool> isRunning() async {
    return await _healthStatus() == 200;
  }

  /// Status code of the health check, or null if nothing is listening.
  static Future<int?> _healthStatus() async {
    try {
      final response = await client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode;
    } catch (e) {
      return null;
    }
  }

  static Future<void> _waitForBackend() async {
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      final status = await _healthStatus();
      if (status == 200) {
        return;
      }
      // Something is listening but rejects our token: another instance owns the port.
      if (status == 401) {
        throw Exception(
          'Port 9480 is in use by another AethrOps instance. Close it and try again.',
        );
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
      final response = await client.post(
        Uri.parse('$baseUrl/api/aws/config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'access_key_id': accessKey,
          'secret_access_key': secretKey,
          'region': region,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error configuring credentials via API: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      // Mobile: Use FFI to stop
      if (_lib != null) {
        final stopBackend = _lib!
            .lookupFunction<StopBackendNative, StopBackendDart>('StopBackend');
        stopBackend();
        return;
      }

      // Desktop: Call graceful shutdown endpoint and wait for process to exit
      if (_process != null) {
        await client
            .post(Uri.parse('$baseUrl/shutdown'))
            .timeout(const Duration(seconds: 1));

        // Wait for process to exit (backend handles its own cleanup)
        await _process!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () => -1,
        );

        _process = null;
      }
    } catch (e) {
      debugPrint('Error stopping backend: $e');
      // Force kill if graceful shutdown fails
      _process?.kill(ProcessSignal.sigkill);
      _process = null;
    }
  }
}

/// Adds the backend auth header to requests aimed at the local backend only,
/// so the token is never sent anywhere else.
class _BackendAuthClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final backendUri = Uri.parse(BackendService.baseUrl);
    if (request.url.host == backendUri.host &&
        request.url.port == backendUri.port) {
      request.headers.addAll(BackendService.authHeaders);
    }
    return _inner.send(request);
  }
}
