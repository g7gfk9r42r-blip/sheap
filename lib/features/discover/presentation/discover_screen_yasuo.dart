import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/recipe.dart';
import '../data/discover_repository.dart';
import '../data/favorite_recipes_storage.dart';
import '../models/recipe_week.dart';
import '../recipe_detail_screen_new.dart';
import '../widgets/recipe_week_carousel.dart';
import '../widgets/supermarket_recipe_row.dart';
import '../data/recipe_week_mock_data.dart'; // Mock-Daten

/// Yasuo-Style Discover Screen
/// 
/// Struktur:
/// 1. Header mit Titel "Entdecken" + Subtitel
/// 2. Rezepte-Wochen Carousel (horizontal swipeable)
/// 3. Supermarkt-Sektionen (vertikal, je Supermarkt horizontal scrollbare Rezepte)
class DiscoverScreenYasuo extends StatefulWidget {
  const DiscoverScreenYasuo({super.key});

  @override
  State<DiscoverScreenYasuo> createState() => _DiscoverScreenYasuoState();
}

class _DiscoverScreenYasuoState extends State<DiscoverScreenYasuo> {
  final DiscoverRepository _repository = const DiscoverRepository();
  FavoriteRecipesStorage? _favoriteStorage;
  
  bool _isLoading = true;
  List<RecipeWeek> _recipeWeeks = [];
  Set<String> _favoriteIds = {};
  
  // Gruppierte Rezepte nach Supermarkt
  Map<String, List<Recipe>> _recipesBySupermarket = {};

  // Alle unterstützten Supermärkte (aus MarketConstants)
  static const List<String> _supermarkets = [
    'REWE',
    'EDEKA',
    'LIDL',
    'ALDI Süd',
    'ALDI Nord',
    'NETTO',
    'PENNY',
    'NORMA',
    'KAUFLAND',
    'MARKTKAUF',
    'PLUS',
    'REAL',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Lade Rezepte
      final recipes = await _repository.fetchAllRecipes();
      
      // Lade Favoriten
      _favoriteStorage = await FavoriteRecipesStorage.create();
      final favorites = _favoriteStorage!.loadFavorites();
      
      // Gruppiere Rezepte nach Supermarkt
      final grouped = <String, List<Recipe>>{};
      for (final recipe in recipes) {
        final market = recipe.retailer;
        grouped.putIfAbsent(market, () => []).add(recipe);
      }
      
      // Generiere RecipeWeeks aus Rezepten (Mock-Daten für Demo)
      final weeks = RecipeWeekMockData.generateWeeksFromRecipes(recipes);

      if (mounted) {
        setState(() {
          _recipesBySupermarket = grouped;
          _recipeWeeks = weeks;
          _favoriteIds = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleRecipeTap(Recipe recipe) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreenNew(recipe: recipe),
      ),
    );
  }

  Future<void> _handleFavoriteTap(String recipeId) async {
    setState(() {
      if (_favoriteIds.contains(recipeId)) {
        _favoriteIds.remove(recipeId);
      } else {
        _favoriteIds.add(recipeId);
      }
    });

    // Persistiere Favoriten (saveFavorites expects Set, not List)
    await _favoriteStorage?.saveFavorites(_favoriteIds);
  }

  void _handleWeekTap(RecipeWeek week) {
    // Optional: Navigate to week detail or filter by week
    HapticFeedback.mediumImpact();
  }

  void _handleMoreTap(String supermarket) {
    // Optional: Navigate to supermarket detail screen
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      // Fix: Use colorScheme.background to provide appropriate background color throughout the app
      backgroundColor: colors.background,
      body: Container(
        color: colors.background,
        child: SafeArea(
          // Wrap [SafeArea] content with another container to explicitly set bg for slivers
          child: Container(
            color: colors.background,
            child: _isLoading
                ? _buildLoadingState(colors)
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Header
                      _buildHeader(theme, colors),
                      
                      // Recipe Weeks Carousel
                      if (_recipeWeeks.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24, bottom: 8),
                            child: RecipeWeekCarousel(
                              weeks: _recipeWeeks,
                              onWeekTap: _handleWeekTap,
                            ),
                          ),
                        ),
                      
                      // Supermarkt-Sektionen
                      ..._buildSupermarketSections(theme, colors),
                      
                      // Bottom spacing
                      const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    // Give the header a background that matches app bg for better visual separation
    return SliverToBoxAdapter(
      child: Container(
        color: colors.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entdecken',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Diese Woche für dich',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Optional: Filter Icon
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: colors.onSurface.withOpacity(0.7),
                ),
                onPressed: () {
                  // Optional: Filter Sheet öffnen
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSupermarketSections(ThemeData theme, ColorScheme colors) {
    final sections = <Widget>[];

    // Iteriere durch alle Supermärkte (in fester Reihenfolge)
    for (final supermarket in _supermarkets) {
      final recipes = _recipesBySupermarket[supermarket] ?? [];
      
      if (recipes.isNotEmpty) {
        sections.add(
          SliverToBoxAdapter(
            child: Container(
              color: colors.background,
              child: SupermarketRecipeRow(
                supermarketName: supermarket,
                recipes: recipes.take(10).toList(), // Max 10 pro Sektion
                isFavorite: (id) => _favoriteIds.contains(id),
                onRecipeTap: _handleRecipeTap,
                onFavoriteTap: _handleFavoriteTap,
                onMoreTap: () => _handleMoreTap(supermarket),
              ),
            ),
          ),
        );
      }
    }

    return sections;
  }

  Widget _buildLoadingState(ColorScheme colors) {
    // Set background of loading widget
    return Container(
      color: colors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: colors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Lade Rezepte...',
              style: TextStyle(
                color: colors.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
