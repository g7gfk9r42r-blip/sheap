/// Plan Screen - Grocify Wochenplan (Modernized UI)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/grocify_theme.dart';
import '../../data/models/recipe.dart';
import '../../data/services/meal_plan_service.dart';
import '../../data/repositories/cached_recipe_repository.dart';
import '../../utils/week.dart';
import '../discover/recipe_detail_screen_new.dart';
import '../recipes/presentation/recipes_screen.dart';

class PlanScreenNew extends StatefulWidget {
  const PlanScreenNew({super.key});

  @override
  State<PlanScreenNew> createState() => _PlanScreenNewState();
}

class _PlanScreenNewState extends State<PlanScreenNew> {
  int _selectedDayIndex = 0;
  final MealPlanService _mealPlanService = MealPlanService.instance;
  int _mealsPerDay = 3; // Default: 3 meals per day

  final List<String> _weekdays = const [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];

  final List<String> _weekdaysShort = const [
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So',
  ];

  @override
  void initState() {
    super.initState();
    _mealPlanService.addListener(_onPlanChanged);
  }
  
  @override
  void dispose() {
    _mealPlanService.removeListener(_onPlanChanged);
    super.dispose();
  }
  
  void _onPlanChanged() {
    setState(() {});
  }
  
  /// Get the Monday of the current week
  DateTime _getWeekStart() {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }
  
  DateTime _getDateForIndex(int index) {
    final weekStart = _getWeekStart();
    return weekStart.add(Duration(days: index));
  }
  
  String _getWeekLabel() {
    final weekStart = _getWeekStart();
    return 'Woche ${isoWeekKey(weekStart)}';
  }
  
  
  /// Get number of meals for selected day
  int _getMealsCount(DateTime date) {
    final recipes = _mealPlanService.getRecipesForDate(date);
    return recipes.values.where((r) => r != null).length;
  }
  
