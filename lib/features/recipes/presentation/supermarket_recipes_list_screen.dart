import 'package:flutter/material.dart';
import '../../../data/models/recipe.dart';
import '../../../data/repositories/recipe_repository.dart';
import '../../discover/recipe_detail_screen_new.dart';
import 'widgets/recipe_list_card.dart';

/// Screen für Rezepte eines einzelnen Supermarkts mit Ernährungsweisen-Filter
class SupermarketRecipesListScreen extends StatefulWidget {
  const SupermarketRecipesListScreen({
    super.key,
    required this.supermarketName,
    required this.retailer,
    required this.favoriteIds,
    required this.onFavoriteTap,
  });

  final String supermarketName;
  final String retailer;
  final Set<String> favoriteIds;
  final Function(Recipe) onFavoriteTap;

  @override
  State<SupermarketRecipesListScreen> createState() =>
      _SupermarketRecipesListScreenState();
}

class _SupermarketRecipesListScreenState
    extends State<SupermarketRecipesListScreen> {
  List<Recipe> _recipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  Set<String> _selectedDietTypes = {};
  
  final List<String> _dietTypes = [
    'Vegan',
    'Vegetarisch',
    'Low Carb',
    'High Protein',
    'Glutenfrei',
    'Laktosefrei',
    'Kalorienarm',
    'High Calorie',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      final recipes = await RecipeRepository.loadRecipesFromAssets(widget.retailer);
      if (mounted) {
        setState(() {
          _recipes = recipes;
          _filteredRecipes = recipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyDietTypeFilter() {
    if (_selectedDietTypes.isEmpty) {
      setState(() {
        _filteredRecipes = _recipes;
      });
      return;
    }

    setState(() {
      _filteredRecipes = _recipes.where((recipe) {
        final categories = recipe.categories ?? [];
        final tags = recipe.tags ?? [];
        final allTags = [...categories, ...tags].map((t) => t.toLowerCase()).toList();

        // Prüfe ob Rezept mindestens eine der ausgewählten Ernährungsweisen erfüllt
        for (final dietType in _selectedDietTypes) {
          bool matches = false;
          switch (dietType) {
            case 'Vegan':
              matches = allTags.any((t) => t.contains('vegan'));
              break;
            case 'Vegetarisch':
              matches = allTags.any((t) => t.contains('vegetarisch') || t.contains('vegetarian'));
              break;
            case 'Low Carb':
              matches = allTags.any((t) => t.contains('low carb') || t.contains('kohlenhydrat'));
              break;
            case 'High Protein':
              matches = allTags.any((t) => t.contains('protein') || t.contains('eiweiß')) ||
                     (recipe.nutritionRange?.proteinMin ?? 0) >= 30;
              break;
            case 'Glutenfrei':
              matches = allTags.any((t) => t.contains('glutenfrei') || t.contains('gluten free'));
              break;
            case 'Laktosefrei':
              matches = allTags.any((t) => t.contains('laktosefrei') || t.contains('lactose free'));
              break;
            case 'Kalorienarm':
              matches = (recipe.calories ?? 999) < 400;
              break;
            case 'High Calorie':
              matches = (recipe.calories ?? 0) > 600 ||
                     ((recipe.nutritionRange?.caloriesMin ?? 0) > 600);
              break;
          }
          if (matches) return true;
        }
        return false;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.supermarketName),
            if (!_isLoading && _recipes.isNotEmpty)
              Text(
                'Verfügbare Rezepte: ${_recipes.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        elevation: 0,
        backgroundColor: colors.surface,
      ),
      body: Column(
        children: [
          // Ernährungsweisen-Filter (farbenfroh mit Emojis)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
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
                      final isSelected = _selectedDietTypes.contains(dietType);
                      return _DietTypeFilterChip(
                        label: dietType,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDietTypes.remove(dietType);
                            } else {
                              _selectedDietTypes.add(dietType);
                            }
                            _applyDietTypeFilter();
                          });
                        },
                        colors: colors,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Recipe List
          Expanded(
            child: _isLoading
          ? const Center(child: CircularProgressIndicator())
                : _filteredRecipes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu_rounded,
                        size: 64,
                        color: colors.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Für ${widget.supermarketName} sind aktuell\nkeine Rezepte vorhanden.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _filteredRecipes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RecipeListCard(
                        recipe: recipe,
                        isFavorite: widget.favoriteIds.contains(recipe.id),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RecipeDetailScreenNew(recipe: recipe),
                                  ),
                                );
                              },
                        onFavoriteTap: () => widget.onFavoriteTap(recipe),
                              ),
                            );
                          },
                      ),
                    ),
                  ],
                ),
    );
  }
}

/// Farbenfroher Diet Type Filter Chip mit Emojis
class _DietTypeFilterChip extends StatelessWidget {
  const _DietTypeFilterChip({
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

  Color _getColor(String label) {
    switch (label) {
      case 'High Protein':
        return const Color(0xFF3B82F6); // Blue
      case 'Low Carb':
        return const Color(0xFF10B981); // Green
      case 'Vegan':
        return const Color(0xFF059669); // Emerald
      case 'Vegetarisch':
        return const Color(0xFFF59E0B); // Amber
      case 'Glutenfrei':
        return const Color(0xFF8B5CF6); // Purple
      case 'Laktosefrei':
        return const Color(0xFFEC4899); // Pink
      case 'Kalorienarm':
        return const Color(0xFF06B6D4); // Cyan
      case 'High Calorie':
        return const Color(0xFFF97316); // Orange
      default:
        return colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _getColor(label);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    chipColor,
                    chipColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? chipColor
                : colors.outlineVariant.withOpacity(0.3),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _getIcon(label),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : colors.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
                ),
    );
  }
}
