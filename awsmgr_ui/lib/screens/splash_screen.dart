import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/aws_credentials_service.dart';
import '../services/backend_service.dart';
import '../screens/home_screen.dart';
import '../screens/credentials_setup_screen.dart';
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
      bool hasCredentials = false;

      if (widget.isReload) {
        // Reload scenario: use provided credentials
        setState(
          () => _status = 'The cloud is just someone else\'s computer...',
        );
        await Future.delayed(const Duration(milliseconds: 500));

        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 500));

        if (widget.accessKey != null &&
            widget.secretKey != null &&
            widget.region != null) {
          await BackendService.setAWSCredentials(
            widget.accessKey!,
            widget.secretKey!,
            widget.region!,
          );
        }
        hasCredentials = true;
      } else {
        // Initial load scenario
        setState(() => _status = 'Checking credentials...');
        await Future.delayed(const Duration(milliseconds: 500));

        hasCredentials = await AWSCredentialsService.hasCredentials();

        // Start backend
        setState(() => _status = 'Waking up the backend...');
        await BackendService.start();

        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 500));

        final isRunning = await BackendService.isRunning();

        if (!isRunning) {
          throw Exception('Backend health check failed');
        }

        debugPrint('✓ Backend loaded successfully');

        // Load and set AWS credentials if available
        if (hasCredentials) {
          setState(() => _status = 'Configuring AWS services...');
          final creds = await AWSCredentialsService.getCredentials();

          if (creds['accessKey'] != null &&
              creds['secretKey'] != null &&
              creds['region'] != null) {
            await BackendService.setAWSCredentials(
              creds['accessKey']!,
              creds['secretKey']!,
              creds['region']!,
            );
          }
        }
      }

      setState(() => _status = 'All systems go!');
      await Future.delayed(const Duration(milliseconds: 500));

      // Prefetch user info if we have credentials
      if (hasCredentials) {
        setState(() => _status = 'Your data is floating somewhere nice...');
        try {
          await ApiService.getCallerIdentity();
        } catch (e) {
          debugPrint('Failed to prefetch user info: $e');
        }
      }

      // Navigate to appropriate screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => hasCredentials
                ? const SecurityWrapper(child: HomeScreen())
                : const CredentialsSetupScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Backend initialization failed: $e');
      setState(() {
        _status = 'Failed to start backend';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.backgroundDark,
                    AppTheme.purple900.withValues(alpha: 0.3),
                  ]
                : [
                    AppTheme.primaryPurple.withValues(alpha: 0.1),
                    AppTheme.purple600.withValues(alpha: 0.2),
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with glow
              TweenAnimationBuilder(
                duration: const Duration(seconds: 2),
                tween: Tween<double>(begin: 0.8, end: 1.0),
                curve: Curves.easeInOut,
                builder: (context, double scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryPurple, AppTheme.purple600],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_rounded,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),

              // App Name
              Text(
                'AethrOps',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),

              // Tagline
              Text(
                'Manage your AWS Infrastructure Anytime, Anywhere',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 60),

              // Loading indicator or error
              if (!_hasError)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryPurple,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.errorRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                ),

              const SizedBox(height: 24),

              // Status message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 15,
                    color: _hasError
                        ? AppTheme.errorRed
                        : (isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Retry button if error
              if (_hasError) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _status = 'Retrying...';
                    });
                    _initialize();
                  },
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
