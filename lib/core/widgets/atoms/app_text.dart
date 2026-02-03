/// Atomic Text Component
/// Konsistente Text-Darstellung mit Varianten
import 'package:flutter/material.dart';
import '../../theme/app_typography.dart';
import '../../theme/app_colors.dart';

enum AppTextVariant {
  displayLarge,
  headlineLarge,
  headlineMedium,
  titleLarge,
  titleMedium,
  titleSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  labelLarge,
  labelMedium,
  labelSmall,
}

class AppText extends StatelessWidget {
  final String text;
  final AppTextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final FontWeight? fontWeight;

  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(context).copyWith(
      color: color ?? _getDefaultColor(),
      fontWeight: fontWeight,
    );

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextStyle _getStyle(BuildContext context) {
    switch (variant) {
      case AppTextVariant.displayLarge:
        return AppTypography.displayLarge(context);
      case AppTextVariant.headlineLarge:
        return AppTypography.headlineLarge(context);
      case AppTextVariant.headlineMedium:
        return AppTypography.headlineMedium(context);
      case AppTextVariant.titleLarge:
        return AppTypography.titleLarge(context);
      case AppTextVariant.titleMedium:
        return AppTypography.titleMedium(context);
      case AppTextVariant.titleSmall:
        return AppTypography.titleSmall(context);
      case AppTextVariant.bodyLarge:
        return AppTypography.bodyLarge(context);
      case AppTextVariant.bodyMedium:
        return AppTypography.bodyMedium(context);
      case AppTextVariant.bodySmall:
        return AppTypography.bodySmall(context);
      case AppTextVariant.labelLarge:
        return AppTypography.labelLarge(context);
      case AppTextVariant.labelMedium:
        return AppTypography.labelMedium(context);
      case AppTextVariant.labelSmall:
        return AppTypography.labelSmall(context);
    }
  }

  Color _getDefaultColor() {
    switch (variant) {
      case AppTextVariant.displayLarge:
      case AppTextVariant.headlineLarge:
      case AppTextVariant.headlineMedium:
      case AppTextVariant.titleLarge:
      case AppTextVariant.titleMedium:
        return AppColors.textPrimary;
      case AppTextVariant.titleSmall:
      case AppTextVariant.bodyLarge:
      case AppTextVariant.bodyMedium:
        return AppColors.textPrimary;
      case AppTextVariant.bodySmall:
      case AppTextVariant.labelLarge:
      case AppTextVariant.labelMedium:
      case AppTextVariant.labelSmall:
        return AppColors.textSecondary;
    }
  }
}

