import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../services/backend_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 'contributors_screen.dart';
import 'features_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = 'Loading...';
  String _osName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendService.baseUrl}/api/version'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _version = data['version'] ?? '1.0.0';
          _osName = data['os_name'] ?? 'Unknown';
        });
      }
    } catch (e) {
      setState(() {
        _version = '1.0.0';
        _osName = 'Unknown';
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.show(context, 'Could not open URL: $url', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final isLandscape = width > height || width >= 900;

    if (isLandscape) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('About AethrOps'),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Branding, Version & Credits
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        _buildLandscapeBranding(isDark),
                        const SizedBox(height: 24),
                        _buildVersionCard(isDark),
                        const SizedBox(height: 24),
                        _buildMadeWithLove(isDark),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Right Column: Explore & Resources & Tech Stack
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Explore', isDark),
                        const SizedBox(height: 16),
                        _buildNavigationCard(
                          'Features',
                          'Checkout all the features you can use',
                          Icons.auto_awesome,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FeaturesScreen(),
                              ),
                            );
                          },
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildNavigationCard(
                          'Contributors',
                          'Checkout contributors!',
                          Icons.people,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ContributorsScreen(),
                              ),
                            );
                          },
                          isDark,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Resources', isDark),
                        const SizedBox(height: 16),
                        _buildLinkCard(
                          'Visit Website',
                          'Checkout our cool website!',
                          Icons.language,
                          'https://aethrops.amrutlabs.in/',
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkCard(
                          'Documentation',
                          'Learn about AethrOps',
                          Icons.menu_book,
                          'https://aethrops.amrutlabs.in/docs',
                          isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildLinkCard(
                          'Source Code',
                          'Checkout our GitHub repository!',
                          Icons.code,
                          'https://github.com/DragonEmperor9480/AethrOps',
                          isDark,
                        ),
                        const SizedBox(height: 32),
                        _buildSectionTitle('Built With', isDark),
                        const SizedBox(height: 16),
                        _buildTechStack(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF1A1A1A), const Color(0xFF121212)]
                        : [const Color(0xFFF5F5F5), Colors.white],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.primaryBlue,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.cloud_outlined,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App Name
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
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Anurati',
                            color: Colors.white,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cloud Management Platform',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.black54,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Version Info Card
                  _buildVersionCard(isDark),

                  const SizedBox(height: 24),

                  // Navigation Cards
                  _buildNavigationCard(
                    'Features',
                    'Checkout all the features you can use',
                    Icons.auto_awesome,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FeaturesScreen(),
                        ),
                      );
                    },
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildNavigationCard(
                    'Contributors',
                    'Checkout contributors!',
                    Icons.people,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContributorsScreen(),
                        ),
                      );
                    },
                    isDark,
                  ),

                  const SizedBox(height: 24),

                  // Website & Docs Links
                  _buildLinkCard(
                    'Visit Website',
                    'Checkout our cool website!',
                    Icons.language,
                    'https://aethrops.amrutlabs.in/',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildLinkCard(
                    'Documentation',
                    'Learn about AethrOps',
                    Icons.menu_book,
                    'https://aethrops.amrutlabs.in/docs',
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildLinkCard(
                    'Source Code',
                    'Checkout our GitHub repository!',
                    Icons.code,
                    'https://github.com/DragonEmperor9480/AethrOps',
                    isDark,
                  ),

                  const SizedBox(height: 32),

                  // Tech Stack
                  _buildSectionTitle('Built With', isDark),
                  const SizedBox(height: 16),
                  _buildTechStack(isDark),

                  const SizedBox(height: 32),

                  // Made with Love
                  _buildMadeWithLove(isDark),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeBranding(bool isDark) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(
            Icons.cloud_outlined,
            size: 55,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [AppTheme.primaryPurple, AppTheme.primaryBlue, AppTheme.accentCyan],
          ).createShader(bounds),
          child: const Text(
            'AethrOps',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFamily: 'Anurati',
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cloud Management Platform',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.black54,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildVersionCard(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryPurple.withValues(alpha: 0.15),
              AppTheme.primaryBlue.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Version: ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                Text(
                  _version,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Quantify',
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 16,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.computer,
              size: 16,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              _osName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    String title,
    String description,
    IconData icon,
    String url,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => _launchURL(url),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(20),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withValues(alpha: 0.15),
                    AppTheme.primaryBlue.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.primaryPurple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(20),
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryPurple.withValues(alpha: 0.15),
                    AppTheme.primaryBlue.withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppTheme.primaryPurple, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.primaryPurple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildTechStack(bool isDark) {
    final stack = [
      {'name': 'Flutter', 'color': const Color(0xFF02569B)},
      {'name': 'Dart', 'color': const Color(0xFF0175C2)},
      {'name': 'Go', 'color': const Color(0xFF00ADD8)},
      {'name': 'AWS SDK', 'color': const Color(0xFFFF9900)},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stack.map((tech) {
        final techColor = tech['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: techColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            tech['name'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: techColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMadeWithLove(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Made with',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.favorite, color: AppTheme.errorRed, size: 24),
              const SizedBox(width: 8),
              Text(
                'by',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _launchURL('https://github.com/DragonEmperor9480'),
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                    ).createShader(bounds),
                    child: const Text(
                      'Amrutesh',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: AppTheme.primaryPurple,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '© 2025-2026 AethrOps',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
}
