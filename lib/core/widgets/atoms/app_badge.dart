/// Atomic Badge Component
/// Für Labels, Tags, Status-Anzeigen
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';


enum AppBadgeVariant {
  primary,
  secondary,
  success,
  warning,
  error,
}

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;

  const AppBadge(
    this.label, {
    super.key,
    this.variant = AppBadgeVariant.primary,
    this.icon,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? _getBackgroundColor();
    final fgColor = textColor ?? _getTextColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (variant) {
      case AppBadgeVariant.primary:
        return AppColors.primaryContainer;
      case AppBadgeVariant.secondary:
        return AppColors.secondaryContainer;
      case AppBadgeVariant.success:
        return AppColors.savingBackground;
      case AppBadgeVariant.warning:
        return AppColors.warning.withOpacity(0.1);
      case AppBadgeVariant.error:
        return AppColors.error.withOpacity(0.1);
    }
  }

  Color _getTextColor() {
    switch (variant) {
      case AppBadgeVariant.primary:
        return AppColors.primary;
      case AppBadgeVariant.secondary:
        return AppColors.secondary;
      case AppBadgeVariant.success:
        return AppColors.success;
      case AppBadgeVariant.warning:
        return AppColors.warning;
      case AppBadgeVariant.error:
        return AppColors.error;
    }
  }
}

