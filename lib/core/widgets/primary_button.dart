/// PrimaryButton
/// Haupt-CTA-Button mit Animation
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';

class PrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color? backgroundColor;
  final LinearGradient? gradient;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
    this.backgroundColor,
    this.gradient,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: GrocifyTheme.animationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    Widget button = Container(
      width: widget.fullWidth ? double.infinity : null,
      height: 56,
      decoration: BoxDecoration(
        color: widget.gradient == null
            ? (widget.backgroundColor ?? GrocifyTheme.primary)
            : null,
        gradient: widget.gradient ?? GrocifyTheme.primaryGradient,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: (widget.backgroundColor ?? GrocifyTheme.primary)
                      .withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: isEnabled ? _handleTapDown : null,
          onTapUp: isEnabled ? _handleTapUp : null,
          onTapCancel: isEnabled ? _handleTapCancel : null,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: GrocifyTheme.spaceSM),
                      ],
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    if (isEnabled) {
      button = ScaleTransition(
        scale: _scaleAnimation,
        child: button,
      );
    }

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: button,
    );
  }
}

