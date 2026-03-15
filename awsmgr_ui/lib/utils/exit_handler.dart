import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/backend_service.dart';

/// Shared exit handler for both Windows close button and Android back button
class ExitHandler {
  /// Shows exit confirmation dialog and handles app shutdown
  /// Returns true if the app should exit, false otherwise
  static Future<bool> showExitConfirmation(BuildContext context) async {
    // Show exit confirmation dialog
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppTheme.primaryPurple),
            const SizedBox(width: 12),
            const Text('Exit AethrOps?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to exit? The backend service will be stopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Exit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      // Perform shutdown with animation and exit - don't return, just exit directly
      await _performShutdownAndExit(context);
      // This line won't be reached as app will be closed
      return true;
    }

    return false;
  }

  /// Performs the actual shutdown process and exits immediately
  static Future<void> _performShutdownAndExit(BuildContext context) async {
    // Close the UI FIRST - immediately
    exitApp();

    // Tell backend to shutdown in background (fire and forget)
    unawaited(
      http
          .post(Uri.parse('${BackendService.baseUrl}/api/shutdown'))
          .timeout(const Duration(milliseconds: 500))
          .catchError((_) => http.Response('', 500)),
    );
  }

  /// Handles app exit based on platform
  static Future<void> exitApp() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await windowManager.destroy();
    } else {
      SystemNavigator.pop();
    }
  }
}
