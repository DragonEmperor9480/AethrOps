import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/toast_utils.dart';
import '../theme/app_theme.dart';
import 'oneui_widgets.dart';

class MFADeviceDialog extends StatefulWidget {
  const MFADeviceDialog({super.key});

  @override
  State<MFADeviceDialog> createState() => _MFADeviceDialogState();
}

class _MFADeviceDialogState extends State<MFADeviceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _deviceNameController = TextEditingController();
  final _deviceArnController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDevice();
  }

  Future<void> _loadExistingDevice() async {
    try {
      final device = await ApiService.getMFADevice();
      if (device['configured'] == true && mounted) {
        setState(() {
          _deviceNameController.text = device['device_name'] ?? '';
          _deviceArnController.text = device['device_arn'] ?? '';
        });
      }
    } catch (e) {
      // No existing device, that's fine
    }
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await ApiService.saveMFADevice(
        deviceName: _deviceNameController.text.trim(),
        deviceArn: _deviceArnController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(
          context,
          'Failed to save MFA device: $e',
          isError: true,
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _deviceArnController.dispose();
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
                      Icons.security,
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
                          'MFA Device Configuration',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configure your MFA device for S3 operations',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OneUIPillTextField(
                        controller: _deviceNameController,
                        label: 'Device Name',
                        hint: 'My Phone, YubiKey, etc.',
                        icon: Icons.phone_android,
                        autofocus: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Device name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      OneUIPillTextField(
                        controller: _deviceArnController,
                        label: 'Device ARN',
                        hint: 'arn:aws:iam::123456789012:mfa/user',
                        icon: Icons.vpn_key,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Device ARN is required';
                          }
                          if (!value.startsWith('arn:aws:iam:')) {
                            return 'Invalid ARN format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.primaryBlue,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'MFA device is required for S3 bucket operations like enabling MFA Delete. You can find your device ARN in the AWS IAM console.',
                                style: TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontSize: 13,
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
                      text: _loading ? 'Saving...' : 'Save Device',
                      icon: Icons.save,
                      isLoading: _loading,
                      backgroundColor: AppTheme.primaryPurple,
                      onPressed: _loading ? null : _saveDevice,
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
