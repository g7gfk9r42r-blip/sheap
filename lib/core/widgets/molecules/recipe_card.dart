/// Recipe Card Molecule
/// Große, bildlastige Rezept-Karte mit Spar-Highlight
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../atoms/app_text.dart';
import 'offer_badge.dart';
import 'recipe_image.dart';

class RecipeCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final double? savingAmount;
  final double? rating;
  final int? durationMinutes;
  final int? servings;
  final VoidCallback? onTap;

  const RecipeCard({
    super.key,
    required this.title,
    this.imageUrl,
    this.savingAmount,
    this.rating,
    this.durationMinutes,
    this.servings,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.border, width: 1),
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              child: RecipeImage(
                imageUrl: imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: _buildPlaceholder(),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  AppText(
                    title,
                    variant: AppTextVariant.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Meta Info Row
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppText(
                          rating!.toStringAsFixed(1),
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      if (durationMinutes != null) ...[
                        Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppText(
                          '$durationMinutes Min',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                        if (servings != null) const SizedBox(width: AppSpacing.md),
                      ],
                      if (servings != null) ...[
                        Icon(
                          Icons.people_rounded,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppText(
                          '$servings Pers',
                          variant: AppTextVariant.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ],
                  ),

                  // Saving Badge
                  if (savingAmount != null && savingAmount! > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    OfferBadge(
                      amount: savingAmount!,
                      showIcon: true,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      color: AppColors.surfaceVariant,
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 48,
        color: AppColors.textTertiary,
      ),
    );
  }
}

