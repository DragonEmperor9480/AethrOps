import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';
import '../services/backend_service.dart';
import '../widgets/loading_animation.dart';

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
      // Show shutting down animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimation(
                  message: 'Shutting down...',
                  size: 40,
                  style: LoadingStyle.orbital,
                  showQuote: false,
                ),
                SizedBox(height: 16),
                Text('Shutting down...', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );

      // Give the animation a moment to render
      await Future.delayed(const Duration(milliseconds: 100));

      // Stop the backend before exiting
      BackendService.stop();

      // Small delay to show the animation
      await Future.delayed(const Duration(milliseconds: 500));

      return true;
    }

    return false;
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
