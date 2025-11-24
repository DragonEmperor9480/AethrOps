import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'iam_screen.dart';
import 's3_screen.dart';
import 'settings_screen.dart';
import 'cloudwatch_screen.dart';
import '../widgets/service_card.dart';
import '../widgets/floating_particles.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _showAllServices = false;
  late AnimationController _fadeController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  
  String _username = 'User';
  String _greeting = 'Good day';
  String _quote = 'Loading...';
  bool _isLoadingUserInfo = true;
  bool _isConnected = false;
  String _loadingMessage = 'Fetching your cloud identity...';

  final List<ServiceInfo> _mainServices = [
    ServiceInfo(
      title: 'IAM',
      description: 'Identity & Access Management',
      icon: Icons.shield_outlined,
      color: AppTheme.iamColor,
      route: '/iam',
    ),
    ServiceInfo(
      title: 'S3',
      description: 'Object Storage Service',
      icon: Icons.storage_outlined,
      color: AppTheme.s3Color,
      route: '/s3',
    ),
    ServiceInfo(
      title: 'CloudWatch',
      description: 'Monitoring & Logs',
      icon: Icons.analytics_outlined,
      color: AppTheme.cloudwatchColor,
      route: '/cloudwatch',
    ),
  ];

  final List<ServiceInfo> _additionalServices = [
    ServiceInfo(
      title: 'EC2',
      description: 'Elastic Compute Cloud',
      icon: Icons.computer_outlined,
      color: AppTheme.ec2Color,
      route: '/ec2',
      comingSoon: true,
    ),
    ServiceInfo(
      title: 'Lambda',
      description: 'Serverless Functions',
      icon: Icons.functions,
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
      description: 'Virtual Private Cloud',
      icon: Icons.cloud_outlined,
      color: AppTheme.vpcColor,
      route: '/vpc',
      comingSoon: true,
    ),
  ];

  final List<String> _cloudQuotes = [
    "The cloud is just someone else's computer... but way cooler!",
    "In the cloud, we trust. On-premise, we backup.",
    "There's no place like 127.0.0.1, but the cloud comes close.",
    "Keep calm and scale horizontally.",
    "Infrastructure as code: Because clicking is for mortals.",
    "May your deployments be smooth and your rollbacks unnecessary.",
    "Cloud computing: Where virtual becomes reality.",
    "Automate everything, question nothing... except your bills.",
    "In the cloud, every day is a deployment day.",
    "The best time to migrate to cloud was yesterday. The second best time is now.",
    "Cloud: Because managing your own servers is so 2010.",
    "Your infrastructure should be cattle, not pets.",
    "May your uptime be high and your latency low.",
    "In AWS we trust, all others must bring IAM policies.",
    "The cloud never sleeps, and neither do DevOps engineers.",
  ];

  @override
  void initState() {
    super.initState();
    
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

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _rotateController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_rotateController);
    
    // Set initial greeting and quote immediately
    _greeting = _getGreeting();
    _quote = _getRandomQuote();
    
    // Cycle through funny loading messages
    _cycleLoadingMessages();
    
    // Load user info asynchronously
    _loadUserInfo();
  }

  void _cycleLoadingMessages() {
    final messages = [
      'Fetching your cloud identity...',
      'Diving into the AWS matrix...',
      'Asking the cloud gods for your name...',
      'Decrypting your digital DNA...',
      'Scanning the cloud for your existence...',
      'Retrieving your cosmic credentials...',
    ];
    
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
    final random = math.Random();
    return _cloudQuotes[random.nextInt(_cloudQuotes.length)];
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  void _navigateToService(String route, bool comingSoon) {
    if (comingSoon) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryPurple),
              const SizedBox(width: 8),
              const Text('This service is coming soon'),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.2)),
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
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isLoadingUserInfo
                      ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                      : _isConnected 
                          ? AppTheme.successGreen.withValues(alpha: 0.1)
                          : AppTheme.errorRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isLoadingUserInfo
                        ? AppTheme.primaryBlue.withValues(alpha: 0.3)
                        : _isConnected 
                            ? AppTheme.successGreen.withValues(alpha: 0.3)
                            : AppTheme.errorRed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isLoadingUserInfo)
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryBlue,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isConnected 
                              ? AppTheme.successGreen
                              : AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _isLoadingUserInfo 
                          ? 'Connecting...' 
                          : _isConnected 
                              ? 'Connected' 
                              : 'Disconnected',
                      style: TextStyle(
                        color: _isLoadingUserInfo
                            ? AppTheme.primaryBlue
                            : _isConnected 
                                ? AppTheme.successGreen
                                : AppTheme.errorRed,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
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
                  title: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryPurple.withValues(alpha: 0.1),
                                AppTheme.primaryBlue.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: AppTheme.primaryPurple,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$_greeting, $_username',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
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
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _loadingMessage,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(left: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Icon(
                                      Icons.format_quote,
                                      size: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _quote,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        color: AppTheme.textPrimary,
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
                  // Animated circles
                  AnimatedBuilder(
                    animation: _rotateAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: CirclesPainter(
                          rotation: _rotateAnimation.value,
                        ),
                      );
                    },
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
                  // Pulsing cloud icon
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppTheme.primaryPurple.withValues(alpha: 0.3),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cloud_outlined,
                              size: 60,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        );
                      },
                    ),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.dashboard_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Services',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your AWS infrastructure',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
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

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: _mainServices.length,
                        itemBuilder: (context, index) {
                          final service = _mainServices[index];
                          return TweenAnimationBuilder<double>(
                            duration: Duration(milliseconds: 300 + (index * 100)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
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
                  const SizedBox(height: 24),
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
                      icon: Icon(
                        _showAllServices ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(
                        _showAllServices ? 'Show Less' : 'Show All Services',
                      ),
                    ),
                  ),

                  if (_showAllServices) ...[
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.textSecondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.apps_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Additional Services',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final crossAxisCount = constraints.maxWidth > 900
                                  ? 4
                                  : constraints.maxWidth > 600
                                      ? 3
                                      : 2;

                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 1.15,
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
        stops: [
          animation - 0.3,
          animation,
          animation + 0.3,
        ],
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
