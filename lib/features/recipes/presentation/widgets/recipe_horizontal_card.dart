import 'package:flutter/material.dart';
import '../../../../data/models/recipe.dart';
import '../../../../core/widgets/molecules/recipe_preview_card.dart';

/// Horizontale Recipe Card für Supermarkt-Sektionen
class RecipeHorizontalCard extends StatelessWidget {
  const RecipeHorizontalCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return RecipePreviewCard(
      recipe: recipe,
      isFavorite: isFavorite,
      width: 180,
      height: 280,
      onTap: onTap,
      onFavoriteTap: onFavoriteTap,
    );
  }
}
