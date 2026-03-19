import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/email_config_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';

/// Dialog for displaying and managing newly created IAM user credentials.
class CredentialsDialog extends StatefulWidget {
  final List<Map<String, String?>> credentials;

  const CredentialsDialog({super.key, required this.credentials});

  @override
  State<CredentialsDialog> createState() => _CredentialsDialogState();
}

class _CredentialsDialogState extends State<CredentialsDialog> {
  final Set<int> _visiblePasswords = {};
  bool _sending = false;

  void _togglePasswordVisibility(int index) {
    setState(() {
      if (_visiblePasswords.contains(index)) {
        _visiblePasswords.remove(index);
      } else {
        _visiblePasswords.add(index);
      }
    });
  }

  Future<void> _sendViaEmail(Map<String, String?> credential) async {
    // Check if email config exists
    final hasConfig = await EmailConfigService.hasEmailConfig();
    if (!hasConfig) {
      if (mounted) {
        ToastUtils.show(
          context,
          'Please configure email settings first',
          isError: true,
        );
      }
      return;
    }

    if (!mounted) return;

    // Ask for recipient email
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.email_rounded,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Send Credentials'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send credentials for ${credential['username']} via email',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Recipient Email',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(
                    color: AppTheme.primaryPurple,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.contains('@')) {
                Navigator.pop(context, emailController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    if (!mounted) return;

    // Confirm email
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber),
            SizedBox(width: 12),
            Text('Confirm Email'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure this is the correct email address?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email_outlined,
                    color: AppTheme.primaryPurple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Send email
    setState(() => _sending = true);
    try {
      await ApiService.sendUserCredentialsEmail(
        username: credential['username']!,
        password: credential['password']!,
        email: email,
      );

      if (mounted) {
        ToastUtils.show(context, 'Credentials sent to $email', isError: false);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Failed to send email: $e', isError: true);
      }
    } finally {
      setState(() => _sending = false);
    }
  }

  void _downloadCredentials() {
    final buffer = StringBuffer();
    buffer.writeln('IAM User Credentials');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('=' * 50);
    buffer.writeln();

    for (var cred in widget.credentials) {
      buffer.writeln('Username: ${cred['username']}');
      if (cred['password'] != null && cred['password']!.isNotEmpty) {
        buffer.writeln('Password: ${cred['password']}');
      }
      buffer.writeln('-' * 50);
    }

    // Copy to clipboard
    final content = buffer.toString();
    Clipboard.setData(ClipboardData(text: content));

    ScaffoldMessenger.of(context).clearSnackBars();
    ToastUtils.show(
      context,
      'All credentials copied to clipboard!',
      isError: false,
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ToastUtils.show(context, '$label copied to clipboard', isError: false);
  }

  Widget _buildCredentialField({
    required BuildContext context,
    required String label,
    required String value,
    required bool isPassword,
    VoidCallback? onCopy,
    VoidCallback? onToggleVisibility,
    bool isVisible = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isVisible ? value : '•' * 20,
                    style: TextStyle(
                      fontFamily: isPassword ? 'monospace' : null,
                      fontSize: 15,
                      letterSpacing: (isPassword && !isVisible) ? 1 : 0,
                      fontWeight: isPassword
                          ? FontWeight.w500
                          : FontWeight.w400,
                      color: Colors.grey[900],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              if (isPassword && onToggleVisibility != null)
                IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  tooltip: isVisible ? 'Hide' : 'Show',
                  onPressed: onToggleVisibility,
                  splashRadius: 20,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 48,
                  ),
                ),
              if (isPassword)
                Container(width: 1, height: 24, color: Colors.grey.shade300),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: Colors.grey[600],
                ),
                tooltip: 'Copy $label',
                onPressed: onCopy,
                splashRadius: 20,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 48),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter out credentials without passwords
    final credsWithPasswords = widget.credentials
        .where((c) => c['password'] != null && c['password']!.isNotEmpty)
        .toList();

    if (credsWithPasswords.isEmpty) {
      // No passwords to show, just close
      Future.microtask(() {
        if (context.mounted) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: AppTheme.successGreen,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Created Successfully',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.warningAmber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.warningAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Colors.orange[800],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These credentials will not be available again. Please copy or download them now.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Credentials list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                itemCount: credsWithPasswords.length,
                separatorBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(),
                ),
                itemBuilder: (context, index) {
                  final cred = credsWithPasswords[index];
                  final username = cred['username'] ?? '';
                  final password = cred['password'] ?? '';
                  final isVisible = _visiblePasswords.contains(index);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCredentialField(
                        context: context,
                        label: 'Username',
                        value: username,
                        isPassword: false,
                        onCopy: () => _copyToClipboard(username, 'Username'),
                      ),
                      const SizedBox(height: 16),
                      _buildCredentialField(
                        context: context,
                        label: 'Console Password',
                        value: password,
                        isPassword: true,
                        isVisible: isVisible,
                        onToggleVisibility: () =>
                            _togglePasswordVisibility(index),
                        onCopy: () => _copyToClipboard(password, 'Password'),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _downloadCredentials,
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('Copy All Credentials'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () async {
                                  for (var cred in credsWithPasswords) {
                                    await _sendViaEmail(cred);
                                  }
                                },
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.email_outlined, size: 18),
                          label: Text(
                            _sending ? 'Sending...' : 'Email Credentials',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: AppTheme.primaryPurple,
                            side: const BorderSide(
                              color: AppTheme.primaryPurple,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
