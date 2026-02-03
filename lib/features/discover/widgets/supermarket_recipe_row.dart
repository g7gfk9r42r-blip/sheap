import 'package:flutter/material.dart';
import '../../../data/models/recipe.dart';
import 'yasuo_recipe_card.dart';

/// Horizontale scrollbare Rezept-Liste für einen Supermarkt (Yasuo-Style)
/// Zeigt Supermarkt-Titel, "Mehr"-Button und horizontal scrollbare Recipe Cards
class SupermarketRecipeRow extends StatelessWidget {
  const SupermarketRecipeRow({
    super.key,
    required this.supermarketName,
    required this.recipes,
    required this.isFavorite,
    required this.onRecipeTap,
    required this.onFavoriteTap,
    this.onMoreTap,
  });

  final String supermarketName;
  final List<Recipe> recipes;
  final bool Function(String recipeId) isFavorite;
  final ValueChanged<Recipe> onRecipeTap;
  final ValueChanged<String> onFavoriteTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    if (recipes.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Supermarkt-Name + "Mehr"-Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$supermarketName Rezepte',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (recipes.isNotEmpty)
                      Text(
                        'Verfügbare Rezepte: ${recipes.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (onMoreTap != null)
                TextButton(
                  onPressed: onMoreTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mehr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Horizontal scrollbare Recipe Cards
        SizedBox(
          height: 280, // Höhe der Cards + Padding
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Padding(
                padding: EdgeInsets.only(right: index < recipes.length - 1 ? 16 : 0),
                child: YasuoRecipeCard(
                  recipe: recipe,
                  isFavorite: isFavorite(recipe.id),
                  onTap: () => onRecipeTap(recipe),
                  onFavoriteTap: () => onFavoriteTap(recipe.id),
                  width: 180,
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 32), // Abstand zur nächsten Sektion
      ],
    );
  }
}