  /// Handle auto-plan button tap
  Future<void> _handleAutoPlan() async {
    HapticFeedback.mediumImpact();
    
    // Show bottom sheet for configuration (only half screen height)
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        builder: (context, scrollController) => _AutoPlanBottomSheet(
        mealsPerDay: _mealsPerDay,
          scrollController: scrollController,
        ),
      ),
    );
    
    if (result == null) return;
    
    _mealsPerDay = result['mealsPerDay'] as int;
    final selectedSupermarket = result['supermarket'] as String?;
    final nutritionPreferences = result['nutritionPreferences'] as List<String>? ?? [];
    
    // Get available recipes
    final availableRecipes = await _getAvailableRecipes(
      supermarket: selectedSupermarket,
      nutritionPreferences: nutritionPreferences,
    );
    
    if (availableRecipes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Keine Rezepte verfügbar. Bitte füge zuerst Rezepte hinzu.'),
            backgroundColor: GrocifyTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
      return;
    }
    
    // Generate weekly plan
    final plannedCount = _mealPlanService.generateWeeklyPlan(
      mealsPerDay: _mealsPerDay,
      availableRecipes: availableRecipes,
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Deine Woche wurde automatisch geplant. $plannedCount Rezepte hinzugefügt.',
                ),
              ),
            ],
          ),
          backgroundColor: GrocifyTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get available recipes for auto-planning
  Future<List<Recipe>> _getAvailableRecipes({
    String? supermarket,
    List<String> nutritionPreferences = const [],
  }) async {
    try {
      // Load all recipes from assets
      final allRecipes = await CachedRecipeRepository.instance.loadAllCached();
      
      // Filter out already planned recipes
      final plannedRecipes = _mealPlanService.getPlannedRecipes();
      final plannedRecipeIds = plannedRecipes.map((r) => r.id).toSet();
      var availableRecipes = allRecipes.where((r) => !plannedRecipeIds.contains(r.id)).toList();
      
      // Filter by supermarket if selected
      if (supermarket != null && supermarket.isNotEmpty) {
        final normalizedSupermarket = supermarket.toUpperCase();
        availableRecipes = availableRecipes.where((recipe) {
          final recipeRetailer = recipe.retailer.toUpperCase();
          // Match retailer (handles ALDI SÜD/NORD, etc.)
          return recipeRetailer.contains(normalizedSupermarket) || 
                 recipeRetailer == normalizedSupermarket;
        }).toList();
      }
      
      // Filter by nutrition preferences
      if (nutritionPreferences.isNotEmpty) {
        availableRecipes = availableRecipes.where((recipe) {
          final categories = recipe.categories ?? [];
          final tags = recipe.tags ?? [];
          final allTags = [...categories, ...tags].map((t) => t.toLowerCase()).toList();
          
          // Recipe must match at least one preference
          return nutritionPreferences.any((pref) {
            switch (pref) {
              case 'high_protein':
                return allTags.any((t) => t.contains('protein') || t.contains('eiweiß')) ||
                       (recipe.nutritionRange?.proteinMin ?? 0) >= 30;
              case 'low_carb':
                return allTags.any((t) => t.contains('low carb') || t.contains('kohlenhydrat'));
              case 'vegan':
                return allTags.any((t) => t.contains('vegan'));
              case 'vegetarian':
                return allTags.any((t) => t.contains('vegetarisch') || t.contains('vegetarian'));
              case 'gluten_free':
                return allTags.any((t) => t.contains('glutenfrei') || t.contains('gluten free'));
              case 'lactose_free':
                return allTags.any((t) => t.contains('laktosefrei') || t.contains('lactose free'));
              case 'low_calorie':
                return (recipe.calories ?? 999) < 400;
              case 'high_calorie':
                return (recipe.calories ?? 0) > 600;
              default:
                return true;
            }
          });
        }).toList();
      }
      
      return availableRecipes;
    } catch (e) {
      debugPrint('Error loading recipes: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = _getDateForIndex(_selectedDayIndex);
    final mealsCount = _getMealsCount(selectedDate);
    
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleAutoPlan,
        backgroundColor: GrocifyTheme.primary,
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Auto planen',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                // Sticky Header: "Wochenplan"
                _StickyHeaderSection(
                  weekLabel: _getWeekLabel(),
                ),
                
                // Sticky Day-Navigation
                _DayNavigationSection(
                  weekdaysShort: _weekdaysShort,
                  selectedIndex: _selectedDayIndex,
                  onDaySelected: (index) {
                    setState(() {
                      _selectedDayIndex = index;
                    });
                    HapticFeedback.selectionClick();
                  },
                ),
                
                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tages-Header
                        _DayHeaderSection(
                          date: selectedDate,
                          weekday: _weekdays[_selectedDayIndex],
                          mealsCount: mealsCount,
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Rezept-Cards für den Tag (gruppiert nach MealType)
                        _RecipeCardsSection(
                          date: selectedDate,
                          mealPlanService: _mealPlanService,
                          onRecipeTap: (recipe) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RecipeDetailScreenNew(recipe: recipe),
                              ),
                            );
                          },
                          onRecipeDelete: (recipe, mealType) {
                            _mealPlanService.removeRecipeFromPlanForMealType(selectedDate, mealType);
                            HapticFeedback.lightImpact();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('${recipe.title} entfernt'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: GrocifyTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          onAddMeal: (mealType) {
                            // Navigate to Recipes screen instead of Discover
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RecipesScreen(),
                              ),
                            );
                          },
                        ),
                      ],
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

// ============================================================================
// STICKY HEADER SECTION
// ============================================================================

class _StickyHeaderSection extends StatelessWidget {
  final String weekLabel;
  
  const _StickyHeaderSection({
    required this.weekLabel,
  });

