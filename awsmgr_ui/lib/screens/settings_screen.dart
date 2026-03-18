import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aws_credentials_service.dart';
import '../services/email_config_service.dart';
import '../services/api_service.dart';
import 'credentials_setup_screen.dart';
import 'about_screen.dart';
import 'security_settings_screen.dart';
import '../widgets/email_config_dialog.dart';
import '../widgets/mfa_device_dialog.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../utils/toast_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _hasCredentials = false;
  bool _hasEmailConfig = false;
  bool _hasMFADevice = false;
  bool _loading = true;
  String? _region;
  String? _senderEmail;
  String? _mfaDeviceName;

  @override
  void initState() {
    super.initState();
    _loadCredentialStatus();
    _loadEmailConfigStatus();
    _loadMFADeviceStatus();
  }

  Future<void> _loadCredentialStatus() async {
    setState(() => _loading = true);
    try {
      final hasCredentials = await AWSCredentialsService.hasCredentials();
      if (hasCredentials) {
        final creds = await AWSCredentialsService.getCredentials();
        setState(() {
          _hasCredentials = true;
          _region = creds['region'];
        });
      } else {
        setState(() => _hasCredentials = false);
      }
    } catch (e) {
      debugPrint('Error loading credentials: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadEmailConfigStatus() async {
    try {
      final hasConfig = await EmailConfigService.hasEmailConfig();
      if (hasConfig) {
        final config = await EmailConfigService.getEmailConfig();
        setState(() {
          _hasEmailConfig = true;
          _senderEmail = config?['sender_email'];
        });
      } else {
        setState(() => _hasEmailConfig = false);
      }
    } catch (e) {
      debugPrint('Error loading email config: $e');
    }
  }

  Future<void> _loadMFADeviceStatus() async {
    try {
      final device = await ApiService.getMFADevice();
      if (device['configured'] == true) {
        setState(() {
          _hasMFADevice = true;
          _mfaDeviceName = device['device_name'];
        });
      } else {
        setState(() => _hasMFADevice = false);
      }
    } catch (e) {
      debugPrint('Error loading MFA device: $e');
      setState(() => _hasMFADevice = false);
    }
  }

  Future<void> _updateCredentials() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CredentialsSetupScreen()),
    );

    if (result == true || mounted) {
      _loadCredentialStatus();
    }
  }

  Future<void> _deleteCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Credentials'),
        content: const Text(
          'Are you sure you want to delete your AWS credentials? '
          'You will need to re-enter them to use AWS services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AWSCredentialsService.deleteCredentials();
        setState(() {
          _hasCredentials = false;
          _region = null;
        });

        if (mounted) {
          ToastUtils.show(context, 'Credentials deleted', isError: false);

          // Navigate to credentials setup screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const CredentialsSetupScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.show(
            context,
            'Failed to delete credentials: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _configureEmail() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const EmailConfigDialog(),
    );

    if (result == true) {
      _loadEmailConfigStatus();
      if (mounted) {
        ToastUtils.show(context, 'Email configuration saved', isError: false);
      }
    }
  }

  Future<void> _deleteEmailConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Email Configuration'),
        content: const Text(
          'Are you sure you want to delete your email configuration? '
          'You will need to re-enter it to send credentials via email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EmailConfigService.deleteEmailConfig();
        setState(() {
          _hasEmailConfig = false;
          _senderEmail = null;
        });

        if (mounted) {
          ToastUtils.show(
            context,
            'Email configuration deleted',
            isError: false,
          );
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.show(
            context,
            'Failed to delete email configuration: $e',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _configureMFADevice() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const MFADeviceDialog(),
    );

    if (result == true) {
      _loadMFADeviceStatus();
      if (mounted) {
        ToastUtils.show(context, 'MFA device saved', isError: false);
      }
    }
  }

  Future<void> _deleteMFADevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete MFA Device'),
        content: const Text(
          'Are you sure you want to delete your MFA device configuration? '
          'You will need to re-enter it for MFA operations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteMFADevice();
        setState(() {
          _hasMFADevice = false;
          _mfaDeviceName = null;
        });

        if (mounted) {
          ToastUtils.show(context, 'MFA device deleted', isError: false);
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.show(
            context,
            'Failed to delete MFA device: $e',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Dark Mode Section
                _buildSectionHeader('Appearance'),
                const SizedBox(height: 16),
                _buildDarkModeCard(),

                const SizedBox(height: 32),

                // AWS Credentials Section
                _buildSectionHeader('AWS Credentials'),
                const SizedBox(height: 16),
                _buildCredentialsCard(),

                const SizedBox(height: 32),

                // Email Configuration Section
                _buildSectionHeader('Email Configuration'),
                const SizedBox(height: 16),
                _buildEmailConfigCard(),

                const SizedBox(height: 32),

                // MFA Device Section
                _buildSectionHeader('MFA Device'),
                const SizedBox(height: 16),
                _buildMFADeviceCard(),

                const SizedBox(height: 32),

                // Security Section
                _buildSectionHeader('Security'),
                const SizedBox(height: 16),
                _buildSecurityNavigationCard(),

                const SizedBox(height: 32),

                // About Section
                _buildSectionHeader('About'),
                const SizedBox(height: 16),
                _buildAboutNavigationCard(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }

  Widget _buildDarkModeCard() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.themeMode == ThemeMode.dark;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: AppTheme.primaryPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Mode(BETA)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDark
                          ? 'Dark theme is enabled'
                          : 'Light theme is enabled',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isDark,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeThumbColor: AppTheme.primaryPurple,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasCredentials
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _hasCredentials ? Icons.check_circle : Icons.warning_amber,
                  color: _hasCredentials
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasCredentials
                          ? 'Credentials Configured'
                          : 'No Credentials',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasCredentials
                          ? 'Region: ${_region ?? 'Unknown'}'
                          : 'Configure your AWS credentials',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasCredentials) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _updateCredentials,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Update'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      side: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteCredentials,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: BorderSide(color: AppTheme.errorRed),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _updateCredentials,
                icon: const Icon(Icons.add),
                label: const Text('Add Credentials'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailConfigCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasEmailConfig
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _hasEmailConfig
                      ? Icons.mark_email_read
                      : Icons.email_outlined,
                  color: _hasEmailConfig
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasEmailConfig ? 'Email Configured' : 'No Email Config',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasEmailConfig
                          ? 'Sender: ${_senderEmail ?? 'Unknown'}'
                          : 'Configure SMTP to send credentials',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasEmailConfig) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _configureEmail,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Update'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      side: BorderSide(color: AppTheme.primaryPurple),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteEmailConfig,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: BorderSide(color: AppTheme.errorRed),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _configureEmail,
                icon: const Icon(Icons.add),
                label: const Text('Configure Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMFADeviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _hasMFADevice
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.warningAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _hasMFADevice ? Icons.security : Icons.security_outlined,
                  color: _hasMFADevice
                      ? AppTheme.successGreen
                      : AppTheme.warningAmber,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hasMFADevice ? 'MFA Device Configured' : 'No MFA Device',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hasMFADevice
                          ? 'Device: ${_mfaDeviceName ?? 'Unknown'}'
                          : 'Configure MFA for S3 operations',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _configureMFADevice,
                icon: Icon(_hasMFADevice ? Icons.edit : Icons.add, size: 18),
                label: Text(_hasMFADevice ? 'Update' : 'Configure'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          if (_hasMFADevice) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteMFADevice,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                      side: BorderSide(
                        color: AppTheme.errorRed.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNavigationCard() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.successGreen.withValues(alpha: 0.1),
              AppTheme.primaryPurple.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.successGreen.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.successGreen, AppTheme.primaryPurple],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Security',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'PIN & Biometric authentication',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: AppTheme.successGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutNavigationCard() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryPurple.withValues(alpha: 0.1),
              AppTheme.primaryBlue.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About AethrOps',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Learn more about this app',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: AppTheme.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }
}
