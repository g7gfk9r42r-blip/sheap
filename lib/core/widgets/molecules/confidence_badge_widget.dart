/// Confidence Badge Widget
/// Zeigt "Bitte prüfen" Badge für low-confidence Angebote
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class ConfidenceBadgeWidget extends StatelessWidget {
  final String? message; // Optional: custom message
  final bool isLowConfidence;

  const ConfidenceBadgeWidget({
    super.key,
    this.message,
    required this.isLowConfidence,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLowConfidence) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            message ?? 'Bitte prüfen',
            style: AppTypography.labelMedium(context).copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