  @override
  Widget build(BuildContext context) {
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      color: GrocifyTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + Subline
          Text(
            'Dein Wochenplan',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: GrocifyTheme.textPrimary,
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Plane deine Mahlzeiten passend zu deinem Einkauf.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: GrocifyTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STICKY DAY NAVIGATION
// ============================================================================

class _DayNavigationSection extends StatelessWidget {
  final List<String> weekdaysShort;
  final int selectedIndex;
  final Function(int) onDaySelected;
  
  const _DayNavigationSection({
    required this.weekdaysShort,
    required this.selectedIndex,
    required this.onDaySelected,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: GrocifyTheme.surface,
      ),
      child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            weekdaysShort.length,
            (index) {
              final isSelected = selectedIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onDaySelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GrocifyTheme.textPrimary
                          : GrocifyTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? GrocifyTheme.textPrimary
                            : GrocifyTheme.border.withOpacity(0.3),
                        width: isSelected ? 0 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                    ),
                      child: Text(
                      weekdaysShort[index],
                        style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : GrocifyTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ),
    );
  }
}

// ============================================================================
// DAY HEADER SECTION
// ============================================================================

class _DayHeaderSection extends StatelessWidget {
  final DateTime date;
  final String weekday;
  final int mealsCount;
  
  const _DayHeaderSection({
    required this.date,
    required this.weekday,
    required this.mealsCount,
  });
  
  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun',
      'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'
    ];
    return '${date.day}. ${months[date.month - 1]}';
  }
  
  @override
  Widget build(BuildContext context) {
    final isToday = date.day == DateTime.now().day && 
                    date.month == DateTime.now().month && 
                    date.year == DateTime.now().year;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$weekday, ${_formatDate(date)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: GrocifyTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GrocifyTheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Heute',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$mealsCount Mahlzeit${mealsCount != 1 ? 'en' : ''} geplant',
                  style: TextStyle(
                    fontSize: 13,
                    color: GrocifyTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RECIPE CARDS SECTION
// ============================================================================

class _RecipeCardsSection extends StatelessWidget {
  final DateTime date;
  final MealPlanService mealPlanService;
  final Function(Recipe) onRecipeTap;
  final Function(Recipe, MealType) onRecipeDelete;
  final Function(MealType) onAddMeal;
  
  const _RecipeCardsSection({
    required this.date,
    required this.mealPlanService,
    required this.onRecipeTap,
    required this.onRecipeDelete,
    required this.onAddMeal,
  });
  
  @override
  Widget build(BuildContext context) {
    final recipesByMealType = mealPlanService.getRecipesForDate(date);
    
    // Meal types in order: Frühstück, Mittagessen, Abendessen
    final mainMealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner];
    
    // Get additional snacks (snack1, snack2)
    final additionalMeals = recipesByMealType.entries
        .where((entry) => entry.key == MealType.snack1 || entry.key == MealType.snack2)
        .toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main meal types
          ...mainMealTypes.map((mealType) {
            final recipe = recipesByMealType[mealType];
            final hasRecipe = recipe != null;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Type Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          mealType.icon,
                          size: 18,
                          color: mealType.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mealType.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recipe Card or Add Button
                  if (hasRecipe)
                    _RecipeCard(
                      recipe: recipe,
                      mealType: mealType,
                      onTap: () => onRecipeTap(recipe),
                      onDelete: () => onRecipeDelete(recipe, mealType),
                    )
                  else
                    _AddMealButton(
                      date: date,
                      mealType: mealType,
                      onTap: () => onAddMeal(mealType),
                    ),
                ],
              ),
            );
          }),
          
          // Additional meals (Snacks)
          ...additionalMeals.map((entry) {
            final mealType = entry.key;
            final recipe = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          mealType.icon,
                          size: 18,
                          color: mealType.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mealType.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _RecipeCard(
                    recipe: recipe!,
                    mealType: mealType,
                    onTap: () => onRecipeTap(recipe),
                    onDelete: () => onRecipeDelete(recipe, mealType),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Recipe Card (Overnight Oats / Pasta Carbonara style)
class _RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final MealType mealType;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  
  const _RecipeCard({
    required this.recipe,
    required this.mealType,
    required this.onTap,
    required this.onDelete,
  });
  
  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> {
  @override
  Widget build(BuildContext context) {
    // Get emoji based on recipe title (simple mapping)
    final emoji = _getEmojiForRecipe(widget.recipe.title);
    
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
                  BoxShadow(
              color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
              spreadRadius: 0,
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Emoji Container (cleaner, no border)
            Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                color: GrocifyTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Right: Content
            Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Header: Title + Delete Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.recipe.title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: GrocifyTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 22,
                            color: GrocifyTheme.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Meta: Duration + Portions + Retailer (subtle)
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: GrocifyTheme.textTertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.recipe.durationMinutes != null
                                ? '${widget.recipe.durationMinutes} Min'
                                : '25 Min',
                            style: TextStyle(
                              fontSize: 13,
                              color: GrocifyTheme.textTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 13,
                            color: GrocifyTheme.textTertiary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.recipe.servings != null
                                ? '${widget.recipe.servings} Pers.'
                                : '2 Pers.',
                            style: TextStyle(
                              fontSize: 13,
                              color: GrocifyTheme.textTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      // Retailer Badge (nur wenn vorhanden)
                      if (widget.recipe.retailer.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.store_rounded,
                                size: 12,
                                color: GrocifyTheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.recipe.retailer,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: GrocifyTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
    );
  }
  
  String _getEmojiForRecipe(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('oats') || lower.contains('hafer')) return '🥣';
    if (lower.contains('pasta') || lower.contains('nudel')) return '🍝';
    if (lower.contains('salat') || lower.contains('salad')) return '🥗';
    if (lower.contains('bowl')) return '🍲';
    if (lower.contains('hähnchen') || lower.contains('chicken')) return '🍗';
    if (lower.contains('lachs') || lower.contains('salmon')) return '🐟';
    if (lower.contains('pizza')) return '🍕';
    if (lower.contains('burger')) return '🍔';
    return '🍽️';
  }
}

// ============================================================================
// ADD MEAL BUTTON
// ============================================================================

class _AddMealButton extends StatefulWidget {
  final DateTime date;
  final MealType? mealType;
  final VoidCallback onTap;
  
  const _AddMealButton({
    required this.date,
    this.mealType,
    required this.onTap,
  });
  
  @override
  State<_AddMealButton> createState() => _AddMealButtonState();
}

class _AddMealButtonState extends State<_AddMealButton> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: GrocifyTheme.surfaceSubtle.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
          ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Icon(
                  Icons.add_rounded,
                  size: 20,
              color: GrocifyTheme.textSecondary.withOpacity(0.6),
              ),
              const SizedBox(width: 10),
              Text(
              'Noch kein Rezept geplant',
                style: TextStyle(
                fontSize: 14,
                  fontWeight: FontWeight.w500,
                color: GrocifyTheme.textSecondary.withOpacity(0.8),
                ),
              ),
            ],
          ),
      ),
    );
  }
}

// ============================================================================
// AUTO-PLAN BOTTOM SHEET
// ============================================================================

class _AutoPlanBottomSheet extends StatefulWidget {
  final int mealsPerDay;
  final ScrollController scrollController;
  
