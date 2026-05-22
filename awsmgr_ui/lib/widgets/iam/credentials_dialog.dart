import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../services/email_config_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/toast_utils.dart';
import '../oneui_widgets.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final email = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        Icons.email_rounded,
                        color: AppTheme.primaryPurple,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Send Credentials',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Send credentials for ${credential['username']} via email',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: OneUIPillTextField(
                  controller: emailController,
                  label: 'Recipient Email',
                  hint: 'user@example.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OneUIPillButton(
                        text: 'Next',
                        onPressed: () {
                          if (emailController.text.contains('@')) {
                            Navigator.pop(context, emailController.text.trim());
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (email == null || email.isEmpty) return;

    if (!mounted) return;

    // Confirm email
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.warningAmber,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirm Email',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Are you sure this is the correct email address?',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
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
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OneUIPillButton(
                        text: 'Send',
                        icon: Icons.send_rounded,
                        backgroundColor: AppTheme.successGreen,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.15) 
                  : Colors.black.withValues(alpha: 0.15),
            ),
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
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Container(
                width: 1, 
                height: 24, 
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.15) 
                    : Colors.black.withValues(alpha: 0.15),
              ),
              if (isPassword && onToggleVisibility != null)
                IconButton(
                  icon: Icon(
                    isVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
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
                Container(
                  width: 1, 
                  height: 24, 
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.15) 
                      : Colors.black.withValues(alpha: 0.15),
                ),
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Created Successfully',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
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
                      color: AppTheme.warningAmber.withValues(alpha: 0.15),
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
                          color: AppTheme.warningAmber,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These credentials will not be available again. Please copy or download them now.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppTheme.warningAmber,
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

            Divider(height: 1, color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor),

            // Credentials list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                itemCount: credsWithPasswords.length,
                separatorBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Divider(color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor),
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

            Divider(height: 1, color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OneUIPillButton(
                          text: 'Copy All',
                          onPressed: _downloadCredentials,
                          icon: Icons.copy_all_rounded,
                          backgroundColor: Colors.transparent,
                          foregroundColor: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OneUIPillButton(
                          text: _sending ? 'Sending...' : 'Email',
                          onPressed: _sending
                              ? null
                              : () async {
                                  for (var cred in credsWithPasswords) {
                                    await _sendViaEmail(cred);
                                  }
                                },
                          isLoading: _sending,
                          icon: Icons.email_outlined,
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OneUIPillButton(
                      text: 'Done',
                      onPressed: () => Navigator.pop(context),
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
