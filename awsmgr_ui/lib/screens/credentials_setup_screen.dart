import 'package:flutter/material.dart';
import '../services/aws_credentials_service.dart';
import '../theme/app_theme.dart';
import '../main.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save credentials: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text(
                  'AWS Credentials',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Enter your AWS credentials to get started',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                TextFormField(
                  controller: _accessKeyController,
                  decoration: InputDecoration(
                    labelText: 'Access Key ID',
                    hintText: 'AKIAIOSFODNN7EXAMPLE',
                    prefixIcon: const Icon(Icons.vpn_key),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Access Key is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _secretKeyController,
                  obscureText: _obscureSecret,
                  decoration: InputDecoration(
                    labelText: 'Secret Access Key',
                    hintText: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecret ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscureSecret = !_obscureSecret);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Secret Key is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                TextFormField(
                  controller: _regionController,
                  decoration: InputDecoration(
                    labelText: 'Region',
                    hintText: 'us-east-1',
                    prefixIcon: const Icon(Icons.public),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Region is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _saving ? null : _saveCredentials,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Continue',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your credentials are stored securely on your device and never shared.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
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
