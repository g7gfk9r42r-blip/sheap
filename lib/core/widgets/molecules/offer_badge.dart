/// Offer Badge Molecule
/// Zeigt Spar-Betrag prominent an (Gamification)
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../atoms/app_text.dart';

class OfferBadge extends StatelessWidget {
  final double amount;
  final bool showIcon;
  final String? label;

  const OfferBadge({
    super.key,
    required this.amount,
    this.showIcon = false,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.savingGradient,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.savings_rounded,
              size: 16,
              color: AppColors.secondary,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          AppText(
            label ?? '${amount.toStringAsFixed(2)} € gespart',
            variant: AppTextVariant.labelMedium,
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

