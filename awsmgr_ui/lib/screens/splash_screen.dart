import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/api_service.dart';
import '../services/aws_profile_service.dart';
import '../services/backend_service.dart';
import '../screens/home_screen.dart';
import '../screens/credentials_setup_screen.dart';
import '../screens/account_selector_screen.dart';
import '../widgets/security_wrapper.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final bool isReload;
  final String? accessKey;
  final String? secretKey;
  final String? region;

  const SplashScreen({
    super.key,
    this.isReload = false,
    this.accessKey,
    this.secretKey,
    this.region,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // 1. Start the Go backend process (if not already running)
      if (!widget.isReload) {
        setState(() => _status = 'Starting local backend...');
        await BackendService.start();

        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 600));

        final isRunning = await BackendService.isRunning();
        if (!isRunning) {
          throw Exception('Backend health check failed');
        }
        debugPrint('✓ Backend loaded successfully');
      }

      // 2. Query auth-status from backend
      setState(() => _status = 'Checking authentication status...');
      final authResult = await AWSProfileService.getAuthStatus();
      final status = authResult['status'] as String;

      setState(() => _status = 'Blasting you off into AethrOps! 🚀');
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        if (status == 'authenticated') {
          // Prefetch user identity for smooth home experience
          setState(() => _status = 'Almost there...');
          try {
            await ApiService.getCallerIdentity();
          } catch (e) {
            debugPrint('Failed to prefetch caller identity: $e');
          }

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const SecurityWrapper(child: HomeScreen()),
              ),
            );
          }
        } else if (status == 'select_account') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const AccountSelectorScreen(),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const CredentialsSetupScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Backend initialization failed: $e');
      setState(() {
        _status = 'Oops! Something went wrong';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // App Name
            Text(
              'AethrOps',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                fontFamily: 'Quantify',
                color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 60),

            // Lottie Animation
            ColorFiltered(
              colorFilter: isDark
                  ? const ColorFilter.matrix([
                      -1, 0, 0, 0, 255, // Invert red
                      0, -1, 0, 0, 255, // Invert green
                      0, 0, -1, 0, 255, // Invert blue
                      0, 0, 0, 1, 0, // Keep alpha
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.multiply,
                    ),
              child: SizedBox(
                height: 250,
                child: Lottie.asset(
                  'assets/animations/Rocket in space.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),

            const SizedBox(height: 60),

            // Status message with fun text
            if (!_hasError)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF666666),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _status,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _status = 'Retrying...';
                      });
                      _initialize();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),

            const Spacer(),

            // Footer tagline
            if (!_hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Text(
                  'Manage your AWS Infrastructure\nAnytime, Anywhere',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF999999),
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
