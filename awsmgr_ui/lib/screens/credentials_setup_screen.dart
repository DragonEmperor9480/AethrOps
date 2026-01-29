import 'package:flutter/material.dart';
import '../services/aws_credentials_service.dart';
import '../theme/app_theme.dart';
import '../widgets/credentials_tutorial_dialog.dart';
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
        // Navigate to splash screen to reload backend with new credentials
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.backgroundDark,
                    AppTheme.purple900.withValues(alpha: 0.2),
                  ]
                : [
                    AppTheme.backgroundLight,
                    AppTheme.purple50,
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Section
                  Column(
                    children: [
                      // Logo with glow
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.purple600],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cloud_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Title
                      Text(
                        'Welcome to AethrOps',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      
                      // Subtitle
                      Text(
                        'Sign in with your AWS credentials',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.cardBackgroundDark.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.purple600.withValues(alpha: 0.3)
                            : AppTheme.purple200.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppTheme.primaryPurple.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Access Key Field
                        TextFormField(
                          controller: _accessKeyController,
                          style: TextStyle(
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Access Key ID',
                            hintText: 'AKIAIOSFODNN7EXAMPLE',
                            prefixIcon: Icon(
                              Icons.vpn_key_rounded,
                              color: AppTheme.primaryPurple,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryPurple,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.backgroundDark
                                : AppTheme.purple50.withValues(alpha: 0.3),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Access Key is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Secret Key Field
                        TextFormField(
                          controller: _secretKeyController,
                          obscureText: _obscureSecret,
                          style: TextStyle(
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Secret Access Key',
                            hintText: '••••••••••••••••••••••••••',
                            prefixIcon: Icon(
                              Icons.lock_rounded,
                              color: AppTheme.primaryPurple,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureSecret
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                              ),
                              onPressed: () {
                                setState(() => _obscureSecret = !_obscureSecret);
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryPurple,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.backgroundDark
                                : AppTheme.purple50.withValues(alpha: 0.3),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Secret Key is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Region Field
                        TextFormField(
                          controller: _regionController,
                          style: TextStyle(
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'AWS Region',
                            hintText: 'us-east-1',
                            prefixIcon: Icon(
                              Icons.public_rounded,
                              color: AppTheme.primaryPurple,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppTheme.primaryPurple,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.backgroundDark
                                : AppTheme.purple50.withValues(alpha: 0.3),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Region is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        
                        // Submit Button
                        ElevatedButton(
                          onPressed: _saving ? null : _saveCredentials,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _saving ? 0 : 4,
                            shadowColor: AppTheme.primaryPurple.withValues(alpha: 0.5),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Connect to AWS',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.primaryPurple.withValues(alpha: 0.1)
                          : AppTheme.purple50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppTheme.primaryPurple.withValues(alpha: 0.3)
                            : AppTheme.purple200.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color: AppTheme.primaryPurple,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your credentials are stored securely on your device and never shared with third parties.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Help link
                  Center(
                    child: TextButton.icon(
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
