import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../../data/models/recipe.dart';
import 'recipe_image.dart';

/// Clean, modern Recipe Preview Card für Grid/Horizontal Lists
/// Zeigt: Bild/Emoji-Platzhalter, Name, Herz-Icon (Favorite), 3 Kategorien-Chips, Supermarkt-Badge
class RecipePreviewCard extends StatefulWidget {
  const RecipePreviewCard({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
    this.width,
    this.height,
  });

  final Recipe recipe;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;
  final double? width;
  final double? height;

  @override
  State<RecipePreviewCard> createState() => _RecipePreviewCardState();
}

class _RecipePreviewCardState extends State<RecipePreviewCard> {
  String _getEmojiForRecipe(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('pasta') || lower.contains('nudel') || lower.contains('spaghetti')) return '🍝';
    if (lower.contains('salat') || lower.contains('salad')) return '🥗';
    if (lower.contains('curry')) return '🍛';
    if (lower.contains('hähnchen') || lower.contains('chicken') || lower.contains('huhn')) return '🍗';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('burger')) return '🍔';
    if (lower.contains('sushi')) return '🍣';
    if (lower.contains('taco')) return '🌮';
    if (lower.contains('bowl')) return '🥙';
    if (lower.contains('suppe') || lower.contains('soup')) return '🍲';
    if (lower.contains('reis') || lower.contains('rice')) return '🍚';
    if (lower.contains('frühstück') || lower.contains('breakfast') || lower.contains('müsli')) return '🥣';
    if (lower.contains('fisch') || lower.contains('fish')) return '🐟';
    if (lower.contains('ei') || lower.contains('egg')) return '🍳';
    if (lower.contains('dessert') || lower.contains('kuchen') || lower.contains('cake')) return '🍰';
    return '🍽️';
  }

  /// Baut das Rezeptbild - verwendet image Schema (NEU) oder heroImageUrl (DEPRECATED)
  /// 
  /// Unterstützte Sources:
  /// - 'shutterstock': Lädt Bild von Shutterstock URL
  /// - 'ai_generated' oder 'asset': Lädt Asset aus app bundle
  /// - 'none': Zeigt Emoji-Placeholder
  Widget _buildRecipeImage({
    required String? imageUrl,
    required String recipeTitle,
    required double imageHeight,
    Map<String, dynamic>? imageSchema,
    String? retailer,
    String? recipeId,
  }) {
    // Release builds: recipe images are remote-first (keeps AAB < 200MB).
    // If we have a URL/path, render it directly (asset OR network).
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return RecipeImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: _EmojiPlaceholder(
          emoji: _getEmojiForRecipe(recipeTitle),
          size: imageHeight * 0.5,
        ),
        errorWidget: _EmojiPlaceholder(
          emoji: _getEmojiForRecipe(recipeTitle),
          size: imageHeight * 0.5,
        ),
      );
    }

    // NEU: Verwende image Schema wenn verfügbar
    if (imageSchema != null) {
      final source = imageSchema['source']?.toString();
      final status = imageSchema['status']?.toString();
      final assetPath = imageSchema['asset_path']?.toString();
      final shutterstockUrl = imageSchema['shutterstock_url']?.toString();
      
      // Shutterstock: Lade von URL
      if (source == 'shutterstock' && status == 'ready' && shutterstockUrl != null && shutterstockUrl.isNotEmpty) {
        return Image.network(
          shutterstockUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _EmojiPlaceholder(
              emoji: _getEmojiForRecipe(recipeTitle),
              size: imageHeight * 0.5,
            );
          },
        );
      }
      
      // Asset (OHNE weekKey): Nutze AssetIndexService für robustes Laden
      if ((source == 'asset' || source == 'ai_generated') && 
          status == 'ready' && 
          assetPath != null && 
          assetPath.isNotEmpty) {
        // FIX: Verwende asset_path direkt (wurde bereits korrekt aufgelöst)
        // asset_path enthält jetzt den korrekten Pfad aus heroImageUrl
        final finalPath = assetPath;
        
        // ✅ BEWEIS: Logge eindeutig ob Image.asset erfolgreich rendert
        if (kDebugMode) {
          debugPrint('🖼️  RecipePreviewCard Image.asset RENDER:');
          debugPrint('   Path: $finalPath');
          debugPrint('   RecipeId: $recipeId');
          debugPrint('   Retailer: $retailer');
          debugPrint('   ImageSchema source: $source');
        }
        
        // We no longer ship recipe images inside the app bundle by default.
        // If an asset path is given, try the equivalent remote URL; else fall back to emoji.
        final networkUrl = _convertToNetworkUrl(finalPath);
        if (networkUrl != null) {
          return RecipeImage(
            imageUrl: networkUrl,
            fit: BoxFit.cover,
            placeholder: _EmojiPlaceholder(
              emoji: _getEmojiForRecipe(recipeTitle),
              size: imageHeight * 0.5,
            ),
            errorWidget: _EmojiPlaceholder(
              emoji: _getEmojiForRecipe(recipeTitle),
              size: imageHeight * 0.5,
            ),
          );
        }
        return _EmojiPlaceholder(
          emoji: _getEmojiForRecipe(recipeTitle),
          size: imageHeight * 0.5,
        );
      }
    }
    
    // DEPRECATED: Fallback zu heroImageUrl
    if (imageUrl == null || imageUrl.isEmpty) {
      return _EmojiPlaceholder(
        emoji: _getEmojiForRecipe(recipeTitle),
        size: imageHeight * 0.5,
      );
    }
    
    // Prüfe ob es ein Asset-Pfad ist
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Logge nur bei kritischen Fehlern (Asset-Fehler sind normal wenn nicht vorhanden)
          // Keine Debug-Logs für Asset-Fehler, um Console sauber zu halten
          // Fallback: Versuche Network-URL
          final networkUrl = _convertToNetworkUrl(imageUrl);
          if (networkUrl != null) {
            return Image.network(
              networkUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _EmojiPlaceholder(
                  emoji: _getEmojiForRecipe(recipeTitle),
                  size: imageHeight * 0.5,
                );
              },
            );
          }
          return _EmojiPlaceholder(
            emoji: _getEmojiForRecipe(recipeTitle),
            size: imageHeight * 0.5,
          );
        },
      );
    } else {
      // Network-URL (http:// oder https://)
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Logge nur bei ersten Fehlern (nicht bei jedem - zu viele Logs)
          // Network-Fehler sind normal wenn Server nicht läuft
          
          // Fallback: Versuche Asset-Pfad
          final assetPath = _convertToAssetPath(imageUrl);
          if (assetPath != null) {
            return Image.asset(
              assetPath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _EmojiPlaceholder(
                  emoji: _getEmojiForRecipe(recipeTitle),
                  size: imageHeight * 0.5,
                );
              },
            );
          }
          
          return _EmojiPlaceholder(
            emoji: _getEmojiForRecipe(recipeTitle),
            size: imageHeight * 0.5,
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
      );
    }
  }

  /// Konvertiert Asset-Pfad zu Network-URL (Fallback)
  String? _convertToNetworkUrl(String assetPath) {
    // assets/recipe_images/aldi_nord/R000.webp -> http://localhost:3000/media/recipe_images/aldi_nord/R000.webp
    if (assetPath.startsWith('assets/recipe_images/')) {
      final relativePath = assetPath.replaceFirst('assets/', '');
      final envBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();
      final baseUrl = (envBase.isNotEmpty ? envBase : (kReleaseMode ? '' : 'http://localhost:3000')).trim();
      if (baseUrl.isEmpty) return null;
      // Server serves under /media/...
      return '$baseUrl/media/$relativePath';
    }
    return null;
  }

  /// Konvertiert Network-URL zu Asset-Pfad (Fallback)
  String? _convertToAssetPath(String networkUrl) {
    // http://localhost:3000/media/recipe_images/aldi_nord/R000.webp -> assets/recipe_images/aldi_nord/R000.webp
    if (networkUrl.contains('/recipe_images/')) {
      final parts = networkUrl.split('/recipe_images/');
      if (parts.length > 1) {
        return 'assets/recipe_images/${parts[1]}';
      }
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cardHeight = widget.height ?? 240;
    final imageHeight = (cardHeight * 0.45).clamp(90.0, 120.0);
    final availableNow = widget.recipe.isAvailableNow;
    final validLabel = widget.recipe.validFromUiLabel;

    return Opacity(
      opacity: availableNow ? 1.0 : 0.55,
      child: AbsorbPointer(
        absorbing: !availableNow,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
        width: widget.width,
        height: cardHeight,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.outlineVariant.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bild/Emoji-Platzhalter oben
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Container(
                    height: imageHeight,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.primaryContainer.withOpacity(0.6),
                          colors.secondaryContainer.withOpacity(0.4),
                          colors.tertiaryContainer.withOpacity(0.3),
                        ],
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Bild oder Emoji (NEU: image Schema hat Priorität)
                        _buildRecipeImage(
                          imageUrl: widget.recipe.heroImageUrl,
                          recipeTitle: widget.recipe.title,
                          imageHeight: imageHeight,
                          imageSchema: widget.recipe.image,
                          retailer: widget.recipe.retailer,
                          recipeId: widget.recipe.id,
                        ),
                        if (!availableNow && validLabel != null)
                          Positioned(
                            left: 12,
                            bottom: 12,
                            child: _ValidFromPill(label: validLabel),
                          ),
                        // Gradient Overlay für bessere Lesbarkeit
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.05),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Content-Bereich
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Title (mit Platz für Heart-Icon)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 32),
                            child: Text(
                              widget.recipe.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                height: 1.3,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        
                        const Spacer(),
                        
                        // Supermarkt-Badge
                        if (widget.recipe.retailer.isNotEmpty)
                          _MarketBadge(
                            retailer: widget.recipe.retailer,
                            colors: colors,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Herz-Icon oben rechts (über Bild)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onFavoriteTap();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.surface.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withOpacity(0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: widget.isFavorite ? colors.error : colors.onSurface.withOpacity(0.7),
                  ),
                ),
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

/// Emoji-Platzhalter für Rezepte ohne Bild
class _EmojiPlaceholder extends StatelessWidget {
  const _EmojiPlaceholder({
    required this.emoji,
    required this.size,
  });

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: size),
      ),
    );
  }
}

/// Supermarkt-Badge
class _MarketBadge extends StatelessWidget {
  const _MarketBadge({
    required this.retailer,
    required this.colors,
  });

  final String retailer;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_rounded,
            size: 13,
            color: colors.onSurface.withOpacity(0.75),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              retailer.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: colors.onSurface.withOpacity(0.85),
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

