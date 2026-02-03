import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/recipe.dart';

/// Yasuo-Style Recipe Card
/// - Großes Bild oben
/// - Herz-Icon (Favorit) oben rechts
/// - Rezeptname, kcal, Zeit unter dem Bild
/// - Abgerundete Ecken (16-20px)
/// - Weiche Schatten
class YasuoRecipeCard extends StatefulWidget {
  const YasuoRecipeCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
    this.width = 180,
  });

  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final double width;

  @override
  State<YasuoRecipeCard> createState() => _YasuoRecipeCardState();
}

class _YasuoRecipeCardState extends State<YasuoRecipeCard> {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticFeedback.lightImpact();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withOpacity(0.08),
                blurRadius: _isPressed ? 16 : 12,
                offset: Offset(0, _isPressed ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    // Background Image (Gradient mit Emoji als Fallback)
                    Container(
                      width: double.infinity,
                      height: widget.width * 0.75, // 3:4 Aspect Ratio
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
                      child: Center(
                        child: Text(
                          _getEmoji(),
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                    
                    // Favorite Button (oben rechts)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onFavoriteTap();
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colors.surface.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colors.shadow.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 20,
                            color: widget.isFavorite
                                ? colors.error
                                : colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recipe Name
                    Text(
                      widget.recipe.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    
                    // Meta Info Row (kcal, Zeit)
                    Row(
                      children: [
                        if (widget.recipe.calories != null) ...[
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.recipe.calories} kcal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (widget.recipe.calories != null &&
                            widget.recipe.durationMinutes != null)
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
                        if (widget.recipe.durationMinutes != null) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 16,
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.recipe.durationMinutes} min',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
