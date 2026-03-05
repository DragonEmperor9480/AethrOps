import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
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
                
                // OneUI Pill Container
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: isDark 
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AWS Access Key
                      _buildPillTextField(
                        controller: _accessKeyController,
                        label: 'AWS Access Key',
                        hint: 'AKIAIOSFODNN7EXAMPLE',
                        icon: Icons.key_rounded,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Access Key is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // AWS Secret Access Key
                      _buildPillTextField(
                        controller: _secretKeyController,
                        label: 'AWS Secret Access Key',
                        hint: '••••••••••••••••••••••••••',
                        icon: Icons.lock_rounded,
                        isDark: isDark,
                        obscureText: _obscureSecret,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureSecret ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                            color: isDark ? Colors.white60 : const Color(0xFF999999),
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
                      _buildPillTextField(
                        controller: _regionController,
                        label: 'AWS Region',
                        hint: 'us-east-1',
                        icon: Icons.public_rounded,
                        isDark: isDark,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Region is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Connect Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveCredentials,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: _saving ? 0 : 8,
                      shadowColor: AppTheme.primaryPurple.withValues(alpha: 0.4),
                      disabledBackgroundColor: isDark 
                          ? const Color(0xFF2A2A2A) 
                          : const Color(0xFFE0E0E0),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Let\'s Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
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

  Widget _buildPillTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: isDark ? Colors.white30 : const Color(0xFFCCCCCC),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 20, right: 12),
          child: Icon(
            icon,
            color: AppTheme.primaryPurple,
            size: 20,
          ),
        ),
        suffixIcon: suffixIcon != null 
            ? Padding(
                padding: const EdgeInsets.only(right: 12),
                child: suffixIcon,
              )
            : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: AppTheme.primaryPurple,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: AppTheme.errorRed,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: AppTheme.errorRed,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        labelStyle: TextStyle(
          color: isDark ? Colors.white60 : const Color(0xFF999999),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: AppTheme.primaryPurple,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: validator,
    );
  }
}
