import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/aws_credentials_service.dart';
import '../theme/app_theme.dart';
import '../widgets/credentials_tutorial_dialog.dart';
import '../widgets/oneui_widgets.dart';
import '../utils/toast_utils.dart';
import 'splash_screen.dart';

class CredentialsSetupScreen extends StatefulWidget {
  const CredentialsSetupScreen({super.key});

  @override
  State<CredentialsSetupScreen> createState() => _CredentialsSetupScreenState();
}

class _CredentialsSetupScreenState extends State<CredentialsSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accessKeyController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _regionController = TextEditingController(text: 'us-east-1');
  
  bool _obscureSecret = true;
  bool _saving = false;

  @override
  void dispose() {
    _accessKeyController.dispose();
    _secretKeyController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await AWSCredentialsService.saveCredentials(
        accessKey: _accessKeyController.text.trim(),
        secretKey: _secretKeyController.text.trim(),
        region: _regionController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SplashScreen(
              isReload: true,
              accessKey: _accessKeyController.text.trim(),
              secretKey: _secretKeyController.text.trim(),
              region: _regionController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Failed to save credentials: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Header Section
                Text(
                  'AethrOps',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Quantify',
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your AWS Cloud Infrastructure\nAnytime, Anywhere.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xFF666666),
                    height: 1.5,
                    letterSpacing: 0.2,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Lottie Animation
                SizedBox(
                  height: 200,
                  child: Lottie.asset(
                    'assets/animations/Pin code Password Protection, Secure Login animation.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Input Fields
                // AWS Access Key
                OneUIPillTextField(
                  controller: _accessKeyController,
                  label: 'AWS Access Key',
                  hint: 'AKIAIOSFODNN7EXAMPLE',
                  icon: Icons.key_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Access Key is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // AWS Secret Access Key
                OneUIPillTextField(
                  controller: _secretKeyController,
                  label: 'AWS Secret Access Key',
                  hint: '••••••••••••••••••••••••••',
                  icon: Icons.lock_rounded,
                  obscureText: _obscureSecret,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureSecret ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Secret Key is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // AWS Region
                OneUIPillTextField(
                  controller: _regionController,
                  label: 'AWS Region',
                  hint: 'us-east-1',
                  icon: Icons.public_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Region is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Connect Button
                OneUIPillButton(
                  text: 'Let\'s Get Started',
                  onPressed: _saveCredentials,
                  isLoading: _saving,
                ),
                
                const SizedBox(height: 24),
                
                // Security Info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppTheme.primaryPurple.withValues(alpha: 0.1)
                        : AppTheme.purple50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: AppTheme.primaryPurple,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your credentials are stored securely on your device',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF666666),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Help Link
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const CredentialsTutorialDialog(),
                    );
                  },
                  icon: Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: AppTheme.primaryPurple,
                  ),
                  label: Text(
                    'Need help getting credentials?',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
