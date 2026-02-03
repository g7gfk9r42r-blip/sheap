import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/recipe.dart';
import '../../../data/repositories/cached_recipe_repository.dart';
import '../data/favorite_recipes_storage.dart';
import 'supermarket_recipes_list_screen.dart';
import 'favorites_recipes_screen.dart';
import '../../discover/recipe_detail_screen_new.dart';
import 'widgets/recipe_hero_card.dart';
import 'widgets/supermarket_section.dart';
import 'diet_type_recipes_list_screen.dart';
import '../../auth/data/auth_service_local.dart';
import '../../auth/data/models/user_account.dart';
import '../domain/recipe_ranking_service.dart';
import '../domain/recipe_personalization_service.dart';
import '../../../core/widgets/empty_state.dart';

/// Recipes Screen - Haupt-Screen für Rezepte mit Filtern, Suche und Supermarkt-Sektionen
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  FavoriteRecipesStorage? _favoriteStorage;

  Set<String> _favoriteIds = {};
  String _searchQuery = '';
  late final Future<
    ({
      List<Recipe> recipes,
      UserAccount? user,
      RecipePersonalizationPrefs prefs,
      String prefsSource,
    })
  >
  _loadFuture;

  // Ernährungsweisen-Filter
  static const List<String> _dietTypes = [
    'High Protein',
    'Low Carb',
    'Vegan',
    'Vegetarisch',
    'Glutenfrei',
    'Laktosefrei',
    'Kalorienarm',
    'High Calorie',
  ];

  /// Generiert Supermarkt-Liste dynamisch aus geladenen Rezepten
  /// Verwendet canonical Market-Keys (Ordnername aus assets/prospekte/<market>/)
  static List<Map<String, String>> _buildSupermarketsFromRecipes(
    List<Recipe> recipes,
  ) {
    // Sammle alle eindeutigen Markets aus Rezepten
    final marketSet = <String>{};
    for (final recipe in recipes) {
      final market = recipe.market?.toLowerCase().trim();
      if (market != null && market.isNotEmpty) {
        marketSet.add(market);
        continue;
      }
      // Fallback: some legacy recipes only have retailer set
      final retailer = recipe.retailer.toLowerCase().trim();
      if (retailer.isNotEmpty) {
        marketSet.add(retailer);
      }
    }

    // Konvertiere zu Liste und sortiere alphabetisch
    // Keep a stable, user-friendly order (matches backend folder names)
    const preferredOrder = [
      'lidl',
      'rewe',
      'aldi_nord',
      'aldi_sued',
      'kaufland',
      'netto',
      'penny',
      'norma',
      'nahkauf',
      'tegut',
      'biomarkt',
    ];
    final markets = marketSet.toList()
      ..sort((a, b) {
        final ia = preferredOrder.indexOf(a);
        final ib = preferredOrder.indexOf(b);
        if (ia == -1 && ib == -1) return a.compareTo(b);
        if (ia == -1) return 1;
        if (ib == -1) return -1;
        return ia.compareTo(ib);
      });

    // Erstelle Supermarkt-Map mit Display-Namen
    return markets.map((marketKey) {
      // Display-Name: Erste Buchstaben groß, Unterstriche durch Leerzeichen ersetzen
      final displayName = marketKey
          .split('_')
          .map(
            (word) =>
                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
          )
          .join(' ');

      return {
        'name': displayName,
        'market':
            marketKey, // Canonical Market-Key (z.B. "biomarkt", "aldi_sued")
        'emoji': '🛒',
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadAll();
    _searchController.addListener(_handleSearchChange);
    _loadFavorites();
  }

  Future<
    ({
      List<Recipe> recipes,
      UserAccount? user,
      RecipePersonalizationPrefs prefs,
      String prefsSource,
    })
  >
  _loadAll() async {
    final recipesFuture = CachedRecipeRepository.instance.loadAllCached();
    final userFuture = AuthServiceLocal.instance.getCurrentUser();
    final results = await Future.wait([recipesFuture, userFuture]);
    final recipes = results[0] as List<Recipe>;
    final user = results[1] as UserAccount?;
    if (user == null) {
      return (
        recipes: recipes,
        user: null,
        prefs: RecipePersonalizationPrefs.none,
        prefsSource: 'default',
      );
    }
    final p = await RecipePersonalizationService.instance.loadPrefsForUid(
      user.uid,
    );
    return (
      recipes: recipes,
      user: user,
      prefs: p.prefs,
      prefsSource: p.source,
    );
  }

  Future<void> _loadFavorites() async {
    final storage = await FavoriteRecipesStorage.create();
    final favorites = storage.loadFavorites();
    if (mounted) {
      setState(() {
        _favoriteStorage = storage;
        _favoriteIds = favorites;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  List<Recipe> _getFilteredRecipes(List<Recipe> recipes) {
    var filtered = recipes;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((recipe) {
        final titleMatch = recipe.title.toLowerCase().contains(_searchQuery);
        final ingredientMatch = recipe.ingredients.any(
          (ing) => ing.toLowerCase().contains(_searchQuery),
        );
        return titleMatch || ingredientMatch;
      }).toList();
    }

    return filtered;
  }

  /// Filtert Rezepte für einen bestimmten Market
  /// Verwendet canonical Market-Key (z.B. "biomarkt", "aldi_sued")
  List<Recipe> _getRecipesForSupermarket(
    List<Recipe> allRecipes,
    String marketKey,
  ) {
    final marketKeyLower = marketKey.toLowerCase().trim();

    final supermarketRecipes = allRecipes.where((recipe) {
      // Verwende recipe.market (canonical Key) als primäre Quelle
      final recipeMarket = recipe.market?.toLowerCase().trim();
      if (recipeMarket != null && recipeMarket == marketKeyLower) {
        return true;
      }

      // Fallback: recipe.retailer (für Kompatibilität)
      final recipeRetailer = recipe.retailer.toLowerCase().trim();
      return recipeRetailer == marketKeyLower;
    }).toList();

    return _getFilteredRecipes(supermarketRecipes);
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final updated = Set<String>.from(_favoriteIds);
    if (updated.contains(recipe.id)) {
      updated.remove(recipe.id);
    } else {
      updated.add(recipe.id);
      HapticFeedback.lightImpact();
    }
    setState(() => _favoriteIds = updated);
    await _favoriteStorage?.saveFavorites(updated);
  }

  void _toggleDietType(String dietType) async {
    // Navigiere zu Diet Type Recipes List statt zu filtern
    final recipes = await CachedRecipeRepository.instance.loadAllCached();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DietTypeRecipesListScreen(
          dietType: dietType,
          allRecipes: recipes,
          favoriteIds: _favoriteIds,
          onFavoriteTap: _toggleFavorite,
        ),
      ),
    );
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          'Rezepte',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        elevation: 0,
        backgroundColor: colors.surface,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.favorite_rounded, color: colors.primary),
              onPressed: () async {
                final recipes = await CachedRecipeRepository.instance
                    .loadAllCached();
                if (!context.mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FavoritesRecipesScreen(
                      favoriteIds: _favoriteIds,
                      allRecipes: recipes,
                      onFavoriteTap: _toggleFavorite,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body:
          FutureBuilder<
            ({
              List<Recipe> recipes,
              UserAccount? user,
              RecipePersonalizationPrefs prefs,
              String prefsSource,
            })
          >(
            future: _loadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const EmptyState(
                  emoji: '😵‍💫',
                  title: 'Rezepte konnten nicht geladen werden',
                  description: 'Bitte versuche es später erneut.',
                );
              }

              final data = snapshot.data;
              final allRecipes = data?.recipes ?? <Recipe>[];
              var filteredRecipes = _getFilteredRecipes(allRecipes);

              if (allRecipes.isEmpty) {
                return const EmptyState(
                  emoji: '📦',
                  title: 'Keine Rezepte gefunden',
                  description: 'Es sind aktuell keine Rezepte verfügbar.',
                );
              }

              // Ranking: AFTER filtering, BEFORE featured=first
              final user = data?.user;
              if (user != null) {
                final ranker = RecipeRankingService.instance;
                filteredRecipes = filteredRecipes.toList()
                  ..sort((a, b) {
                    final sa = ranker.score(a, user.profile);
                    final sb = ranker.score(b, user.profile);
                    final byScore = sb.compareTo(sa);
                    if (byScore != 0) return byScore;
                    return a.title.compareTo(b.title);
                  });
              }

              // Personalization (stable): Vegan -> vegan first; Vegetarian -> vegetarian+vegan first.
              final prefs = data?.prefs ?? RecipePersonalizationPrefs.none;
              final prefsSource = data?.prefsSource ?? 'default';
              final personalized = RecipePersonalizationService.instance
                  .personalize(
                    recipes: filteredRecipes,
                    prefs: prefs,
                    source: prefsSource,
                  );
              filteredRecipes = personalized.recipes;

              if (filteredRecipes.isEmpty) {
                return EmptyState(
                  emoji: '🔎',
                  title: 'Keine Treffer',
                  description: 'Versuche einen anderen Suchbegriff.',
                  ctaLabel: 'Suche zurücksetzen',
                  onCtaTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                );
              }

              final featured = filteredRecipes.isNotEmpty
                  ? filteredRecipes.first
                  : null;

              // Dynamisch Supermärkte aus geladenen Rezepten generieren
              final supermarkets = _buildSupermarketsFromRecipes(allRecipes);

              return GestureDetector(
                onTap: () => _searchFocusNode.unfocus(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Ernährungsweisen-Filter
                    _buildDietTypeFilters(theme, colors),

                    // Search Bar
                    _buildSearchBar(theme, colors),

                    // Hero: Rezepte der Woche
                    if (featured != null)
                      SliverToBoxAdapter(
                        child: RecipeHeroCard(
                          recipe: featured,
                          isFavorite: _favoriteIds.contains(featured.id),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailScreenNew(recipe: featured),
                              ),
                            );
                          },
                          onFavoriteTap: () => _toggleFavorite(featured),
                        ),
                      ),

                    // Supermarkt-Sektionen (dynamisch generiert)
                    ...supermarkets.map((supermarket) {
                      final marketKey = supermarket['market']!;
                      // Important: use the already ranked + personalized order (stable).
                      final recipes = _getRecipesForSupermarket(
                        filteredRecipes,
                        marketKey,
                      );
                      if (recipes.isEmpty) {
                        return const SliverToBoxAdapter(
                          child: SizedBox.shrink(),
                        );
                      }

                      return SliverToBoxAdapter(
                        child: SupermarketSection(
                          supermarketName: supermarket['name']!,
                          emoji: supermarket['emoji']!,
                          recipes: recipes,
                          favoriteIds: _favoriteIds,
                          onRecipeTap: (recipe) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RecipeDetailScreenNew(recipe: recipe),
                              ),
                            );
                          },
                          onFavoriteTap: _toggleFavorite,
                          onMoreTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => SupermarketRecipesListScreen(
                                  supermarketName: supermarket['name']!,
                                  retailer:
                                      marketKey, // Canonical Market-Key verwenden
                                  favoriteIds: _favoriteIds,
                                  onFavoriteTap: _toggleFavorite,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }),

                    // Bottom spacing
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildDietTypeFilters(ThemeData theme, ColorScheme colors) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ernährungsweisen',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _dietTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final dietType = _dietTypes[index];
                  // Keine Auswahl mehr - alle Chips navigieren
                  return _DietTypeChip(
                    label: dietType,
                    isSelected: false,
                    onTap: () => _toggleDietType(dietType),
                    colors: colors,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colors) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchFocusNode.hasFocus
                  ? colors.primary
                  : colors.outlineVariant.withOpacity(0.2),
              width: _searchFocusNode.hasFocus ? 2.5 : 1,
            ),
            boxShadow: _searchFocusNode.hasFocus
                ? [
                    BoxShadow(
                      color: colors.primary.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: colors.shadow.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Rezepte oder Zutaten suchen',
              hintStyle: TextStyle(
                color: colors.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.search_rounded,
                  color: _searchFocusNode.hasFocus
                      ? colors.primary
                      : colors.onSurface.withOpacity(0.6),
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: colors.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Diet Type Filter Chip
class _DietTypeChip extends StatelessWidget {
  const _DietTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colors;

  String _getIcon(String label) {
    switch (label) {
      case 'High Protein':
        return '💪';
      case 'Low Carb':
        return '🥑';
      case 'Vegan':
        return '🌱';
      case 'Vegetarisch':
        return '🥕';
      case 'Glutenfrei':
        return '🌾';
      case 'Laktosefrei':
        return '🥛';
      case 'Kalorienarm':
        return '⚡';
      case 'High Calorie':
        return '🔥';
      default:
        return '✓';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.outlineVariant.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getIcon(label), style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? colors.onPrimaryContainer
                    : colors.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
