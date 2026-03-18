import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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

  final List<String> _funMessages = [
    'Waking up the cloud hamsters...',
    'Convincing AWS to let you in...',
    'Downloading the internet...',
    'Spinning up your virtual empire...',
    'Teaching servers to behave...',
    'Bribing the load balancers...',
    'Asking nicely for your data...',
    'Herding cloud cats...',
    'Inflating the cloud balloons...',
    'Summoning the DevOps wizards...',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  String _getRandomMessage() {
    _funMessages.shuffle();
    return _funMessages.first;
  }

  Future<void> _initialize() async {
    try {
      bool hasCredentials = false;

      if (widget.isReload) {
        setState(() => _status = _getRandomMessage());
        await Future.delayed(const Duration(milliseconds: 800));

        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 800));

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
        setState(() => _status = 'Checking credentials...');
        await Future.delayed(const Duration(milliseconds: 600));

        hasCredentials = await AWSCredentialsService.hasCredentials();

        setState(() => _status = _getRandomMessage());
        await BackendService.start();

        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 600));

        final isRunning = await BackendService.isRunning();

        if (!isRunning) {
          throw Exception('Backend health check failed');
        }

        debugPrint('✓ Backend loaded successfully');

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

      setState(() => _status = 'Blasting you off into AethrOps! 🚀');
      await Future.delayed(const Duration(milliseconds: 800));

      if (hasCredentials) {
        setState(() => _status = 'Almost there...');
        try {
          await ApiService.getCallerIdentity();
        } catch (e) {
          debugPrint('Failed to prefetch user info: $e');
        }
      }

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
