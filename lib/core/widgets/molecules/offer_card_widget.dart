/// Offer Card Widget
/// Zeigt ein Angebot mit klarer Preis-Darstellung
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../data/models/offer.dart';
import 'price_block_widget.dart';
import 'confidence_badge_widget.dart';

class OfferCardWidget extends StatelessWidget {
  final Offer offer;
  final VoidCallback? onTap;

  const OfferCardWidget({
    super.key,
    required this.offer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Confidence Badge (falls low confidence)
            if (offer.isLowConfidence) ...[
              Row(
                children: [
                  ConfidenceBadgeWidget(isLowConfidence: true),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            
            // Titel und Marke
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titel
                      Text(
                        offer.title,
                        style: AppTypography.titleMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Marke (falls vorhanden)
                      if (offer.brand != null && offer.brand!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          offer.brand!,
                          style: AppTypography.bodySmall(context).copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppSpacing.md),
            
            // Preis-Block
            PriceBlockWidget(
              standardPrice: offer.standardPriceValue > 0 ? offer.standardPriceValue : null,
              loyaltyPrice: offer.loyaltyPriceValue,
              loyaltyCondition: offer.condition?.label ?? offer.loyaltyPrice?.condition,
              unit: offer.unit,
              originalPrice: offer.originalPrice,
            ),
            
            // Menge (falls vorhanden)
            if (offer.unit != null && offer.unit!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                offer.unit!,
                style: AppTypography.bodySmall(context).copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

