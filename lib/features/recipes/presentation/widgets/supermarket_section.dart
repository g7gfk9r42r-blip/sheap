import 'package:flutter/material.dart';
import '../../../../data/models/recipe.dart';
import 'recipe_horizontal_card.dart';

/// Supermarkt-Sektion mit horizontaler Rezept-Liste und "Mehr"-Button
class SupermarketSection extends StatelessWidget {
  const SupermarketSection({
    super.key,
    required this.supermarketName,
    required this.emoji,
    required this.recipes,
    required this.favoriteIds,
    required this.onRecipeTap,
    required this.onFavoriteTap,
    required this.onMoreTap,
  });

  final String supermarketName;
  final String emoji;
  final List<Recipe> recipes;
  final Set<String> favoriteIds;
  final void Function(Recipe) onRecipeTap;
  final void Function(Recipe) onFavoriteTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Zeige max. 3 Rezepte in der horizontalen Liste
    final displayRecipes = recipes.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header mit Supermarkt-Name und "Mehr"-Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              supermarketName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (recipes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 34, top: 4),
                          child: Text(
                            'Verfügbare Rezepte: ${recipes.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onMoreTap,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    minimumSize: const Size(70, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Mehr',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Horizontale Rezept-Liste
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: displayRecipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final recipe = displayRecipes[index];
                return RecipeHorizontalCard(
                  recipe: recipe,
                  isFavorite: favoriteIds.contains(recipe.id),
                  onTap: () => onRecipeTap(recipe),
                  onFavoriteTap: () => onFavoriteTap(recipe),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

