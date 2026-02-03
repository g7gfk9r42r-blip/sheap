/// Loyalty Badge Widget
/// Zeigt Badge für benötigte Karte/Bonus/App
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class LoyaltyBadgeWidget extends StatelessWidget {
  final String condition; // z.B. "Mit K-Card", "Mit REWE Bonus"
  final String? conditionType; // "card", "bonus", "app"

  const LoyaltyBadgeWidget({
    super.key,
    required this.condition,
    this.conditionType,
  });

  IconData get _icon {
    switch (conditionType) {
      case 'card':
        return Icons.card_membership_rounded;
      case 'bonus':
        return Icons.stars_rounded;
      case 'app':
        return Icons.phone_android_rounded;
      default:
        return Icons.card_membership_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            condition,
            style: AppTypography.labelMedium(context).copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

