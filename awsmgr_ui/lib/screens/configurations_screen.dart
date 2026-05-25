import 'package:flutter/material.dart';
import '../services/email_config_service.dart';
import '../services/api_service.dart';
import '../widgets/email_config_dialog.dart';
import '../widgets/mfa_device_dialog.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/oneui_widgets.dart';

class ConfigurationsScreen extends StatefulWidget {
  const ConfigurationsScreen({super.key});

  @override
  State<ConfigurationsScreen> createState() => _ConfigurationsScreenState();
}

class _ConfigurationsScreenState extends State<ConfigurationsScreen> {
  bool _hasEmailConfig = false;
  bool _hasMFADevice = false;
  bool _loading = true;
  String? _senderEmail;
  String? _mfaDeviceName;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      await Future.wait([
        _loadEmailConfigStatus(),
        _loadMFADeviceStatus(),
      ]);
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
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
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.errorRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Email Configuration',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Are you sure you want to delete your email configuration? You will need to re-enter it to send credentials via email.',
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
                  child: Column(
                    children: [
                      OneUIPillButton(
                        text: 'Delete',
                        icon: Icons.delete,
                        backgroundColor: AppTheme.errorRed,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
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
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.errorRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete MFA Device',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Are you sure you want to delete your MFA device configuration? You will need to re-enter it for MFA operations.',
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
                  child: Column(
                    children: [
                      OneUIPillButton(
                        text: 'Delete',
                        icon: Icons.delete,
                        backgroundColor: AppTheme.errorRed,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      appBar: AppBar(
        title: const Text('Configurations'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Email Configuration Section
                _buildSectionHeader('Email Configuration'),
                const SizedBox(height: 16),
                _buildEmailConfigCard(),

                const SizedBox(height: 32),

                // MFA Device Section
                _buildSectionHeader('MFA Device'),
                const SizedBox(height: 16),
                _buildMFADeviceCard(),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
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
              OneUIPillButton(
                text: _hasEmailConfig ? 'Update' : 'Configure',
                icon: _hasEmailConfig ? Icons.edit : Icons.add,
                backgroundColor: AppTheme.primaryPurple,
                width: null,
                onPressed: _configureEmail,
              ),
            ],
          ),
          if (_hasEmailConfig) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OneUIPillButton(
                    text: 'Delete',
                    icon: Icons.delete_outline,
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.errorRed,
                    onPressed: _deleteEmailConfig,
                  ),
                ),
              ],
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
              OneUIPillButton(
                text: _hasMFADevice ? 'Update' : 'Configure',
                icon: _hasMFADevice ? Icons.edit : Icons.add,
                backgroundColor: AppTheme.primaryBlue,
                width: null,
                onPressed: _configureMFADevice,
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
                  child: OneUIPillButton(
                    text: 'Delete',
                    icon: Icons.delete_outline,
                    backgroundColor: Colors.transparent,
                    foregroundColor: AppTheme.errorRed,
                    onPressed: _deleteMFADevice,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
