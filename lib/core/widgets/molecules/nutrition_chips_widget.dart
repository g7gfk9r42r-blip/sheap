/// Nutrition Chips Widget
/// Zeigt Nährwerte als kompakte Chips mit Ranges
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../../data/models/recipe.dart';

class NutritionChipsWidget extends StatelessWidget {
  final RecipeNutritionRange? nutritionRange;
  final int? caloriesFallback; // Fallback wenn kein Range vorhanden

  const NutritionChipsWidget({
    super.key,
    this.nutritionRange,
    this.caloriesFallback,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    // Kalorien
    if (nutritionRange != null && nutritionRange!.caloriesDisplay.isNotEmpty) {
      chips.add(_buildChip(
        context,
        Icons.local_fire_department_rounded,
        '${nutritionRange!.caloriesDisplay} kcal',
      ));
    } else if (caloriesFallback != null) {
      chips.add(_buildChip(
        context,
        Icons.local_fire_department_rounded,
        '$caloriesFallback kcal',
      ));
    }

    // Protein
    if (nutritionRange != null && nutritionRange!.proteinDisplay.isNotEmpty) {
      chips.add(_buildChip(
        context,
        Icons.fitness_center_rounded,
        'Prot. ${nutritionRange!.proteinDisplay}',
      ));
    }

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: chips,
    );
  }

  Widget _buildChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelMedium(context).copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

