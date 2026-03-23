import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';

class LoadingAnimation extends StatefulWidget {
  final String? message;
  final double size;
  final LoadingStyle style;
  final bool showQuote;

  const LoadingAnimation({
    super.key,
    this.message,
    this.size = 60,
    this.style = LoadingStyle.orbital,
    this.showQuote = true,
  });

  @override
  State<LoadingAnimation> createState() => _LoadingAnimationState();
}

enum LoadingStyle {
  orbital, // Multiple orbiting rings (default, professional)
  pulse, // Pulsing gradient orb
  dots, // Bouncing dots
  wave, // Wave effect
}

class _LoadingAnimationState extends State<LoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _secondaryController;
  late String _currentQuote;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _secondaryController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat();

    // Get random quote on init - either contextual or completely random
    _currentQuote = widget.message != null
        ? AppConstants.getContextualLoadingMessage(widget.message!)
        : AppConstants.getRandomQuote();
  }

  @override
  void dispose() {
    _controller.dispose();
    _secondaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLoadingIndicator(isDark),
          if (widget.showQuote) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                widget.message ?? _currentQuote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: widget.message != null ? FontStyle.normal : FontStyle.italic,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    switch (widget.style) {
      case LoadingStyle.orbital:
        return _buildOrbitalLoader(isDark);
      case LoadingStyle.pulse:
        return _buildPulseLoader(isDark);
      case LoadingStyle.dots:
        return _buildDotsLoader(isDark);
      case LoadingStyle.wave:
        return _buildWaveLoader(isDark);
    }
  }

  // Professional orbital loader with smooth animations
  Widget _buildOrbitalLoader(bool isDark) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _secondaryController]),
      builder: (context, child) {
        return SizedBox(
          width: widget.size * 2.2,
          height: widget.size * 2.2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle glow effect
              Container(
                width: widget.size * 1.5,
                height: widget.size * 1.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.primaryPurple.withValues(
                        alpha: isDark ? 0.15 : 0.08,
                      ),
                      AppTheme.primaryPurple.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),

              // Outer ring - clockwise
              Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size * 1.6, widget.size * 1.6),
                  painter: _ArcPainter(
                    color: AppTheme.primaryPurple,
                    strokeWidth: 3.0,
                    sweepAngle: math.pi * 0.6,
                    startAngle: 0,
                  ),
                ),
              ),

              // Middle ring - counter-clockwise
              Transform.rotate(
                angle: -_secondaryController.value * 2 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size * 1.15, widget.size * 1.15),
                  painter: _ArcPainter(
                    color: AppTheme.primaryBlue,
                    strokeWidth: 2.5,
                    sweepAngle: math.pi * 0.5,
                    startAngle: math.pi * 0.5,
                  ),
                ),
              ),

              // Inner ring - clockwise (faster)
              Transform.rotate(
                angle: _controller.value * 3 * math.pi,
                child: CustomPaint(
                  size: Size(widget.size * 0.7, widget.size * 0.7),
                  painter: _ArcPainter(
                    color: AppTheme.accentCyan,
                    strokeWidth: 2.0,
                    sweepAngle: math.pi * 0.4,
                    startAngle: math.pi,
                  ),
                ),
              ),

              // Center gradient orb
              Container(
                width: widget.size * 0.28,
                height: widget.size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Smooth pulsing gradient orb
  Widget _buildPulseLoader(bool isDark) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;

        return Container(
          width: widget.size * (1.0 + pulse * 0.3),
          height: widget.size * (1.0 + pulse * 0.3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.primaryPurple.withValues(alpha: 0.8),
                AppTheme.primaryBlue.withValues(alpha: 0.6),
                AppTheme.accentCyan.withValues(alpha: 0.3),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3 * pulse),
                blurRadius: 30 * pulse,
                spreadRadius: 10 * pulse,
              ),
            ],
          ),
        );
      },
    );
  }

  // Bouncing dots loader
  Widget _buildDotsLoader(bool isDark) {
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 0.4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.15;
              final value = (_controller.value - delay) % 1.0;
              final bounce = (math.sin(value * 2 * math.pi)).abs();

              return Transform.translate(
                offset: Offset(0, -bounce * 15),
                child: Container(
                  width: widget.size * 0.2,
                  height: widget.size * 0.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        [
                          AppTheme.primaryPurple,
                          AppTheme.primaryBlue,
                          AppTheme.accentCyan,
                        ][index],
                        [
                          AppTheme.primaryBlue,
                          AppTheme.accentCyan,
                          AppTheme.primaryPurple,
                        ][index],
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: [
                          AppTheme.primaryPurple,
                          AppTheme.primaryBlue,
                          AppTheme.accentCyan,
                        ][index].withValues(alpha: 0.3),
                        blurRadius: 5,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  // Wave effect loader
  Widget _buildWaveLoader(bool isDark) {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 0.5,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(5, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.1;
              final value = (_controller.value - delay) % 1.0;
              final height = (math.sin(value * 2 * math.pi) + 1) / 2;

              return Container(
                width: widget.size * 0.12,
                height: widget.size * (0.2 + height * 0.3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppTheme.primaryPurple, AppTheme.primaryBlue],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// Custom painter for smooth arcs
class _ArcPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double sweepAngle;
  final double startAngle;

  _ArcPainter({
    required this.color,
    required this.strokeWidth,
    required this.sweepAngle,
    required this.startAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.3),
          color,
          color,
          color.withValues(alpha: 0.3),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => false;
}

// Overlay loading widget with blur effect
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final LoadingStyle style;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.style = LoadingStyle.orbital,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: (isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight)
                .withValues(alpha: 0.95),
            child: LoadingAnimation(message: message, style: style),
          ),
      ],
    );
  }
}
