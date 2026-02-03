/// Einkaufen Screen - Supermarket Selection & Recipe Discovery
/// Modern, clean design inspired by Nike/Yazio
/// Features: Supermarket selector + filtered recipe list
/// 
/// UI-Update: Harmonisiertes Farbsystem, modernere Card-Styles und konsistente Typografie.
/// Layout und Datenlogik bleiben unverändert.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/grocify_theme.dart';
import '../../core/widgets/week_day_selector.dart';
import '../../data/models/recipe.dart';
import '../../data/repositories/cached_recipe_repository.dart';
import '../../data/services/meal_plan_service.dart';
import '../discover/recipe_detail_screen_new.dart';

class EinkaufenScreen extends StatefulWidget {
  const EinkaufenScreen({super.key});

  @override
  State<EinkaufenScreen> createState() => _EinkaufenScreenState();
}

class _EinkaufenScreenState extends State<EinkaufenScreen> {
  // Available retailers
  final List<String> _retailers = ['REWE', 'EDEKA', 'LIDL', 'ALDI', 'NETTO'];
  String? _selectedRetailer;
  
  // Filter/Sort options
  String _selectedFilter = 'Alle';
  final List<String> _filters = ['Alle', 'Meiste Ersparnis', 'Beliebt', 'Neu'];
  
  // Recipe data
  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _error;
  
  // Meal plan service
  final MealPlanService _mealPlanService = MealPlanService.instance;
  
  @override
  void initState() {
    super.initState();
    // Listen to meal plan changes
    _mealPlanService.addListener(_onMealPlanChanged);
    // Load recipes for all retailers initially
    _loadRecipes();
  }
  
  @override
  void dispose() {
    _mealPlanService.removeListener(_onMealPlanChanged);
    super.dispose();
  }
  
  void _onMealPlanChanged() {
    // Filter out planned recipes when meal plan changes
    setState(() {});
  }
  
  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      List<Recipe> recipes;
      
      if (_selectedRetailer == null) {
        // Load all recipes from all retailers
        recipes = await CachedRecipeRepository.instance.loadAllCached();
      } else {
        // Load recipes for selected retailer from assets
        recipes = await CachedRecipeRepository.instance.loadForMarket(_selectedRetailer!);
      }
      
      // Filter out recipes that are already in the meal plan
      final plannedRecipeIds = _mealPlanService.getPlannedRecipes().map((r) => r.id).toSet();
      List<Recipe> filtered = recipes.where((r) => !plannedRecipeIds.contains(r.id)).toList();
      
