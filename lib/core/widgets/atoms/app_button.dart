/// Atomic Button Component
/// Große, touch-freundliche Buttons mit Varianten
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

enum AppButtonVariant {
  filled,
  outlined,
  text,
}

enum AppButtonSize {
  large,
  medium,
  small,
}

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton(
    this.label, {
    super.key,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.size = AppButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    if (variant == AppButtonVariant.filled) {
      return FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: foregroundColor ?? AppColors.onPrimary,
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          minimumSize: Size(double.infinity, _getHeight()),
        ),
        child: _buildContent(),
      );
    }

    if (variant == AppButtonVariant.outlined) {
      return OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor ?? AppColors.primary,
          side: BorderSide(
            color: backgroundColor ?? AppColors.primary,
            width: 1.5,
          ),
          padding: _getPadding(),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          minimumSize: Size(double.infinity, _getHeight()),
        ),
        child: _buildContent(),
      );
    }

    // Text button
    return TextButton(
      onPressed: isEnabled ? onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: foregroundColor ?? AppColors.primary,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        minimumSize: Size(double.infinity, _getHeight()),
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: _getIconSize(),
        width: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            foregroundColor ?? AppColors.onPrimary,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: _getFontSize(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Text(
      label,
      style: TextStyle(
        fontSize: _getFontSize(),
        fontWeight: FontWeight.w600,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        );
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        );
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        );
    }
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.large:
        return 56;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.small:
        return 40;
    }
  }

  double _getFontSize() {
    switch (size) {
      case AppButtonSize.large:
        return 16;
      case AppButtonSize.medium:
        return 14;
      case AppButtonSize.small:
        return 12;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.large:
        return 20;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.small:
        return 16;
    }
  }
}

