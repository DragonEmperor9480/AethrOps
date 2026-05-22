import 'package:flutter/material.dart';
import 'dart:async';
import '../services/security_service.dart';
import '../screens/pin_lock_screen.dart';

/// Wrapper widget that checks for PIN security on app startup
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper>
    with WidgetsBindingObserver {
  bool _isUnlocked = false;
  bool _isChecking = true;
  bool _hasCompletedInitialAuth = false;
  DateTime? _lastPausedTime;
  static const _lockTimeout = Duration(
    minutes: 5,
  ); // Lock after 5 minutes of inactivity

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Record when app was paused
      if (_isUnlocked && _hasCompletedInitialAuth) {
        _lastPausedTime = DateTime.now();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Check if enough time has passed to lock the app
      if (_isUnlocked && _hasCompletedInitialAuth && _lastPausedTime != null) {
        final timeSincePause = DateTime.now().difference(_lastPausedTime!);
        if (timeSincePause > _lockTimeout) {
          // Lock the app if timeout exceeded
          setState(() => _isUnlocked = false);
          _checkSecurity();
        }
      }
    }
  }

  Future<void> _checkSecurity() async {
    setState(() => _isChecking = true);

    final securityEnabled = await SecurityService.isSecurityEnabled();

    if (!securityEnabled) {
      setState(() {
        _isUnlocked = true;
        _isChecking = false;
        _hasCompletedInitialAuth = true;
      });
      return;
    }

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
        _hasCompletedInitialAuth = true;
      });
    } else {
      if (mounted) {
        _showPinScreen();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isUnlocked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return widget.child;
  }
}
