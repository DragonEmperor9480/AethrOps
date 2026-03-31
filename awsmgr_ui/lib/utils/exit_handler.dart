import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
        content: const Text('Are you sure you want to exit?'),
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
      // Send shutdown request to backend
      try {
        await http
            .post(Uri.parse('${BackendService.baseUrl}/api/shutdown'))
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {
        // Ignore errors - backend might already be down
      }

      // Exit immediately
      await exitApp();
      return true;
    }

    return false;
  }

  /// Handles app exit based on platform
  static Future<void> exitApp() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      exit(0); // Force immediate exit
    } else {
      SystemNavigator.pop();
    }
  }
}
