import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../../data/models/recipe.dart';
import '../../../../utils/tag_mapper.dart';
import '../../../../core/widgets/molecules/recipe_image.dart';

/// Recipe Card für vertikale Listen (SupermarketRecipesListScreen)
class RecipeListCard extends StatelessWidget {
  const RecipeListCard({
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

  Widget _buildRecipeImage() {
    final imageUrl = recipe.heroImageUrl;
    return RecipeImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: Center(
        child: Text(
          _getEmoji(),
          style: const TextStyle(fontSize: 52),
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

    final card = Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            child: Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer.withOpacity(0.6),
                        colors.secondaryContainer.withOpacity(0.4),
                      ],
                    ),
                  ),
                  child: _buildRecipeImage(),
                ),
                if (!availableNow && validLabel != null)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _ValidFromPill(label: validLabel),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Title + Favorite
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onFavoriteTap();
                          },
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 22,
                            color: isFavorite ? colors.error : colors.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Tags/Hashtags (besser aufgeteilt)
                    Builder(
                      builder: (context) {
                        final tags = recipe.tags ?? [];
                        final hashtags = TagMapper.getTopTags(tags);
                        if (hashtags.isEmpty) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: hashtags.map((hashtag) {
                              // Liste der Supermärkte (kleingeschrieben für Vergleich)
                              final supermarkets = ['kaufland', 'lidl', 'rewe', 'aldi', 'netto', 'penny', 'norma', 'nahkauf', 'tegut', 'edeka', 'denns', 'biomarkt'];
                              // Entferne # falls vorhanden und prüfe ob Supermarkt
                              final hashtagLower = hashtag.replaceFirst('#', '').toLowerCase();
                              final isSupermarket = supermarkets.any((s) => hashtagLower.contains(s));
                              // Wenn Supermarkt, großschreiben
                              final displayText = isSupermarket ? hashtag.replaceFirst('#', '').toUpperCase() : hashtag;
                              
                              return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colors.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                  displayText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colors.primary,
                                ),
                              ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    // Meta Info (Zeit + Portionen)
                    Row(
                      children: [
                        if (recipe.durationMinutes != null) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.durationMinutes} Min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (recipe.durationMinutes != null && recipe.servings != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.onSurface.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        if (recipe.servings != null) ...[
                          Icon(
                            Icons.people_rounded,
                            size: 16,
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.servings} Pers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Markt/Retailer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.store_rounded,
                            size: 14,
                            color: colors.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            recipe.retailer.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: colors.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Opacity(
      opacity: availableNow ? 1.0 : 0.55,
      child: AbsorbPointer(
        absorbing: !availableNow,
        child: GestureDetector(
          onTap: onTap,
          child: card,
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: colors.onSurface.withOpacity(0.8),
        ),
      ),
    );
  }
}

