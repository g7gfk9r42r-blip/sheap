import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../data/models/recipe.dart';
import '../../../utils/tag_mapper.dart';
import '../../../core/widgets/molecules/recipe_image.dart';

/// High-quality recipe card for discover list (horizontal layout)
class RecipeCard extends StatefulWidget {
  const RecipeCard({
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
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _isPressed = false;

  String _getEmoji() {
    final title = widget.recipe.title.toLowerCase();
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

  List<String> _getMetaInfo() {
    final info = <String>[];
    if (widget.recipe.durationMinutes != null) {
      info.add('${widget.recipe.durationMinutes} Min');
    }
    if (widget.recipe.servings != null) {
      info.add('${widget.recipe.servings} Pers.');
    }
    // Preis wird jetzt separat angezeigt
    return info;
  }

  Widget _buildImageContainer(ColorScheme colors) {
    final imageUrl = widget.recipe.heroImageUrl;
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer.withOpacity(0.25),
            colors.secondaryContainer.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: RecipeImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: Center(
            child: Text(
              _getEmoji(),
              style: const TextStyle(fontSize: 52),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meta = _getMetaInfo();
    final availableNow = widget.recipe.isAvailableNow;
    final validLabel = widget.recipe.validFromUiLabel;

    return Opacity(
      opacity: availableNow ? 1.0 : 0.55,
      child: AbsorbPointer(
        absorbing: !availableNow,
        child: GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.outlineVariant.withOpacity(_isPressed ? 0.3 : 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(_isPressed ? 0.12 : 0.04),
              blurRadius: _isPressed ? 20 : 12,
              offset: Offset(0, _isPressed ? 6 : 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
              // Emoji/Image Container (left) - GRÖSSER
              Stack(
                children: [
                  _buildImageContainer(colors),
                  if (!availableNow && validLabel != null)
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _ValidFromPill(label: validLabel),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              
              // Content (middle)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title - GRÖSSER
                    Text(
                      widget.recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                        letterSpacing: -0.5,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Description (optional)
                    if (widget.recipe.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          widget.recipe.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface.withOpacity(0.65),
                            height: 1.4,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    
                    // Meta Info Row (Zeit, Portionen)
                    if (meta.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: meta.map((m) => _MetaChip(
                                label: m,
                                colors: colors,
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    // Tags/Hashtags (diet_categories) - besser aufgeteilt
                    Builder(
                      builder: (context) {
                        final tags = widget.recipe.tags ?? [];
                        final hashtags = TagMapper.getTopTags(tags);
                        if (hashtags.isEmpty) return const SizedBox.shrink();
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: hashtags.map((hashtag) {
                                // Liste der Supermärkte (kleingeschrieben für Vergleich)
                                final supermarkets = ['kaufland', 'lidl', 'rewe', 'aldi', 'netto', 'penny', 'norma', 'nahkauf', 'tegut', 'edeka', 'denns', 'biomarkt'];
                                // Entferne # falls vorhanden und prüfe ob Supermarkt
                                final hashtagLower = hashtag.replaceFirst('#', '').toLowerCase();
                                final isSupermarket = supermarkets.any((s) => hashtagLower.contains(s));
                                // Wenn Supermarkt, großschreiben
                                final displayText = isSupermarket ? hashtag.replaceFirst('#', '').toUpperCase() : hashtag;
                                
                                return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: colors.primary.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                    displayText,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                    
                    // Preis-Block (neues Format mit strikethrough)
                    
                    
                    // Market Badge - GRÖSSER
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.recipe.retailer.toUpperCase(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Favorite Button (right) - GRÖSSER
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onFavoriteTap,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.isFavorite
                              ? colors.primaryContainer.withOpacity(0.6)
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.isFavorite
                                ? colors.primary.withOpacity(0.4)
                                : colors.outlineVariant.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          widget.isFavorite ? Icons.bookmark : Icons.bookmark_outline,
                          size: 24,
                          color: widget.isFavorite
                              ? colors.primary
                              : colors.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      ),
      ),
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
          fontWeight: FontWeight.w800,
          color: colors.onSurface.withOpacity(0.85),
        ),
      ),
    );
  }
}

/// Compact meta chip - GRÖSSER
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.colors,
  });

  final String label;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 14,
            color: colors.onSurface.withOpacity(0.6),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colors.onSurface.withOpacity(0.7),
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (label.contains('Min')) return Icons.schedule_outlined;
    if (label.contains('Pers')) return Icons.people_outline;
    if (label.contains('kcal')) return Icons.local_fire_department_outlined;
    if (label.contains('€')) return Icons.euro_outlined;
    return Icons.info_outline;
  }
}
