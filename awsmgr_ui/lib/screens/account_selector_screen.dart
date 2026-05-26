import 'package:flutter/material.dart';
import '../services/aws_profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/oneui_widgets.dart';
import '../widgets/security_wrapper.dart';
import '../utils/toast_utils.dart';
import 'credentials_setup_screen.dart';
import 'home_screen.dart';

class AccountSelectorScreen extends StatefulWidget {
  const AccountSelectorScreen({super.key});

  @override
  State<AccountSelectorScreen> createState() => _AccountSelectorScreenState();
}

class _AccountSelectorScreenState extends State<AccountSelectorScreen> {
  List<dynamic> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final accounts = await AWSProfileService.listAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _selectAccount(dynamic account) async {
    final id = account['id'] as int;
    final name = account['profile_name'] as String;

    // Show beautiful loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.primaryPurple),
              const SizedBox(height: 24),
              Text(
                'Connecting to $name...',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Initializing AWS clients securely...',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await AWSProfileService.activateAccount(id);
      if (mounted) {
        Navigator.pop(context); // Close loading overlay
        if (result['success'] == true) {
          ToastUtils.show(context, 'Successfully logged into $name', isError: false);
          // Navigate to HomeScreen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const SecurityWrapper(child: HomeScreen()),
            ),
            (route) => false,
          );
        } else {
          ToastUtils.show(context, result['message'], isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading overlay
        ToastUtils.show(context, 'Connection failed: $e', isError: true);
      }
    }
  }

  Future<void> _deleteAccount(dynamic account) async {
    final id = account['id'] as int;
    final name = account['profile_name'] as String;

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
                          Icons.delete_forever_rounded,
                          color: AppTheme.errorRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Delete Account Profile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Are you sure you want to delete the profile "$name"? This will remove its encrypted credentials permanently.',
                              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
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
                        text: 'Delete Profile',
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
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
        final result = await AWSProfileService.deleteAccount(id);
        if (result['success'] == true) {
          if (mounted) ToastUtils.show(context, 'Profile "$name" deleted', isError: false);
          _loadAccounts();
        } else {
          if (mounted) ToastUtils.show(context, result['message'], isError: true);
        }
      } catch (e) {
        if (mounted) ToastUtils.show(context, 'Failed to delete account: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Back button if pushed
            if (Navigator.of(context).canPop())
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                ),
              ),

            // Custom Header using OneUI styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        AppTheme.primaryPurple,
                        AppTheme.primaryBlue,
                        AppTheme.accentCyan,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'AethrOps',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Anurati',
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select an AWS account profile to begin',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryPurple))
                  : _accounts.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _accounts.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final acc = _accounts[index];
                            return _buildAccountCard(acc, isDark);
                          },
                        ),
            ),

            // Bottom Add Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: OneUIPillButton(
                text: 'Add AWS Profile',
                icon: Icons.add_circle_outline_rounded,
                backgroundColor: AppTheme.primaryPurple,
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CredentialsSetupScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadAccounts();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: AppTheme.primaryPurple,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No AWS Profiles Configured',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add your first AWS credential profile to connect and manage your infrastructure.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(dynamic acc, bool isDark) {
    final bool isActive = acc['is_active'] == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [
                  AppTheme.primaryPurple.withValues(alpha: 0.18),
                  AppTheme.primaryBlue.withValues(alpha: 0.18),
                ]
              : isDark
                  ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.05)]
                  : [Colors.black.withValues(alpha: 0.03), Colors.black.withValues(alpha: 0.03)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryPurple.withValues(alpha: 0.5)
              : isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
          width: isActive ? 1.8 : 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectAccount(acc),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  // Icon badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [AppTheme.primaryPurple, AppTheme.primaryBlue]
                            : isDark
                                ? [Colors.white12, Colors.white10]
                                : [Colors.black12, Colors.black26],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.cloud_done_outlined,
                      color: isActive ? Colors.white : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Detail Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              acc['profile_name'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.successGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Region: ${acc['region']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Access Key: ${acc['access_key_id']}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 22),
                    onPressed: () => _deleteAccount(acc),
                    tooltip: 'Delete Profile',
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
