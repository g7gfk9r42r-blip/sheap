/// Premium Supermarket Card
/// Swipeable card with gradient background
import 'package:flutter/material.dart';
import '../../theme/grocify_theme.dart';

class SupermarketCard extends StatelessWidget {
  final String name;
  final String logo; // Emoji or icon
  final int recipeCount;
  final double savings;
  final Color? gradientColor;
  final VoidCallback onTap;

  const SupermarketCard({
    super.key,
    required this.name,
    required this.logo,
    required this.recipeCount,
    required this.savings,
    this.gradientColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = gradientColor != null
        ? LinearGradient(
            colors: [gradientColor!, gradientColor!.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : GrocifyTheme.primaryGradient;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: GrocifyTheme.screenPadding,
        ),
        padding: const EdgeInsets.all(GrocifyTheme.spaceXXL),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
          boxShadow: GrocifyTheme.shadowMD,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                  ),
                  child: Text(logo, style: const TextStyle(fontSize: 32)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GrocifyTheme.spaceLG,
                    vertical: GrocifyTheme.spaceMD,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(
                      GrocifyTheme.radiusRound,
                    ),
                  ),
                  child: Text(
                    '$recipeCount Rezepte',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GrocifyTheme.spaceXXL),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.2,
              ),
            ),
            const SizedBox(height: GrocifyTheme.spaceMD),
            Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: GrocifyTheme.spaceSM),
                Text(
                  '${savings.toStringAsFixed(2)} € sparen',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
