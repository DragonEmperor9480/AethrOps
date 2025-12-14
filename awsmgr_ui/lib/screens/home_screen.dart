import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iam_screen.dart';
import 's3_screen.dart';
import 'settings_screen.dart';
import 'cloudwatch_screen.dart';
import 'ec2_screen.dart';
import '../widgets/service_card.dart';
import '../widgets/floating_particles.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/email_config_service.dart';
import '../services/aws_credentials_service.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showAllServices = false;
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;


  String _username = 'User';
  String _greeting = 'Good day';
  String _quote = 'Loading...';
  bool _isLoadingUserInfo = true;
  bool _isConnected = false;
  String _loadingMessage = 'Fetching your cloud identity...';

  final List<ServiceInfo> _mainServices = [
    ServiceInfo(
      title: 'IAM',
      description: 'Control access to AWS resources',
      icon: Icons.security,
      color: AppTheme.iamColor,
      route: '/iam',
    ),
    ServiceInfo(
      title: 'S3',
      description: 'Scalable cloud storage',
      icon: Icons.cloud_queue,
      color: AppTheme.s3Color,
      route: '/s3',
    ),
    ServiceInfo(
      title: 'EC2',
      description: 'Virtual servers in the cloud',
      icon: Icons.developer_board,
      color: AppTheme.ec2Color,
      route: '/ec2',
    ),
    ServiceInfo(
      title: 'CloudWatch',
      description: 'Monitor resources & logs',
      icon: Icons.insights,
      color: AppTheme.cloudwatchColor,
      route: '/cloudwatch',
    ),
  ];

  final List<ServiceInfo> _additionalServices = [
    ServiceInfo(
      title: 'Lambda',
      description: 'Run code without servers',
      icon: Icons.offline_bolt,
      color: AppTheme.lambdaColor,
      route: '/lambda',
      comingSoon: true,
    ),
    ServiceInfo(
      title: 'RDS',
      description: 'Relational Database',
      icon: Icons.storage_rounded,
      color: AppTheme.rdsColor,
      route: '/rds',
      comingSoon: true,
    ),
    ServiceInfo(
      title: 'VPC',
      description: 'Isolated cloud networks',
      icon: Icons.hub,
      color: AppTheme.vpcColor,
      route: '/vpc',
      comingSoon: true,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // Check for missing configurations after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMissingConfigurations();
    });

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();



    // Set initial greeting and quote immediately
    _greeting = _getGreeting();
    _quote = _getRandomQuote();

    // Cycle through funny loading messages
    _cycleLoadingMessages();

    // Load user info asynchronously
    _loadUserInfo();
  }

  void _cycleLoadingMessages() {
    final messages = AppConstants.userLoadingMessages;
    int index = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (_isLoadingUserInfo && mounted) {
        setState(() {
          index = (index + 1) % messages.length;
          _loadingMessage = messages[index];
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final identity = await ApiService.getCallerIdentity();
      final username = identity['username'] ?? 'User';

      setState(() {
        _username = username;
        _greeting = _getGreeting();
        _quote = _getRandomQuote();
        _isLoadingUserInfo = false;
        _isConnected = true;
      });
    } catch (e) {
      debugPrint('Error loading user info: $e');
      setState(() {
        _username = 'User';
        _greeting = _getGreeting();
        _quote = _getRandomQuote();
        _isLoadingUserInfo = false;
        _isConnected = false;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getRandomQuote() {
    return AppConstants.getRandomQuote();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _checkMissingConfigurations() async {
    // Only check if we have credentials (meaning user is "logged in")
    if (!await AWSCredentialsService.hasCredentials()) return;

    // Check if user has opted out of this prompt
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('hide_setup_prompt') == true) return;

    final missingItems = <String>[];

    // Check Email
    if (!await EmailConfigService.hasEmailConfig()) {
      missingItems.add('Email Notifications');
    }

    // Check MFA
    try {
      final mfaDevice = await ApiService.getMFADevice();
      if (mfaDevice['configured'] != true) {
        missingItems.add('MFA Device');
      }
    } catch (e) {
      // If error (e.g. backend down), assume missing or just ignore
      debugPrint('Error checking MFA status: $e');
    }

    if (missingItems.isNotEmpty && mounted) {
      _showConfigurationPrompt(missingItems);
    }
  }

  void _showConfigurationPrompt(List<String> missingItems) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.build_circle_outlined, color: AppTheme.primaryPurple),
            const SizedBox(width: 10),
            const Text('Complete Setup'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('To get the most out of AWS Manager, please configure:'),
            const SizedBox(height: 16),
            ...missingItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppTheme.warningAmber),
                    const SizedBox(width: 10),
                    Text(
                      item,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('hide_setup_prompt', true);
              navigator.pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
            child: const Text("Don't ask again"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Remind Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Configure Now'),
          ),
        ],
      ),
    );
  }

  void _navigateToService(String route, bool comingSoon) {
    if (comingSoon) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              const Text('This service is coming soon'),
            ],
          ),
          backgroundColor: theme.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: AppTheme.primaryPurple.withValues(alpha: 0.2),
            ),
          ),
        ),
      );
      return;
    }

    Widget screen;
    switch (route) {
      case '/iam':
        screen = const IAMScreen();
        break;
      case '/s3':
        screen = const S3Screen();
        break;
      case '/cloudwatch':
        screen = const CloudWatchScreen();
        break;
      case '/ec2':
        screen = const EC2Screen();
        break;
      case '/settings':
        screen = const SettingsScreen();
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.1);
          const end = Offset.zero;
          const curve = Curves.easeOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isLoadingUserInfo
                      ? AppTheme.purple400
                      : _isConnected
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingUserInfo)
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.onPrimary,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isLoadingUserInfo
                          ? 'Connecting...'
                          : _isConnected
                          ? 'Connected'
                          : 'Disconnected',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _navigateToService('/settings', false),
                tooltip: 'Settings',
              ),
            ],
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final isCollapsed = constraints.maxHeight <= 120;

                return FlexibleSpaceBar(
                  titlePadding: EdgeInsets.only(
                    left: 16,
                    right: 60,
                    bottom: 16,
                  ),
                  title: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = MediaQuery.of(context).size.width < 600;
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _greeting,
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 22,
                                fontWeight: FontWeight.w800,
                                color: theme.textTheme.bodyMedium?.color,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              _username,
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.w700,
                                color: theme.textTheme.bodyLarge?.color,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (!isCollapsed) ...[
                              const SizedBox(height: 4),
                              if (_isLoadingUserInfo)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: isMobile ? 10 : 12,
                                        height: isMobile ? 10 : 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppTheme.primaryPurple,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _loadingMessage,
                                          style: TextStyle(
                                            fontSize: isMobile ? 8 : 11,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            color: AppTheme.primaryPurple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(left: 4.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 2.0,
                                        ),
                                        child: Icon(
                                          Icons.format_quote,
                                          size: isMobile ? 9 : 12,
                                          color:
                                              theme.textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _quote,
                                          style: TextStyle(
                                            fontSize: isMobile ? 8 : 11,
                                            fontWeight: FontWeight.w600,
                                            fontStyle: FontStyle.italic,
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            letterSpacing: 0.2,
                                            height: 1.3,
                                          ),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryPurple.withValues(alpha: 0.1),
                              AppTheme.primaryBlue.withValues(alpha: 0.1),
                            ],
                          ),
                        ),
                      ),
                      // Floating particles
                      const FloatingParticles(
                        count: 15,
                        color: AppTheme.primaryPurple,
                      ),
                      // Shimmer effect
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: ShimmerPainter(
                              animation: _shimmerController.value,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Services Header
                  Container(
                    padding: const EdgeInsets.only(bottom: 4, left: 2),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: AppTheme.primaryPurple,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        'Available Services',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900
                          ? 4
                          : constraints.maxWidth > 600
                          ? 3
                          : 2;

                      // Adjust aspect ratio based on screen size
                      final aspectRatio = constraints.maxWidth > 600
                          ? 1.15
                          : 1.0;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: aspectRatio,
                        ),
                        itemCount: _mainServices.length,
                        itemBuilder: (context, index) {
                          final service = _mainServices[index];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(
                              milliseconds: 300 + (index * 100),
                            ),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Opacity(opacity: value, child: child),
                              );
                            },
                            child: ServiceCard(
                              title: service.title,
                              description: service.description,
                              icon: service.icon,
                              color: service.color,
                              onTap: () => _navigateToService(
                                service.route,
                                service.comingSoon,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  // Show All Services Button with enhanced design
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAllServices = !_showAllServices;
                          if (_showAllServices) {
                            _fadeController.forward();
                          } else {
                            _fadeController.reverse();
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        side: BorderSide(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        _showAllServices
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppTheme.primaryPurple,
                      ),
                      label: Text(
                        _showAllServices
                            ? 'Show Less Services'
                            : 'Show All Services',
                        style: TextStyle(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),

                  if (_showAllServices) ...[
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: AppTheme.primaryPurple,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.apps_outlined,
                                    color: AppTheme.primaryPurple,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Additional Services',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryPurple.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primaryPurple,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 900
                                  ? 4
                                  : constraints.maxWidth > 600
                                  ? 3
                                  : 2;

                              // Adjust aspect ratio based on screen size
                              final aspectRatio = constraints.maxWidth > 600
                                  ? 1.15
                                  : 1.0;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: aspectRatio,
                                    ),
                                itemCount: _additionalServices.length,
                                itemBuilder: (context, index) {
                                  final service = _additionalServices[index];
                                  return ServiceCard(
                                    title: service.title,
                                    description: service.comingSoon
                                        ? 'Coming Soon'
                                        : service.description,
                                    icon: service.icon,
                                    color: service.color,
                                    onTap: () => _navigateToService(
                                      service.route,
                                      service.comingSoon,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceInfo {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
  final bool comingSoon;

  ServiceInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    this.comingSoon = false,
  });
}

class ShimmerPainter extends CustomPainter {
  final double animation;

  ShimmerPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.transparent,
          AppTheme.primaryPurple.withValues(alpha: 0.1),
          Colors.transparent,
        ],
        stops: [animation - 0.3, animation, animation + 0.3],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(ShimmerPainter oldDelegate) => true;
}

class CirclesPainter extends CustomPainter {
  final double rotation;

  CirclesPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw rotating circles
    for (int i = 0; i < 3; i++) {
      final radius = 50.0 + (i * 30);
      final opacity = 0.15 - (i * 0.03);

      paint.color = AppTheme.primaryBlue.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation + (i * 0.5));
      canvas.translate(-center.dx, -center.dy);

      canvas.drawCircle(center, radius, paint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CirclesPainter oldDelegate) => true;
}
