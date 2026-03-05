import 'package:flutter/material.dart';
import '../services/security_service.dart';
import '../screens/pin_lock_screen.dart';

/// Wrapper widget that checks for PIN security on app startup
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isChecking = true;
  bool _hasCompletedInitialAuth = false; // Track if user has authenticated once

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSecurity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only lock app when going to background if user has completed initial authentication
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isUnlocked && _hasCompletedInitialAuth) {
        setState(() => _isUnlocked = false);
      }
    }
    // Re-check security when app comes back to foreground (only if already authenticated once)
    else if (state == AppLifecycleState.resumed) {
      if (!_isUnlocked && _hasCompletedInitialAuth) {
        _checkSecurity();
      }
    }
  }

  Future<void> _checkSecurity() async {
    setState(() => _isChecking = true);
    
    final securityEnabled = await SecurityService.isSecurityEnabled();
    
    if (!securityEnabled) {
      // No security enabled, allow access
      setState(() {
        _isUnlocked = true;
        _isChecking = false;
        _hasCompletedInitialAuth = true;
      });
      return;
    }

    // Security enabled, show PIN screen
    setState(() => _isChecking = false);
    
    if (mounted) {
      _showPinScreen();
    }
  }

  Future<void> _showPinScreen() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const PinLockScreen(isSetup: false),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      setState(() {
        _isUnlocked = true;
        _hasCompletedInitialAuth = true; // Mark as authenticated
      });
    } else {
      // User cancelled or failed - show again
      if (mounted) {
        _showPinScreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isUnlocked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return widget.child;
  }
}