      // Apply filter/sort
      if (_selectedFilter == 'Meiste Ersparnis') {
        // TODO: Sort by savings when available in JSON
        // For now, sort alphabetically
        filtered.sort((a, b) => a.title.compareTo(b.title));
      } else if (_selectedFilter == 'Beliebt') {
        // TODO: Sort by popularity when available in JSON
        // For now, sort alphabetically
        filtered.sort((a, b) => a.title.compareTo(b.title));
      } else if (_selectedFilter == 'Neu') {
        // Sort by creation date (newest first)
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      // "Alle" filter: no sorting needed, keep original order
      
      setState(() {
        _recipes = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Fehler beim Laden der Rezepte: $e';
        _isLoading = false;
      });
    }
  }
  
  void _onRetailerSelected(String retailer) {
    setState(() {
      _selectedRetailer = _selectedRetailer == retailer ? null : retailer;
    });
    _loadRecipes();
  }
  
  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadRecipes();
  }
  
  void _navigateToRecipeDetail(Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreenNew(recipe: recipe),
      ),
    );
  }
  
  Future<void> _showAddToPlanDialog(Recipe recipe) async {
    // Use week-based selector instead of month DatePicker
    final result = await showWeekDayMealTypeSelector(
      context: context,
      initialDate: DateTime.now(),
    );
    
    if (result != null && result['date'] != null && result['mealType'] != null) {
      final selectedDate = result['date'] as DateTime;
      final mealType = result['mealType'] as MealType;
      
      _mealPlanService.addRecipeToPlan(recipe, selectedDate, mealType);
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: GrocifyTheme.spaceMD),
                Expanded(
                  child: Text('${recipe.title} zum ${mealType.label} hinzugefügt'),
                ),
              ],
            ),
            backgroundColor: GrocifyTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // Reload recipes to filter out the added one
      _loadRecipes();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrocifyTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecipes,
          color: GrocifyTheme.primary,
          backgroundColor: GrocifyTheme.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
            // Header Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  GrocifyTheme.screenPadding,
                  GrocifyTheme.spaceXXL,
                  GrocifyTheme.screenPadding,
                  GrocifyTheme.spaceLG,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: GrocifyTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(GrocifyTheme.radiusMD),
                          ),
                          child: Icon(
                            Icons.shopping_bag_rounded,
                            size: 24,
                            color: GrocifyTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Einkaufen',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                  color: GrocifyTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Wähle deinen Supermarkt und entdecke passende Rezepte',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: GrocifyTheme.textSecondary,
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
            ),
            
            // Supermarket Selector (Horizontal Scroll)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GrocifyTheme.screenPadding,
                ),
                child: SizedBox(
                  height: 50,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _retailers.length + 1, // +1 for "Alle" option
                    separatorBuilder: (context, index) => const SizedBox(width: GrocifyTheme.spaceMD),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "Alle" option
                        final isSelected = _selectedRetailer == null;
                        return _RetailerChip(
                          retailer: 'Alle',
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedRetailer = null;
                            });
                            _loadRecipes();
                          },
                        );
                      }
                      final retailer = _retailers[index - 1];
                      final isSelected = _selectedRetailer == retailer;
                      return _RetailerChip(
                        retailer: retailer,
                        isSelected: isSelected,
                        onTap: () => _onRetailerSelected(retailer),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: GrocifyTheme.spaceLG),
            ),
            
            // Filter Row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GrocifyTheme.screenPadding,
                ),
                child: Row(
                  children: [
                    Text(
                      'Sortieren:',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: GrocifyTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: GrocifyTheme.spaceMD),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: GrocifyTheme.spaceSM),
                              child: _FilterChip(
                                label: filter,
                                isSelected: isSelected,
                                onTap: () => _onFilterChanged(filter),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SliverToBoxAdapter(
              child: SizedBox(height: GrocifyTheme.spaceXXL),
            ),
            
            // Recipe List
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(GrocifyTheme.spaceXXXXL),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: GrocifyTheme.primary,
                    ),
                  ),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(GrocifyTheme.spaceXXL),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: GrocifyTheme.textTertiary,
                        ),
                        const SizedBox(height: GrocifyTheme.spaceLG),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: GrocifyTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: GrocifyTheme.spaceLG),
                        TextButton.icon(
                          onPressed: _loadRecipes,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Erneut versuchen'),
                          style: TextButton.styleFrom(
                            foregroundColor: GrocifyTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_recipes.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(GrocifyTheme.spaceXXXXL),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          size: 64,
                          color: GrocifyTheme.textTertiary,
                        ),
                        const SizedBox(height: GrocifyTheme.spaceLG),
                        Text(
                          'Keine Rezepte gefunden',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: GrocifyTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: GrocifyTheme.spaceSM),
                        Text(
                          'Versuche einen anderen Supermarkt oder Filter',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: GrocifyTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: GrocifyTheme.screenPadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final recipe = _recipes[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: GrocifyTheme.spaceLG),
                        child: _RecipeCard(
                          recipe: recipe,
                          onTap: () => _navigateToRecipeDetail(recipe),
                          onAddToPlan: () => _showAddToPlanDialog(recipe),
                        ),
                      );
                    },
                    childCount: _recipes.length,
                  ),
                ),
              ),
            
            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: GrocifyTheme.spaceXXXXL),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Retailer Chip - Selectable supermarket card
