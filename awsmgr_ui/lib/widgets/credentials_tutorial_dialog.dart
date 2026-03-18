import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CredentialsTutorialDialog extends StatefulWidget {
  const CredentialsTutorialDialog({super.key});

  @override
  State<CredentialsTutorialDialog> createState() =>
      _CredentialsTutorialDialogState();
}

class _CredentialsTutorialDialogState extends State<CredentialsTutorialDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _steps = [
    {
      'image': 'assets/how_to_get_access_credentials/1_aws_console_homepage',
      'title': 'Step 1: Open AWS Console',
      'description':
          'Sign in to the AethrOps Console using your AWS account credentials.',
    },
    {
      'image':
          'assets/how_to_get_access_credentials/2_aws_security_credentials_page',
      'title': 'Step 2: Navigate to Security Credentials',
      'description':
          'Click on your account name in the top-right corner and select "Security credentials" from the dropdown menu.',
    },
    {
      'image':
          'assets/how_to_get_access_credentials/3_choosing_thrid_party_service_in_create_access_key',
      'title': 'Step 3: Create Access Key',
      'description':
          'Scroll to "Access keys" section, click "Create access key", and choose "Third-party service" as the use case.',
    },
    {
      'image':
          'assets/how_to_get_access_credentials/4_final retrive_access_keys_page',
      'title': 'Step 4: Save Your Credentials',
      'description':
          'Copy both the Access Key ID and Secret Access Key. Store them securely - this is the only time you\'ll see the secret key!',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppTheme.backgroundDark,
                    AppTheme.purple900.withValues(alpha: 0.3),
                  ]
                : [AppTheme.cardBackground, AppTheme.purple50],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppTheme.purple600.withValues(alpha: 0.3)
                : AppTheme.purple200,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: AppTheme.primaryPurple,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How to Get AWS Credentials',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Tap image to zoom • Pinch to zoom in/out',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondary,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Image Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Step indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            step['title']!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Image with zoom
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              // Show fullscreen image
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (context) => _FullscreenImageViewer(
                                    imagePath: step['image']!,
                                    title: step['title']!,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? AppTheme.purple600.withValues(
                                          alpha: 0.3,
                                        )
                                      : AppTheme.purple200,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryPurple.withValues(
                                      alpha: 0.1,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 3.0,
                                      child: Image.asset(
                                        step['image']!,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .broken_image_rounded,
                                                      size: 64,
                                                      color: AppTheme.textMuted,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Image not found',
                                                      style: TextStyle(
                                                        color:
                                                            AppTheme.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                      ),
                                    ),
                                  ),
                                  // Tap hint overlay
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.zoom_in_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Tap to expand',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Description
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.cardBackgroundDark
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.purple600.withValues(alpha: 0.2)
                                  : AppTheme.purple200,
                            ),
                          ),
                          child: Text(
                            step['description']!,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page indicators and navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppTheme.primaryPurple
                              : (isDark
                                    ? AppTheme.purple600.withValues(alpha: 0.3)
                                    : AppTheme.purple200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text('Previous'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryPurple,
                              side: BorderSide(color: AppTheme.primaryPurple),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_currentPage < _steps.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          icon: Icon(
                            _currentPage < _steps.length - 1
                                ? Icons.arrow_forward_rounded
                                : Icons.check_rounded,
                          ),
                          label: Text(
                            _currentPage < _steps.length - 1
                                ? 'Next'
                                : 'Got it!',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
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

// Fullscreen image viewer
class _FullscreenImageViewer extends StatelessWidget {
  final String imagePath;
  final String title;

  const _FullscreenImageViewer({required this.imagePath, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: isDark
            ? AppTheme.backgroundDark
            : AppTheme.primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(child: Image.asset(imagePath, fit: BoxFit.contain)),
      ),
    );
  }
}
