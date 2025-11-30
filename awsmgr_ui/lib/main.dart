import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/backend_service.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/credentials_setup_screen.dart';
import 'services/aws_credentials_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'AWS Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

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
        setState(() => _status = 'The cloud is just someone else\'s computer...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() => _status = 'Establishing secure connection...');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (widget.accessKey != null && widget.secretKey != null && widget.region != null) {
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
                ? const HomeScreen() 
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            if (!_hasError)
              const CircularProgressIndicator()
            else
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppTheme.errorRed,
              ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: TextStyle(
                fontSize: 16,
                color: _hasError ? AppTheme.errorRed : AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_hasError) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _status = 'Retrying...';
                  });
                  _initialize();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