  const _AutoPlanBottomSheet({
    required this.mealsPerDay,
    required this.scrollController,
  });
  
  @override
  State<_AutoPlanBottomSheet> createState() => _AutoPlanBottomSheetState();
}

class _AutoPlanBottomSheetState extends State<_AutoPlanBottomSheet> {
  int _mealsPerDay = 1;
  String? _selectedSupermarket;
  final Set<String> _nutritionPreferences = {};
  
  // Available supermarkets
  static const List<Map<String, String>> _supermarkets = [
    {'name': 'Rewe', 'retailer': 'REWE'},
    {'name': 'Lidl', 'retailer': 'LIDL'},
    {'name': 'Aldi Süd', 'retailer': 'ALDI SÜD'},
    {'name': 'Aldi Nord', 'retailer': 'ALDI NORD'},
    {'name': 'Kaufland', 'retailer': 'KAUFLAND'},
    {'name': 'Penny', 'retailer': 'PENNY'},
    {'name': 'Netto', 'retailer': 'NETTO'},
    {'name': 'Norma', 'retailer': 'NORMA'},
    {'name': 'Edeka', 'retailer': 'EDEKA'},
    {'name': 'Tegut', 'retailer': 'TEGUT'},
    {'name': 'Marktkauf', 'retailer': 'MARKTKAUF'},
    {'name': 'Nahkauf', 'retailer': 'NAHKAUF'},
    {'name': 'Denns', 'retailer': 'DENNS'},
  ];
  
