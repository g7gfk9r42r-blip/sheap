/// Premium Recipe Card
/// Modern, clean design with savings badge
import 'package:flutter/material.dart';
import '../../theme/grocify_theme.dart';

class RecipeCardPremium extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final double? priceEstimate;
  final double? savings;
  final int? durationMinutes;
  final int? servings;
  final String? supermarket;
  final VoidCallback onTap;

  const RecipeCardPremium({
    super.key,
    required this.title,
    this.imageUrl,
    this.priceEstimate,
    this.savings,
    this.durationMinutes,
    this.servings,
    this.supermarket,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: GrocifyTheme.spaceLG),
        decoration: BoxDecoration(
          color: GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
          boxShadow: GrocifyTheme.shadowSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(GrocifyTheme.radiusXXL),
                topRight: Radius.circular(GrocifyTheme.radiusXXL),
              ),
              child: Container(
                height: 180,
                width: double.infinity,
                color: GrocifyTheme.surfaceSubtle,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GrocifyTheme.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: GrocifyTheme.spaceMD),
                  // Meta info row
                  Row(
                    children: [
                      if (durationMinutes != null) ...[
                        _buildMetaChip(
                          Icons.access_time_rounded,
                          '$durationMinutes Min',
                        ),
                        const SizedBox(width: GrocifyTheme.spaceMD),
                      ],
                      if (servings != null) ...[
                        _buildMetaChip(
                          Icons.people_rounded,
                          '$servings Pers',
                        ),
                        const SizedBox(width: GrocifyTheme.spaceMD),
                      ],
                      if (priceEstimate != null)
                        _buildMetaChip(
                          Icons.euro_rounded,
                          '${priceEstimate!.toStringAsFixed(2)} €',
                        ),
                    ],
                  ),
                  if (savings != null && savings! > 0) ...[
                    const SizedBox(height: GrocifyTheme.spaceMD),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: GrocifyTheme.spaceMD,
                        vertical: GrocifyTheme.spaceSM,
                      ),
                      decoration: BoxDecoration(
                        color: GrocifyTheme.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.savings_rounded,
                            size: 16,
                            color: GrocifyTheme.success,
                          ),
                          const SizedBox(width: GrocifyTheme.spaceXS),
                          Text(
                            '${savings!.toStringAsFixed(2)} € gespart',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GrocifyTheme.success,
                            ),
                          ),
                        ],
                      ),
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
      color: GrocifyTheme.surfaceSubtle,
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 48,
          color: GrocifyTheme.textTertiary,
        ),
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: GrocifyTheme.textSecondary,
        ),
        const SizedBox(width: GrocifyTheme.spaceXS),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: GrocifyTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

