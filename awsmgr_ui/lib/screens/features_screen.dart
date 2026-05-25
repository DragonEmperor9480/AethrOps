import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FeaturesScreen extends StatefulWidget {
  const FeaturesScreen({super.key});

  @override
  State<FeaturesScreen> createState() => _FeaturesScreenState();
}

class _FeaturesScreenState extends State<FeaturesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    
    // 1-column on mobile, 2-column on tablets, 3-column on desktop
    final crossAxisCount = width >= 1100 ? 3 : (width >= 750 ? 2 : 1);

    final features = [
      {
        'icon': Icons.cloud,
        'title': 'EC2 Management',
        'desc':
            'Launch, monitor, and manage EC2 instances with ease. Control your compute resources from anywhere.',
        'color': AppTheme.ec2Color,
      },
      {
        'icon': Icons.storage,
        'title': 'S3 Browser',
        'desc':
            'Browse, upload, download, and manage S3 buckets and objects. Full file management capabilities.',
        'color': AppTheme.s3Color,
      },
      {
        'icon': Icons.vpn_key,
        'title': 'IAM Control',
        'desc':
            'Manage users, roles, groups, and policies. Complete identity and access management.',
        'color': AppTheme.iamColor,
      },
      {
        'icon': Icons.monitor_heart,
        'title': 'CloudWatch Logs',
        'desc':
            'Real-time log streaming and monitoring. View and search through your application logs.',
        'color': AppTheme.cloudwatchColor,
      },
      {
        'icon': Icons.email,
        'title': 'Email Alerts',
        'desc':
            'Configure SMTP-based email notifications for important events and alerts.',
        'color': AppTheme.primaryPurple,
      },
      {
        'icon': Icons.security,
        'title': 'Biometric Security',
        'desc':
            'Protect your app with PIN codes and fingerprint authentication for enhanced security.',
        'color': AppTheme.successGreen,
      },
    ];

    // Chunk features list into rows for responsive equal-height alignment
    List<List<Map<String, dynamic>>> chunkedFeatures = [];
    for (var i = 0; i < features.length; i += crossAxisCount) {
      chunkedFeatures.add(
        features.sublist(
          i,
          (i + crossAxisCount) > features.length ? features.length : i + crossAxisCount,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Features'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryPurple.withValues(alpha: 0.15),
                        AppTheme.primaryBlue.withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.primaryPurple,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            AppTheme.primaryPurple,
                            AppTheme.primaryBlue,
                            AppTheme.accentCyan,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'Powerful Features',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Everything you need to manage your AWS infrastructure securely',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Responsive dynamic grid rows
                ...chunkedFeatures.map((rowItems) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...rowItems.map((item) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: _buildFeatureCard(item, isDark),
                            ),
                          );
                        }),
                        if (rowItems.length < crossAxisCount)
                          ...List.generate(
                            crossAxisCount - rowItems.length,
                            (index) => const Expanded(
                              child: SizedBox(),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, bool isDark) {
    final featureColor = feature['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? AppTheme.borderColorDark : AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  featureColor.withValues(alpha: 0.2),
                  featureColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: featureColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              feature['icon'] as IconData,
              color: featureColor,
              size: 26,
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
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  feature['desc'] as String,
                  style: TextStyle(
                    fontSize: 13,
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
  }
}