  // Nutrition preferences
  static const List<Map<String, String>> _nutritionOptions = [
    {'label': 'High Protein', 'key': 'high_protein'},
    {'label': 'High Calorie', 'key': 'high_calorie'},
    {'label': 'Low Carb', 'key': 'low_carb'},
    {'label': 'Vegan', 'key': 'vegan'},
    {'label': 'Vegetarisch', 'key': 'vegetarian'},
    {'label': 'Glutenfrei', 'key': 'gluten_free'},
    {'label': 'Laktosefrei', 'key': 'lactose_free'},
    {'label': 'Kalorienarm', 'key': 'low_calorie'},
  ];
  
  @override
  void initState() {
    super.initState();
    _mealsPerDay = widget.mealsPerDay;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GrocifyTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
        child: Column(
          children: [
            // Handle bar + Close button
            Stack(
              children: [
                // Handle bar centered
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: GrocifyTheme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              // Close button (X) - oben rechts für bessere Daumen-Erreichbarkeit
                Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: GrocifyTheme.border,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: GrocifyTheme.textPrimary,
                      ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - minimalistisch
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: GrocifyTheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: GrocifyTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart planen',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: GrocifyTheme.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Automatisch deine Woche planen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: GrocifyTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Step 1: Mahlzeiten pro Tag - minimalistisch
                  Text(
                    'Mahlzeiten pro Tag',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GrocifyTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (index) {
                      final count = index + 1;
                      final isSelected = _mealsPerDay == count;
                      
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index < 2 ? 8 : 0,
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _mealsPerDay = count;
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? GrocifyTheme.primary
                                    : GrocifyTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? GrocifyTheme.primary
                                      : GrocifyTheme.border,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : GrocifyTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  
                  // Step 2: Supermarkt auswählen - minimalistisch
                  Text(
                    'Supermarkt (optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GrocifyTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Für bessere Angebote',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: GrocifyTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _supermarkets.map((supermarket) {
                      final retailer = supermarket['retailer']!;
                      final name = supermarket['name']!;
                      final isSelected = _selectedSupermarket == retailer;
                      return GestureDetector(
              onTap: () {
                setState(() {
                            _selectedSupermarket = isSelected ? null : retailer;
                });
                          HapticFeedback.selectionClick();
              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                decoration: BoxDecoration(
                            color: isSelected
                          ? GrocifyTheme.primary
                                : GrocifyTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                              color: isSelected
                            ? GrocifyTheme.primary
                            : GrocifyTheme.border,
                              width: isSelected ? 2 : 1,
                  ),
                          ),
                    child: Text(
                            name,
                      style: TextStyle(
                        fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : GrocifyTheme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Step 3: Ernährungsweise (optional) - minimalistisch
                  Text(
                    'Ernährungsweise (optional)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: GrocifyTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mehrfachauswahl möglich',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: GrocifyTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _nutritionOptions.map((option) {
                      final key = option['key']!;
                      final label = option['label']!;
                      final isSelected = _nutritionPreferences.contains(key);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _nutritionPreferences.remove(key);
                            } else {
                              _nutritionPreferences.add(key);
                            }
                          });
                          HapticFeedback.selectionClick();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? GrocifyTheme.primary.withOpacity(0.1)
                                : GrocifyTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? GrocifyTheme.primary
                                  : GrocifyTheme.border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: GrocifyTheme.primary,
                                )
                              else
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: GrocifyTheme.border,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? GrocifyTheme.primary
                                      : GrocifyTheme.textPrimary,
                      ),
                    ),
                  ],
              ),
            ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  
                  const SizedBox(height: 24),
                  
                  // CTA Button - minimalistisch
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context, {
                          'mealsPerDay': _mealsPerDay,
                          'supermarket': _selectedSupermarket,
                          'nutritionPreferences': _nutritionPreferences.toList(),
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: GrocifyTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Plan erstellen',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
        ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}
