/// GrocifyCard
/// Wiederverwendbare Karte mit einheitlichem Design
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';

class GrocifyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GrocifyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.onTap,
    this.elevation,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? GrocifyTheme.surface) : null,
        gradient: gradient,
        borderRadius: borderRadius ?? BorderRadius.circular(GrocifyTheme.radiusXL),
        border: border,
        boxShadow: boxShadow ??
            (elevation != null
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(GrocifyTheme.spaceLG),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(GrocifyTheme.radiusXL),
        child: card,
      );
    }

    return card;
  }
}

