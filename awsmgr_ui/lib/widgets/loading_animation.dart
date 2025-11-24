import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LoadingAnimation extends StatefulWidget {
  final String? message;
  final double size;

  const LoadingAnimation({
    super.key,
    this.message,
    this.size = 60,
  });

  @override
  State<LoadingAnimation> createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<LoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _getFunnyMessage() {
    if (widget.message == null) return '';
    
    final msg = widget.message!.toLowerCase();
    
    if (msg.contains('user')) {
      return 'Summoning IAM wizards...';
    } else if (msg.contains('group')) {
      return 'Gathering the squad...';
    } else if (msg.contains('bucket')) {
      return 'Diving into your secret buckets...';
    } else if (msg.contains('object')) {
      return 'Fishing for your files...';
    } else if (msg.contains('function')) {
      return 'Waking up Lambda functions...';
    } else if (msg.contains('log')) {
      return 'Reading the tea leaves...';
    } else {
      return 'Talking to the cloud...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main spinner with effects
          AnimatedBuilder(
            animation: Listenable.merge([_spinController, _pulseController]),
            builder: (context, child) {
              return SizedBox(
                width: widget.size * 1.8,
                height: widget.size * 1.8,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulsing glow background
                    Container(
                      width: widget.size * 1.2,
                      height: widget.size * 1.2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(
                              alpha: 0.2 + (_pulseController.value * 0.2),
                            ),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    
                    // Outer spinning ring
                    Transform.rotate(
                      angle: _spinController.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size(widget.size * 1.3, widget.size * 1.3),
                        painter: _ModernRingPainter(
                          color: AppTheme.primaryBlue,
                          strokeWidth: 3,
                          progress: _spinController.value,
                        ),
                      ),
                    ),
                    
                    // Middle ring (opposite direction)
                    Transform.rotate(
                      angle: -_spinController.value * 2.5 * math.pi,
                      child: CustomPaint(
                        size: Size(widget.size * 0.9, widget.size * 0.9),
                        painter: _ModernRingPainter(
                          color: AppTheme.accentCyan,
                          strokeWidth: 2.5,
                          progress: 1 - _spinController.value,
                        ),
                      ),
                    ),
                    
                    // Inner ring
                    Transform.rotate(
                      angle: _spinController.value * 3 * math.pi,
                      child: CustomPaint(
                        size: Size(widget.size * 0.55, widget.size * 0.55),
                        painter: _ModernRingPainter(
                          color: const Color(0xFFFF9900),
                          strokeWidth: 2,
                          progress: _spinController.value,
                        ),
                      ),
                    ),
                    
                    // Center dot with pulse
                    Transform.scale(
                      scale: 1.0 + (_pulseController.value * 0.2),
                      child: Container(
                        width: widget.size * 0.25,
                        height: widget.size * 0.25,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.primaryBlue,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Funny message
          Text(
            _getFunnyMessage(),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Animated progress bar
          AnimatedBuilder(
            animation: _spinController,
            builder: (context, child) {
              return SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                    minHeight: 3,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModernRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double progress;

  _ModernRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Draw main arc
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );

    // Draw dots at ends for extra flair
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Start dot
    final startAngle = -math.pi / 2;
    final startX = center.dx + radius * math.cos(startAngle);
    final startY = center.dy + radius * math.sin(startAngle);
    canvas.drawCircle(Offset(startX, startY), strokeWidth * 0.8, dotPaint);

    // End dot
    final endAngle = -math.pi / 2 + (math.pi * 1.5);
    final endX = center.dx + radius * math.cos(endAngle);
    final endY = center.dy + radius * math.sin(endAngle);
    canvas.drawCircle(Offset(endX, endY), strokeWidth * 0.8, dotPaint);
  }

  @override
  bool shouldRepaint(_ModernRingPainter oldDelegate) => false;
}

// Overlay loading widget
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.5),
            child: LoadingAnimation(message: message),
          ),
      ],
    );
  }
}
