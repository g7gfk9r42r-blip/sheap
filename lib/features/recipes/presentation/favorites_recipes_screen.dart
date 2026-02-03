import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/recipe.dart';
import '../../discover/recipe_detail_screen_new.dart';
import 'widgets/recipe_list_card.dart';

/// Favoriten-Screen - Zeigt alle favorisierten Rezepte
class FavoritesRecipesScreen extends StatefulWidget {
  const FavoritesRecipesScreen({
    super.key,
    required this.favoriteIds,
    required this.allRecipes,
    required this.onFavoriteTap,
  });

  final Set<String> favoriteIds;
  final List<Recipe> allRecipes;
  final Function(Recipe) onFavoriteTap;

  @override
  State<FavoritesRecipesScreen> createState() => _FavoritesRecipesScreenState();
}

class _FavoritesRecipesScreenState extends State<FavoritesRecipesScreen> {
  List<Recipe> _favoriteRecipes = [];

  @override
  void initState() {
    super.initState();
    _loadFavoriteRecipes();
  }

  void _loadFavoriteRecipes() {
    // Filtere Rezepte: ALLE Favoriten
    final newFavoriteRecipes = widget.allRecipes
        .where((recipe) => widget.favoriteIds.contains(recipe.id))
        .toList();

    // Sortiere nach Datum (neueste zuerst)
    newFavoriteRecipes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    if (mounted) {
      setState(() {
        _favoriteRecipes = newFavoriteRecipes;
      });
    } else {
      _favoriteRecipes = newFavoriteRecipes;
    }
  }

  void _handleFavoriteTap(Recipe recipe) {
    HapticFeedback.selectionClick();
    // Toggle Favorite
    widget.onFavoriteTap(recipe);
    // Warte kurz, dann aktualisiere die Liste
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _loadFavoriteRecipes();
      }
    });
  }

  @override
  void didUpdateWidget(FavoritesRecipesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.favoriteIds != widget.favoriteIds ||
        oldWidget.allRecipes != widget.allRecipes) {
      _loadFavoriteRecipes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    
    // Aktualisiere Rezepte wenn sich Favoriten ändern
    if (widget.favoriteIds.length != _favoriteRecipes.length ||
        !_favoriteRecipes.every((r) => widget.favoriteIds.contains(r.id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFavoriteRecipes();
      });
    }

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFE91E63), // Rot
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Deine Favoriten'),
          ],
        ),
        elevation: 0,
        backgroundColor: colors.surface,
      ),
      body: _favoriteRecipes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFEC4899).withOpacity(0.2),
                            const Color(0xFFF472B6).withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.favorite_border_rounded,
                        size: 80,
                        color: const Color(0xFFEC4899).withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Noch keine Favoriten ✨',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        'Markiere Rezepte als Favorit, um sie hier zu sehen.\n\nKlicke einfach auf das Herz-Icon bei jedem Rezept! 💖',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colors.onSurface.withOpacity(0.6),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _favoriteRecipes.length,
              itemBuilder: (context, index) {
                final recipe = _favoriteRecipes[index];
                final isFavorite = widget.favoriteIds.contains(recipe.id);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: RecipeListCard(
                    recipe: recipe,
                    isFavorite: isFavorite,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecipeDetailScreenNew(recipe: recipe),
                        ),
                      );
                    },
                    onFavoriteTap: () {
                      _handleFavoriteTap(recipe);
                    },
                  ),
                );
              },
            ),
    );
  }
}

