/// Ingredient List Organism
/// Zeigt Zutaten mit Angeboten (nur bei Rezept-Details)
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../atoms/app_text.dart';
import '../molecules/offer_badge.dart';

class IngredientItem {
  final String name;
  final double? price;
  final String? retailer;
  final String? unit;

  const IngredientItem({
    required this.name,
    this.price,
    this.retailer,
    this.unit,
  });
}

class IngredientList extends StatelessWidget {
  final List<IngredientItem> ingredients;
  final String? sectionTitle;

  const IngredientList({
    super.key,
    required this.ingredients,
    this.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sectionTitle != null) ...[
          AppText(
            sectionTitle!,
            variant: AppTextVariant.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...ingredients.map((ingredient) => _buildIngredientItem(context, ingredient)),
      ],
    );
  }

  Widget _buildIngredientItem(BuildContext context, IngredientItem ingredient) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          // Checkbox
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          // Ingredient Name
          Expanded(
            child: AppText(
              ingredient.name,
              variant: AppTextVariant.bodyLarge,
            ),
          ),
          // Offer Badge (wenn Preis vorhanden)
          if (ingredient.price != null && ingredient.price! > 0) ...[
            const SizedBox(width: AppSpacing.md),
            OfferBadge(
              amount: ingredient.price!,
              showIcon: false,
            ),
            if (ingredient.retailer != null && ingredient.retailer!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.xs),
              AppText(
                '(${ingredient.retailer})',
                variant: AppTextVariant.bodySmall,
                color: AppColors.textSecondary,
              ),
            ],
          ] else if (ingredient.retailer != null && ingredient.retailer!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.md),
            AppText(
              ingredient.retailer!,
              variant: AppTextVariant.bodySmall,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

