import 'package:flutter/material.dart';

class SpeedDialMenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  SpeedDialMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class SpeedDialMenu extends StatefulWidget {
  final List<SpeedDialMenuItem> items;
  final IconData? closedIcon;
  final IconData? openIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const SpeedDialMenu({
    super.key,
    required this.items,
    this.closedIcon = Icons.menu,
    this.openIcon = Icons.close,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<SpeedDialMenu> createState() => _SpeedDialMenuState();
}

class _SpeedDialMenuState extends State<SpeedDialMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _handleItemTap(VoidCallback onTap) {
    setState(() => _isExpanded = false);
    _animationController.reverse();
    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Animated menu items
        if (_isExpanded)
          ...List.generate(
            widget.items.length,
            (index) => _buildAnimatedMenuItem(widget.items[index], index),
          ),
        // Main FAB
        FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.foregroundColor,
          onPressed: _toggleMenu,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 250),
            child: Icon(_isExpanded ? widget.openIcon : widget.closedIcon),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedMenuItem(SpeedDialMenuItem item, int index) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          index * 0.1,
          0.5 + (index * 0.1),
          curve: Curves.easeOut,
        ),
      ),
      child: FadeTransition(
        opacity: _animation,
        child: Padding(
          padding: EdgeInsets.only(bottom: 70.0 + (index * 65.0)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FloatingActionButton(
                heroTag: 'speed_dial_${item.label}_$index',
                mini: true,
                backgroundColor: item.color,
                onPressed: () => _handleItemTap(item.onTap),
                child: Icon(item.icon, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
