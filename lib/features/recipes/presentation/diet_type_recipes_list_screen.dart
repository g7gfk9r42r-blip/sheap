import 'package:flutter/material.dart';
import '../../../data/models/recipe.dart';
import '../../discover/recipe_detail_screen_new.dart';
import 'widgets/recipe_list_card.dart';

/// Screen für Rezepte einer Ernährungsweise mit zusätzlichen Filtern
class DietTypeRecipesListScreen extends StatefulWidget {
  const DietTypeRecipesListScreen({
    super.key,
    required this.dietType,
    required this.allRecipes,
    required this.favoriteIds,
    required this.onFavoriteTap,
  });

  final String dietType;
  final List<Recipe> allRecipes;
  final Set<String> favoriteIds;
  final Function(Recipe) onFavoriteTap;

  @override
  State<DietTypeRecipesListScreen> createState() => _DietTypeRecipesListScreenState();
}

class _DietTypeRecipesListScreenState extends State<DietTypeRecipesListScreen> {
  late List<Recipe> _filteredRecipes;
  Set<String> _selectedAdditionalDietTypes = {};
  
  final List<String> _additionalDietTypes = [
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
    _filterRecipes();
  }

  void _filterRecipes() {
    _filteredRecipes = widget.allRecipes.where((recipe) {
      final categories = recipe.categories ?? [];
      final tags = recipe.tags ?? [];
      final allTags = [...categories, ...tags].map((t) => t.toLowerCase()).toList();

      // Hauptfilter: Ernährungsweise
      bool matchesMainDiet = false;
      switch (widget.dietType) {
        case 'High Protein':
          matchesMainDiet = allTags.any((t) => t.contains('protein') || t.contains('eiweiß')) ||
                 (recipe.nutritionRange?.proteinMin ?? 0) >= 30;
          break;
        case 'Low Carb':
          matchesMainDiet = allTags.any((t) => t.contains('low carb') || t.contains('kohlenhydrat'));
          break;
        case 'Vegan':
          matchesMainDiet = allTags.any((t) => t.contains('vegan'));
          break;
        case 'Vegetarisch':
          matchesMainDiet = allTags.any((t) => t.contains('vegetarisch') || t.contains('vegetarian'));
          break;
        case 'Glutenfrei':
          matchesMainDiet = allTags.any((t) => t.contains('glutenfrei') || t.contains('gluten free'));
          break;
        case 'Laktosefrei':
          matchesMainDiet = allTags.any((t) => t.contains('laktosefrei') || t.contains('lactose free'));
          break;
        case 'Kalorienarm':
          matchesMainDiet = (recipe.calories ?? 999) < 400 ||
                 ((recipe.nutritionRange?.caloriesMax ?? 999) < 400);
          break;
        case 'High Calorie':
          matchesMainDiet = (recipe.calories ?? 0) > 600 ||
                 ((recipe.nutritionRange?.caloriesMin ?? 0) > 600);
          break;
        default:
          matchesMainDiet = false;
      }
      
      if (!matchesMainDiet) return false;

      // Zusätzliche Ernährungsweisen-Filter (mehrfache Auswahl)
      if (_selectedAdditionalDietTypes.isNotEmpty) {
        // Rezept muss alle ausgewählten Filter erfüllen
        for (final dietType in _selectedAdditionalDietTypes) {
          bool matchesAdditional = false;
          switch (dietType) {
            case 'Vegan':
              matchesAdditional = allTags.any((t) => t.contains('vegan'));
              break;
            case 'Vegetarisch':
              matchesAdditional = allTags.any((t) => t.contains('vegetarisch') || t.contains('vegetarian'));
              break;
            case 'Low Carb':
              matchesAdditional = allTags.any((t) => t.contains('low carb') || t.contains('kohlenhydrat'));
              break;
            case 'High Protein':
              matchesAdditional = allTags.any((t) => t.contains('protein') || t.contains('eiweiß')) ||
                     (recipe.nutritionRange?.proteinMin ?? 0) >= 30;
              break;
            case 'Glutenfrei':
              matchesAdditional = allTags.any((t) => t.contains('glutenfrei') || t.contains('gluten free'));
              break;
            case 'Laktosefrei':
              matchesAdditional = allTags.any((t) => t.contains('laktosefrei') || t.contains('lactose free'));
              break;
            case 'Kalorienarm':
              matchesAdditional = (recipe.calories ?? 999) < 400;
              break;
            case 'High Calorie':
              matchesAdditional = (recipe.calories ?? 0) > 600 ||
                     ((recipe.nutritionRange?.caloriesMin ?? 0) > 600);
              break;
          }
          if (!matchesAdditional) return false;
        }
      }

      return true;
    }).toList();

    // Sortiere nach Titel
    _filteredRecipes.sort((a, b) => a.title.compareTo(b.title));
  }

  String _getIcon(String dietType) {
    switch (dietType) {
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

  String _getTitle() {
    if (_selectedAdditionalDietTypes.isNotEmpty) {
      final additionalTypes = _selectedAdditionalDietTypes.join(' & ');
      return '${widget.dietType} & $additionalTypes';
    }
    return widget.dietType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              _getIcon(widget.dietType),
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getTitle(),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colors.surface,
      ),
      body: Column(
        children: [
          // Ernährungsweisen-Filter (wie im Recipes Screen)
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
                    itemCount: _additionalDietTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final dietType = _additionalDietTypes[index];
                      final isSelected = _selectedAdditionalDietTypes.contains(dietType);
                      return _DietTypeChip(
                        label: dietType,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAdditionalDietTypes.remove(dietType);
                            } else {
                              _selectedAdditionalDietTypes.add(dietType);
                            }
                            _filterRecipes();
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
            child: _filteredRecipes.isEmpty
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
                    'Keine Rezepte für\n${widget.dietType} vorhanden.',
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

/// Diet Type Filter Chip (wie im Recipes Screen)
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

