/// Grocify UI Components
/// Wiederverwendbare Komponenten basierend auf GrocifyTheme
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';

/// Standard Card-Komponente mit Theme-Styling
class GrocifyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final Border? border;

  const GrocifyCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
    this.borderRadius,
    this.boxShadow,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(GrocifyTheme.spaceLG),
      decoration: BoxDecoration(
        color: backgroundColor ?? GrocifyTheme.surface,
        borderRadius: BorderRadius.circular(
          borderRadius ?? GrocifyTheme.radiusXL,
        ),
        border: border,
        boxShadow: boxShadow ?? GrocifyTheme.shadowMD,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          borderRadius ?? GrocifyTheme.radiusXL,
        ),
        child: card,
      );
    }

    return card;
  }
}

/// Button-Komponente mit Varianten
enum GrocifyButtonVariant {
  primary,
  secondary,
  ghost,
}

class GrocifyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final GrocifyButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  const GrocifyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = GrocifyButtonVariant.primary,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (variant == GrocifyButtonVariant.primary) {
      return FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: GrocifyTheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: GrocifyTheme.spaceXL,
            vertical: GrocifyTheme.spaceLG,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
          ),
        ),
        child: _buildContent(),
      );
    }

    if (variant == GrocifyButtonVariant.secondary) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: GrocifyTheme.primary,
          side: const BorderSide(
            color: GrocifyTheme.primary,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GrocifyTheme.spaceXL,
            vertical: GrocifyTheme.spaceLG,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
          ),
        ),
        child: _buildContent(),
      );
    }

    // Ghost variant
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: GrocifyTheme.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: GrocifyTheme.spaceXL,
          vertical: GrocifyTheme.spaceLG,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
        ),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: GrocifyTheme.spaceSM),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Badge-Komponente für kleine Labels (kcal, Preis, Ersparnis)
class GrocifyBadge extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const GrocifyBadge(
    this.label, {
    super.key,
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GrocifyTheme.spaceSM,
        vertical: GrocifyTheme.spaceXS,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? GrocifyTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(GrocifyTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: textColor ?? GrocifyTheme.textSecondary,
            ),
            const SizedBox(width: GrocifyTheme.spaceXS),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor ?? GrocifyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

