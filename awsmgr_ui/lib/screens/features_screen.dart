import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final features = [
      {
        'icon': Icons.cloud,
        'title': 'EC2 Management',
        'desc': 'Launch, monitor, and manage EC2 instances with ease. Control your compute resources from anywhere.',
        'color': AppTheme.ec2Color,
      },
      {
        'icon': Icons.storage,
        'title': 'S3 Browser',
        'desc': 'Browse, upload, download, and manage S3 buckets and objects. Full file management capabilities.',
        'color': AppTheme.s3Color,
      },
      {
        'icon': Icons.vpn_key,
        'title': 'IAM Control',
        'desc': 'Manage users, roles, groups, and policies. Complete identity and access management.',
        'color': AppTheme.iamColor,
      },
      {
        'icon': Icons.monitor_heart,
        'title': 'CloudWatch Logs',
        'desc': 'Real-time log streaming and monitoring. View and search through your application logs.',
        'color': AppTheme.cloudwatchColor,
      },
      {
        'icon': Icons.email,
        'title': 'Email Alerts',
        'desc': 'Configure SMTP-based email notifications for important events and alerts.',
        'color': AppTheme.primaryPurple,
      },
      {
        'icon': Icons.security,
        'title': 'Biometric Security',
        'desc': 'Protect your app with PIN codes and fingerprint authentication for enhanced security.',
        'color': AppTheme.successGreen,
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Features'),
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.1),
                  AppTheme.primaryBlue.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryPurple,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Powerful Features',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Everything you need to manage your AWS infrastructure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Features List
          ...features.map((feature) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (feature['color'] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: feature['color'] as Color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feature['desc'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
