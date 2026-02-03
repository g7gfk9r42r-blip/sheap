import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/models/recipe.dart';
import '../../../../core/widgets/molecules/recipe_image.dart';

/// Hero Card für "Rezepte der Woche" - großes Bild, Titel, kcal, Zeit
class RecipeHeroCard extends StatelessWidget {
  const RecipeHeroCard({
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

  String _getEmoji() {
    final title = recipe.title.toLowerCase();
    if (title.contains('pasta') || title.contains('spaghetti') || title.contains('nudel')) return '🍝';
    if (title.contains('curry')) return '🍛';
    if (title.contains('salad') || title.contains('salat')) return '🥗';
    if (title.contains('chicken') || title.contains('hähnchen') || title.contains('huhn')) return '🍗';
    if (title.contains('fish') || title.contains('fisch')) return '🐟';
    if (title.contains('burger')) return '🍔';
    if (title.contains('pizza')) return '🍕';
    if (title.contains('soup') || title.contains('suppe')) return '🍲';
    if (title.contains('rice') || title.contains('reis')) return '🍚';
    if (title.contains('egg') || title.contains('ei')) return '🍳';
    return '🍽️';
  }

  Widget _buildRecipeImage(String imageUrl) {
    return RecipeImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: Center(
        child: Text(
          _getEmoji(),
          style: const TextStyle(fontSize: 80),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableNow = recipe.isAvailableNow;
    final validLabel = recipe.validFromUiLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⭐ Rezept der Woche',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Opacity(
            opacity: availableNow ? 1.0 : 0.55,
            child: AbsorbPointer(
              absorbing: !availableNow,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Image
                    Container(
                      width: double.infinity,
                      height: 280,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.primaryContainer.withOpacity(0.6),
                            colors.secondaryContainer.withOpacity(0.4),
                            colors.tertiaryContainer.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: recipe.heroImageUrl != null && recipe.heroImageUrl!.isNotEmpty
                          ? _buildRecipeImage(recipe.heroImageUrl!)
                          : Center(
                              child: Text(
                                _getEmoji(),
                                style: const TextStyle(fontSize: 80),
                              ),
                            ),
                    ),
                    if (!availableNow && validLabel != null)
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: _ValidFromPill(label: validLabel),
                      ),

                    // Favorite Button (oben rechts)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onFavoriteTap();
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.surface.withOpacity(0.95),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 24,
                            color: isFavorite ? colors.error : colors.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),

                    // Content Overlay (unten)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipe.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (recipe.calories != null) ...[
                                  Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 20,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${recipe.calories} kcal',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                if (recipe.calories != null &&
                                    recipe.durationMinutes != null)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                if (recipe.durationMinutes != null) ...[
                                  Icon(
                                    Icons.schedule_rounded,
                                    size: 20,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${recipe.durationMinutes} Min',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Supermarkt unten klein
                            if (recipe.retailer.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                recipe.retailer.toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidFromPill extends StatelessWidget {
  final String label;
  const _ValidFromPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: colors.onSurface.withOpacity(0.85),
        ),
      ),
    );
  }
}

