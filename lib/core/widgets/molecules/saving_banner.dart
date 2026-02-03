/// Saving Banner Molecule
/// Prominenter Spar-Banner für Home Screen (Gamification)
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../atoms/app_text.dart';

class SavingBanner extends StatelessWidget {
  final double amount;
  final double? percentageChange;
  final VoidCallback? onTap;

  const SavingBanner({
    super.key,
    required this.amount,
    this.percentageChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: AppColors.savingGradient,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.savings_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Diese Woche gespart',
                    variant: AppTextVariant.bodySmall,
                    color: AppColors.secondary.withOpacity(0.8),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppText(
                    '${amount.toStringAsFixed(2)} €',
                    variant: AppTextVariant.headlineLarge,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w700,
                  ),
                  if (percentageChange != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          percentageChange! > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 14,
                          color: AppColors.secondary.withOpacity(0.8),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppText(
                          '${percentageChange!.abs().toStringAsFixed(0)}% vs. letzte Woche',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.secondary.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.secondary.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