/// Modern pill-shaped design with smooth animations
class _RetailerChip extends StatelessWidget {
  final String retailer;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _RetailerChip({
    required this.retailer,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: GrocifyTheme.spaceLG,
          vertical: GrocifyTheme.spaceMD,
        ),
        decoration: BoxDecoration(
          color: isSelected ? GrocifyTheme.primary : GrocifyTheme.surface,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusRound),
          border: Border.all(
            color: isSelected
                ? GrocifyTheme.primary
                : GrocifyTheme.border.withOpacity(0.5),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected ? GrocifyTheme.shadowMD : GrocifyTheme.shadowSM,
        ),
        child: Center(
          child: Text(
            retailer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : GrocifyTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter Chip - Sort/Filter option
/// Pill-shaped with subtle active state
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: GrocifyTheme.spaceMD,
          vertical: GrocifyTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? GrocifyTheme.primary.withOpacity(0.12)
              : GrocifyTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusRound),
          border: Border.all(
            color: isSelected
                ? GrocifyTheme.primary
                : GrocifyTheme.border.withOpacity(0.4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? GrocifyTheme.primary
                : GrocifyTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Recipe Card - Full-width, modern design
/// Clean food app card with rounded corners, subtle shadows, and clear hierarchy
/// Now with animated "Add to Plan" button
class _RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final VoidCallback onAddToPlan;
  
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onAddToPlan,
  });
  
  @override
  State<_RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<_RecipeCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => _scaleController.forward(),
          onTapUp: (_) => _scaleController.reverse(),
          onTapCancel: () => _scaleController.reverse(),
          borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
          child: Container(
            width: double.infinity,
          decoration: BoxDecoration(
            color: GrocifyTheme.surface,
            borderRadius: BorderRadius.circular(GrocifyTheme.radiusXXL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image placeholder with rounded top corners
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(GrocifyTheme.radiusXXL),
                  topRight: Radius.circular(GrocifyTheme.radiusXXL),
                ),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        GrocifyTheme.primary.withOpacity(0.15),
                        GrocifyTheme.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      size: 64,
                      color: GrocifyTheme.primary.withOpacity(0.35),
                    ),
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(GrocifyTheme.spaceLG),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      widget.recipe.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: GrocifyTheme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: GrocifyTheme.spaceSM),
                    
                    // Description
                    if (widget.recipe.description.isNotEmpty)
                      Text(
                        widget.recipe.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: GrocifyTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: GrocifyTheme.spaceMD),
                    
                    // Meta info row - flexible to prevent overflow
                    Row(
                      children: [
                        // Retailer
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.store_rounded,
                                size: 16,
                                color: GrocifyTheme.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.recipe.retailer,
                                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: GrocifyTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: GrocifyTheme.spaceLG),
                        
                        // Savings badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: GrocifyTheme.spaceMD,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: GrocifyTheme.successGradient,
                            borderRadius: BorderRadius.circular(GrocifyTheme.radiusRound),
                          ),
                          child: Text(
                            'Bis zu 35% sparen',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: GrocifyTheme.spaceMD),
                    
                    // Add to Plan Button - Animated
                    _AnimatedAddButton(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        widget.onAddToPlan();
                      },
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

/// Animated Add to Plan Button with spring animation
class _AnimatedAddButton extends StatefulWidget {
  final VoidCallback onTap;
  
  const _AnimatedAddButton({required this.onTap});
  
  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: GrocifyTheme.spaceMD),
              decoration: BoxDecoration(
                gradient: GrocifyTheme.primaryGradient,
                borderRadius: BorderRadius.circular(GrocifyTheme.radiusLG),
                boxShadow: [
                  BoxShadow(
                    color: GrocifyTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: GrocifyTheme.spaceSM),
                  Text(
                    'Zum Plan hinzufügen',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

