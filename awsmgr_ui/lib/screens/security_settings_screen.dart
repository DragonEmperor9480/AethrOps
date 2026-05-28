import 'package:flutter/material.dart';
import 'dart:io';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 'pin_lock_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _securityEnabled = false;
  bool _biometricEnabled = false;
  bool _canUseBiometric = false;
  List<String> _availableBiometrics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);

    final securityEnabled = await SecurityService.isSecurityEnabled();
    final biometricEnabled = await SecurityService.isBiometricEnabled();
    final canUseBiometric = await SecurityService.canUseBiometric();

    final biometrics = await SecurityService.getAvailableBiometrics();
    final biometricNames = biometrics.map((b) => b.name).toList();

    setState(() {
      _securityEnabled = securityEnabled;
      _biometricEnabled = biometricEnabled;
      _canUseBiometric = canUseBiometric;
      _availableBiometrics = biometricNames;
      _loading = false;
    });
  }

  Future<void> _toggleSecurity(bool value) async {
    if (value) {
      // Enable security - set up PIN
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinLockScreen(
            isSetup: true,
            isCancelable: true,
          ),
        ),
      );

      if (result == true) {
        setState(() => _securityEnabled = true);
      }
    } else {
      // Disable security - verify PIN first
      final verified = await _verifyCurrentPin();
      if (verified) {
        await SecurityService.disableSecurity();
        setState(() {
          _securityEnabled = false;
          _biometricEnabled = false;
        });
        if (mounted) {
          ToastUtils.show(context, 'Security disabled', isError: false);
        }
      }
    }
  }

  Future<bool> _verifyCurrentPin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const PinLockScreen(
          isSetup: false,
          isCancelable: true,
        ),
      ),
    );
    return result == true;
  }

  Future<void> _changePin() async {
    final verified = await _verifyCurrentPin();
    if (!verified) return;

    if (mounted) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PinLockScreen(
            isSetup: true,
            isCancelable: true,
          ),
        ),
      );

      if (result == true && mounted) {
        ToastUtils.show(context, 'PIN changed successfully', isError: false);
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (!_canUseBiometric) {
      ToastUtils.show(
        context,
        'Biometric authentication not available',
        isError: true,
      );
      return;
    }

    if (value) {
      // Test biometric before enabling
      final success = await SecurityService.authenticateWithBiometric();
      if (success) {
        await SecurityService.setBiometricEnabled(true);
        setState(() => _biometricEnabled = true);
        if (mounted) {
          ToastUtils.show(
            context,
            'Biometric authentication enabled',
            isError: false,
          );
        }
      } else {
        if (mounted) {
          ToastUtils.show(
            context,
            'Biometric authentication failed',
            isError: true,
          );
        }
      }
    } else {
      await SecurityService.setBiometricEnabled(false);
      setState(() => _biometricEnabled = false);
      if (mounted) {
        ToastUtils.show(
          context,
          'Biometric authentication disabled',
          isError: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Security Settings'), elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSecurityCard(),
                const SizedBox(height: 16),
                if (_securityEnabled) ...[
                  _buildPinCard(),
                  const SizedBox(height: 16),
                  if (_canUseBiometric) _buildBiometricCard(),
                ],
              ],
            ),
    );
  }

  Widget _buildSecurityCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.security,
                    color: AppTheme.primaryPurple,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Security',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Protect your app with PIN',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _securityEnabled,
                  onChanged: _toggleSecurity,
                  activeThumbColor: AppTheme.primaryPurple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.pin,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
            ),
            title: const Text('Change PIN'),
            subtitle: const Text('Update your security PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _changePin,
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard() {
    String biometricType = 'Biometric';
    IconData biometricIcon = Icons.fingerprint;

    if (Platform.isWindows) {
      biometricType = 'Windows Hello';
      biometricIcon = Icons.lock_person;
    } else if (_availableBiometrics.contains('fingerprint')) {
      biometricType = 'Fingerprint';
      biometricIcon = Icons.fingerprint;
    } else if (_availableBiometrics.contains('face')) {
      biometricType = 'Face Recognition';
      biometricIcon = Icons.face;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                biometricIcon,
                color: AppTheme.successGreen,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    biometricType,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Use $biometricType to unlock',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: _biometricEnabled,
              onChanged: _toggleBiometric,
              activeThumbColor: AppTheme.successGreen,
            ),
          ],
        ),
      ),
    );
  }
}
