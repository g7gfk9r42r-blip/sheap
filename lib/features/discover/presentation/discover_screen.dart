import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/models/recipe.dart';
import '../data/discover_repository.dart';
import '../data/favorite_recipes_storage.dart';
import '../recipe_detail_screen_new.dart';
import '../utils/market_constants.dart';
import '../widgets/recipe_card.dart';
import '../../recipes/weekly_recipes_screen.dart';

/// Discover Screen - Completely rebuilt with all 10 markets
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final DiscoverRepository _repository = const DiscoverRepository();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  
  Timer? _searchDebounce;
  FavoriteRecipesStorage? _favoriteStorage;

  bool _isLoading = true;
  String? _errorMessage;
  
  List<Recipe> _allRecipes = [];
  List<Recipe> _filteredRecipes = [];
  Set<String> _favoriteIds = {};

  String _selectedMarketKey = ''; // Empty = "Alle"
  String _selectedCategory = 'Alle';
  String _searchQuery = '';

  final List<String> _categories = [
    'Alle',
    'Schnell',
    'Budget',
    'High Protein',
    'Low Carb',
    'Vegetarisch',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final storage = await FavoriteRecipesStorage.create();
      final favorites = storage.loadFavorites();
      final recipes = await _repository.fetchAllRecipes();
      
      if (mounted) {
        setState(() {
          _favoriteStorage = storage;
          _favoriteIds = favorites;
          _allRecipes = recipes;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Fehler beim Laden der Rezepte: ${e.toString()}';
        });
      }
      debugPrint('Error loading recipes: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _searchQuery = _searchController.text.trim());
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    var recipes = List<Recipe>.from(_allRecipes);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      recipes = recipes.where((r) =>
        r.title.toLowerCase().contains(query) ||
        r.description.toLowerCase().contains(query) ||
        r.ingredients.any((i) => i.toLowerCase().contains(query))
      ).toList();
    }

    // Market filter
    if (_selectedMarketKey.isNotEmpty) {
      recipes = recipes.where((r) {
        final normalizedRetailer = MarketConstants.normalizeMarket(r.retailer);
        return normalizedRetailer == _selectedMarketKey;
      }).toList();
    }

    // Category filter
    if (_selectedCategory != 'Alle') {
      recipes = recipes.where((r) => _matchesCategory(r, _selectedCategory)).toList();
    }

    if (mounted) {
      setState(() => _filteredRecipes = recipes);
    }
  }

  bool _matchesCategory(Recipe recipe, String category) {
    switch (category) {
      case 'Schnell':
        return (recipe.durationMinutes ?? 999) <= 20;
      case 'Budget':
        return (recipe.price ?? 999) <= 5.0;
      case 'High Protein':
        return recipe.tags?.any((t) => 
          t.toLowerCase().contains('protein') || 
          t.toLowerCase().contains('eiweiß')
        ) ?? false;
      case 'Low Carb':
        return recipe.tags?.any((t) => 
          t.toLowerCase().contains('carb') || 
          t.toLowerCase().contains('kohlenhydrat')
        ) ?? false;
      case 'Vegetarisch':
        return !recipe.ingredients.any((i) => 
          i.toLowerCase().contains('fleisch') || 
          i.toLowerCase().contains('fisch') ||
          i.toLowerCase().contains('chicken')
        );
      default:
        return true;
    }
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

  void _resetFilters() {
    setState(() {
      _selectedMarketKey = '';
      _selectedCategory = 'Alle';
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: GestureDetector(
        onTap: () {
          // Unfocus when tapping outside
          _searchFocusNode.unfocus();
        },
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header - Pinned
              _buildSliverHeader(theme, colors),
              
              // Market Pills - Primary Filter
              _buildMarketPills(theme, colors),
              
              // Category Chips - Secondary Filter
              _buildCategoryChips(theme, colors),
              
              // Content
              if (_isLoading)
                _buildLoadingState(colors)
              else if (_errorMessage != null)
                _buildErrorState(theme, colors)
              else if (_filteredRecipes.isEmpty)
                _buildEmptyState(theme, colors)
              else
                _buildRecipeGrid(theme, colors),
              
              // Bottom spacing
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeData theme, ColorScheme colors) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      expandedHeight: 180,
      collapsedHeight: 100,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.zero,
        background: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colors.primaryContainer.withOpacity(0.08),
                colors.surfaceContainerLowest,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Title above search
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    colors.onSurface,
                    colors.primary,
                  ],
                ).createShader(bounds),
                child: Text(
                  'Entdecken',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.1,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Finde die besten Rezepte aus aktuellen Angeboten',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const WeeklyRecipesScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colors.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Woche',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSearchBar(theme, colors),
            ],
          ),
        ),
        expandedTitleScale: 1,
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, ColorScheme colors) {
    return AnimatedBuilder(
      animation: _searchFocusNode,
      builder: (context, child) {
        final isFocused = _searchFocusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isFocused 
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      colors.surfaceContainerLowest,
                    ],
                  )
                : null,
            color: isFocused ? null : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused 
                  ? colors.primary 
                  : colors.outlineVariant.withOpacity(0.4),
              width: isFocused ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isFocused 
                    ? colors.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isFocused ? 16 : 8,
                offset: Offset(0, isFocused ? 6 : 3),
                spreadRadius: isFocused ? 0 : -2,
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Suche Rezepte, Zutaten...',
              hintStyle: TextStyle(
                color: colors.onSurface.withOpacity(0.35),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 400),
                  turns: isFocused ? 0.5 : 0,
                  child: Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: isFocused 
                        ? colors.primary 
                        : colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          HapticFeedback.selectionClick();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: colors.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketPills(ThemeData theme, ColorScheme colors) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        decoration: BoxDecoration(
          color: colors.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Supermarkt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: MarketConstants.markets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final market = MarketConstants.markets[index];
                  final isActive = _selectedMarketKey == market.key;
                  
                  return _MarketPill(
                    market: market,
                    isActive: isActive,
                    colors: colors,
                    onTap: () {
                      setState(() => _selectedMarketKey = market.key);
                      _applyFilters();
                      HapticFeedback.mediumImpact();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeData theme, ColorScheme colors) {
    final hasActiveFilters = _selectedMarketKey.isNotEmpty || 
                            _selectedCategory != 'Alle' ||
                            _searchQuery.isNotEmpty;
    
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            bottom: BorderSide(
              color: colors.outlineVariant.withOpacity(0.15),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.category_rounded,
                      size: 20,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kategorie',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
                if (hasActiveFilters)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _resetFilters();
                        HapticFeedback.lightImpact();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Zurücksetzen',
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ..._categories.map((category) {
                  final isActive = _selectedCategory == category;
                  return _CategoryChip(
                    label: category,
                    isActive: isActive,
                    colors: colors,
                    onTap: () {
                      setState(() => _selectedCategory = category);
                      _applyFilters();
                      HapticFeedback.mediumImpact();
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeGrid(ThemeData theme, ColorScheme colors) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              // Result count header with badge
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_filteredRecipes.length}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _filteredRecipes.length == 1 ? 'Rezept' : 'Rezepte',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }
            
            final recipe = _filteredRecipes[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: RecipeCard(
                recipe: recipe,
                isFavorite: _favoriteIds.contains(recipe.id),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreenNew(recipe: recipe),
                    ),
                  );
                },
                onFavoriteTap: () => _toggleFavorite(recipe),
              ),
            );
          },
          childCount: _filteredRecipes.length + 1,
        ),
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme colors) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: CircularProgressIndicator(color: colors.primary),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colors) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: colors.error,
              ),
              const SizedBox(height: 20),
              Text(
                _errorMessage ?? 'Ein Fehler ist aufgetreten',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    final marketName = _selectedMarketKey.isNotEmpty
        ? MarketConstants.getDisplayName(_selectedMarketKey)
        : null;
    
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: colors.primary.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                marketName != null
                    ? 'Keine Rezepte für $marketName'
                    : 'Keine Rezepte gefunden',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                marketName != null
                    ? 'Für diesen Supermarkt sind aktuell keine Rezepte verfügbar.'
                    : 'Versuche andere Suchbegriffe oder Filter.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(marketName != null ? 'Alle Märkte anzeigen' : 'Filter zurücksetzen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Market pill without emoji
class _MarketPill extends StatefulWidget {
  const _MarketPill({
    required this.market,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final MarketInfo market;
  final bool isActive;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  State<_MarketPill> createState() => _MarketPillState();
}

class _MarketPillState extends State<_MarketPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          gradient: widget.isActive ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.colors.primary,
              widget.colors.primary.withOpacity(0.85),
            ],
          ) : null,
          color: widget.isActive
              ? null
              : widget.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isActive
                ? widget.colors.primary
                : widget.colors.outlineVariant.withOpacity(0.2),
            width: widget.isActive ? 0 : 1,
          ),
          boxShadow: widget.isActive ? [
            BoxShadow(
              color: widget.colors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          widget.market.displayName,
          style: TextStyle(
            fontSize: 14,
            fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
            color: widget.isActive
                ? widget.colors.onPrimary
                : widget.colors.onSurface.withOpacity(0.7),
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

/// Category filter chip
class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final ColorScheme colors;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0),
        decoration: BoxDecoration(
          color: widget.isActive
              ? widget.colors.primary.withOpacity(0.12)
              : widget.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isActive
                ? widget.colors.primary.withOpacity(0.4)
                : widget.colors.outlineVariant.withOpacity(0.15),
            width: widget.isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w600,
            color: widget.isActive
                ? widget.colors.primary
                : widget.colors.onSurface.withOpacity(0.7),
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
