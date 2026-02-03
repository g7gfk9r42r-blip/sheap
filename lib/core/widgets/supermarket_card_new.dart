/// SupermarketCardNew
/// Moderne Supermarkt-Karte für Home-Screen
import 'package:flutter/material.dart';
import '../theme/grocify_theme.dart';
import 'grocify_card.dart';

class SupermarketCardNew extends StatelessWidget {
  final String name;
  final String emoji;
  final int recipeCount;
  final double? savings;
  final Color color;
  final VoidCallback onTap;

  const SupermarketCardNew({
    super.key,
    required this.name,
    required this.emoji,
    required this.recipeCount,
    this.savings,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GrocifyCard(
      onTap: onTap,
      margin: const EdgeInsets.only(
        left: GrocifyTheme.screenPadding,
        right: GrocifyTheme.screenPadding,
        bottom: GrocifyTheme.spaceLG,
      ),
      gradient: LinearGradient(
        colors: [
          color,
          color.withOpacity(0.8),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 40),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: GrocifyTheme.spaceMD,
                  vertical: GrocifyTheme.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(GrocifyTheme.radiusRound),
                ),
                child: Text(
                  '$recipeCount Rezepte',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GrocifyTheme.spaceLG),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          if (savings != null) ...[
            const SizedBox(height: GrocifyTheme.spaceSM),
            Row(
              children: [
                const Icon(
                  Icons.savings_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '€${savings!.toStringAsFixed(2)} sparen',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

