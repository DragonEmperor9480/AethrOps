import 'package:flutter/material.dart';
import '../services/email_config_service.dart';
import '../utils/toast_utils.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/oneui_widgets.dart';

class EmailConfigDialog extends StatefulWidget {
  const EmailConfigDialog({super.key});

  @override
  State<EmailConfigDialog> createState() => _EmailConfigDialogState();
}

class _EmailConfigDialogState extends State<EmailConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _smtpHostController = TextEditingController(text: 'smtp.gmail.com');
  final _smtpPortController = TextEditingController(text: '587');
  final _senderEmailController = TextEditingController();
  final _senderPassController = TextEditingController();
  final _senderNameController = TextEditingController(text: 'AethrOps');
  bool _obscurePassword = true;
  bool _isSaveLoading = false;
  bool _isTestLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  Future<void> _loadExistingConfig() async {
    final config = await EmailConfigService.getEmailConfig();
    if (config != null && mounted) {
      setState(() {
        _smtpHostController.text = config['smtp_host'] ?? 'smtp.gmail.com';
        _smtpPortController.text = (config['smtp_port'] ?? 587).toString();
        _senderEmailController.text = config['sender_email'] ?? '';
        _senderPassController.text = config['sender_pass'] ?? '';
        _senderNameController.text = config['sender_name'] ?? 'AethrOps';
      });
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaveLoading = true);
    try {
      await EmailConfigService.saveEmailConfig(
        smtpHost: _smtpHostController.text.trim(),
        smtpPort: int.parse(_smtpPortController.text.trim()),
        senderEmail: _senderEmailController.text.trim(),
        senderPass: _senderPassController.text,
        senderName: _senderNameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(
          context,
          'Failed to save configuration: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaveLoading = false);
      }
    }
  }

  Future<void> _testEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTestLoading = true);
    try {
      await ApiService.sendTestEmail(
        smtpHost: _smtpHostController.text.trim(),
        smtpPort: int.parse(_smtpPortController.text.trim()),
        senderEmail: _senderEmailController.text.trim(),
        senderPass: _senderPassController.text,
      );

      if (mounted) {
        ToastUtils.show(
          context,
          'Test email sent successfully! Check your inbox.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(
          context,
          'Test failed: ${e.toString().replaceAll("Exception: ", "")}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTestLoading = false);
      }
    }
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => const EmailConfigHelpDialog(),
    );
  }

  @override
  void dispose() {
    _smtpHostController.dispose();
    _smtpPortController.dispose();
    _senderEmailController.dispose();
    _senderPassController.dispose();
    _senderNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.email,
                      color: AppTheme.primaryPurple,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Configuration',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configure SMTP settings for sending emails',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    onPressed: _showHelp,
                    tooltip: 'Help',
                    color: AppTheme.primaryPurple,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OneUIPillTextField(
                        controller: _smtpHostController,
                        label: 'SMTP Host',
                        hint: 'smtp.gmail.com',
                        icon: Icons.dns,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'SMTP host is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      OneUIPillTextField(
                        controller: _smtpPortController,
                        label: 'SMTP Port',
                        hint: '587',
                        icon: Icons.settings_ethernet,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'SMTP port is required';
                          }
                          final port = int.tryParse(value);
                          if (port == null || port < 1 || port > 65535) {
                            return 'Invalid port number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      OneUIPillTextField(
                        controller: _senderEmailController,
                        label: 'Sender Email',
                        hint: 'your-email@gmail.com',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Sender email is required';
                          }
                          if (!value.contains('@')) {
                            return 'Invalid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      OneUIPillTextField(
                        controller: _senderPassController,
                        label: 'App Password',
                        hint: 'Enter app password',
                        icon: Icons.lock,
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscurePassword = !_obscurePassword,
                            );
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'App password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      OneUIPillTextField(
                        controller: _senderNameController,
                        label: 'Sender Name',
                        hint: 'AethrOps',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Sender name is required';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OneUIPillButton(
                          text: 'Test Email',
                          onPressed: _testEmail,
                          isLoading: _isTestLoading,
                          icon: Icons.send,
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppTheme.primaryPurple,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OneUIPillButton(
                          text: 'Save',
                          onPressed: _saveConfig,
                          isLoading: _isSaveLoading,
                          icon: Icons.save,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Help Dialog
class EmailConfigHelpDialog extends StatelessWidget {
  const EmailConfigHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.purple400, AppTheme.purple600],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.help, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Email Configuration Help',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('Gmail Setup', Icons.mail, Colors.red, [
                      '1. Go to your Google Account settings',
                      '2. Navigate to Security → 2-Step Verification',
                      '3. Scroll down to "App passwords"',
                      '4. Select "Mail" and your device',
                      '5. Copy the 16-character password',
                      '6. Use this password in the "App Password" field',
                    ]),
                    const SizedBox(height: 24),

                    _buildSection(
                      'Common SMTP Settings',
                      Icons.settings,
                      AppTheme.primaryBlue,
                      [
                        'Gmail: smtp.gmail.com:587',
                        'Outlook: smtp-mail.outlook.com:587',
                        'Yahoo: smtp.mail.yahoo.com:587',
                        'Office 365: smtp.office365.com:587',
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSection(
                      'Security Tips',
                      Icons.security,
                      AppTheme.successGreen,
                      [
                        '✓ Always use App Passwords, never your main password',
                        '✓ Enable 2-Factor Authentication on your email',
                        '✓ Use port 587 for TLS encryption',
                        '✓ Keep your credentials secure',
                        '✓ Revoke app passwords you no longer use',
                      ],
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.warningAmber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info, color: Colors.orange),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Your email credentials are stored securely in the app data directory and used by the backend to send emails.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
