/// Meal Plan Service
/// Manages weekly meal planning - simple in-memory store
import 'package:flutter/material.dart';
import '../../core/theme/grocify_theme.dart';
import '../models/recipe.dart';
import 'shopping_list_service.dart';

class MealPlanService extends ChangeNotifier {
  MealPlanService._();
  static final MealPlanService instance = MealPlanService._();

  // Map: DateTime (date only) -> Map<MealType, Recipe?>
  final Map<DateTime, Map<MealType, Recipe?>> _plan = {};

  /// Get all recipes currently in the meal plan
  List<Recipe> getPlannedRecipes() {
    final recipes = <Recipe>[];
    for (final dayPlan in _plan.values) {
      for (final recipe in dayPlan.values) {
        if (recipe != null) {
          recipes.add(recipe);
        }
      }
    }
    return recipes;
  }

  /// Check if a recipe is already in the plan
  bool isRecipePlanned(Recipe recipe) {
    final plannedIds = getPlannedRecipes().map((r) => r.id).toSet();
    return plannedIds.contains(recipe.id);
  }

  /// Add a recipe to the meal plan for a specific date and meal type
  /// Also adds ingredients to shopping list
  void addRecipeToPlan(Recipe recipe, DateTime date, MealType mealType) {
    final dateKey = DateTime(date.year, date.month, date.day);
    _plan.putIfAbsent(dateKey, () => {})[mealType] = recipe;
    
    // Add ingredients to shopping list
    _addIngredientsToShoppingList(recipe);
    
    notifyListeners();
  }
  
  /// Add recipe ingredients to shopping list
  void _addIngredientsToShoppingList(Recipe recipe) {
    try {
      // Import ShoppingListService dynamically to avoid circular dependency
      final shoppingListService = ShoppingListService.instance;
      
      final items = <ShoppingListItem>[];
      
      // Wenn offersUsed verfügbar ist, nutze die detaillierten Informationen
      if (recipe.offersUsed != null && recipe.offersUsed!.isNotEmpty) {
        for (final offerUsed in recipe.offersUsed!) {
          // Menge formatieren
          String? amount;
          if (offerUsed.unit.isNotEmpty) {
            if (offerUsed.unit == 'g' || offerUsed.unit == 'ml') {
              amount = offerUsed.unit;
            } else {
              amount = offerUsed.unit;
            }
          }
          
          items.add(
            ShoppingListItem(
              name: offerUsed.exactName,
              amount: amount,
              brand: offerUsed.brand,
              quantity: null, // Kann aus unit abgeleitet werden
              unit: offerUsed.unit,
              price: offerUsed.priceEur,
              priceBefore: offerUsed.priceBeforeEur ?? offerUsed.uvpEur,
              currency: 'EUR',
            ),
          );
        }
      } else {
        // Fallback: Nutze ingredients als String-Liste
        for (final ingredient in recipe.ingredients) {
          // Menge extrahieren (falls vorhanden)
          String? amount;
          if (ingredient.contains('(') && ingredient.contains(')')) {
            final match = RegExp(r'\(([^)]+)\)').firstMatch(ingredient);
            if (match != null) {
              amount = match.group(1);
            }
          }
          
          items.add(
            ShoppingListItem(
              name: ingredient.split('(').first.trim(),
              amount: amount,
            ),
          );
        }
      }
      
      if (items.isNotEmpty) {
        shoppingListService.addItems(items);
      }
    } catch (e) {
      // Silently fail if shopping list service is not available
      debugPrint('Failed to add ingredients to shopping list: $e');
    }
  }

  /// Remove a recipe from the plan
  void removeRecipeFromPlan(Recipe recipe) {
    for (final dayPlan in _plan.values) {
      dayPlan.removeWhere((key, value) => value?.id == recipe.id);
    }
    notifyListeners();
  }

  /// Remove recipe from a specific date and meal type
  void removeRecipeFromPlanForMealType(DateTime date, MealType mealType) {
    final dateKey = DateTime(date.year, date.month, date.day);
    _plan.putIfAbsent(dateKey, () => {})[mealType] = null;
    notifyListeners();
  }

  /// Get recipe for a specific date and meal type
  Recipe? getRecipeFor(DateTime date, MealType mealType) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _plan[dateKey]?[mealType];
  }

  /// Get all recipes for a specific date
  Map<MealType, Recipe?> getRecipesForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return _plan[dateKey] ?? {};
  }

  /// Clear all plans
  void clearPlan() {
    _plan.clear();
    notifyListeners();
  }

  /// Determine if a recipe is suitable for a meal type (intelligent matching)
  bool _isRecipeSuitableForMealType(Recipe recipe, MealType mealType) {
    final titleLower = recipe.title.toLowerCase();
    final descriptionLower = recipe.description.toLowerCase();
    final tags = (recipe.tags ?? []).map((t) => t.toLowerCase()).toList();
    final categories = (recipe.categories ?? []).map((c) => c.toLowerCase()).toList();
    final allText = '$titleLower $descriptionLower ${tags.join(' ')} ${categories.join(' ')}';

    switch (mealType) {
      case MealType.breakfast:
        // Frühstück: süße Sachen, Müsli, Eier, Toast, Smoothies, etc.
        final breakfastKeywords = [
          'frühstück', 'breakfast', 'müsli', 'cereal', 'porridge', 'haferflocken',
          'pancake', 'pfannkuchen', 'waffel', 'waffle', 'toast', 'brötchen',
          'eier', 'egg', 'omelett', 'omelet', 'rührei', 'scrambled',
          'smoothie', 'joghurt', 'yoghurt', 'quark', 'marmelade',
          'croissant', 'bagel', 'overnight', 'oats', 'granola'
        ];
        // Ausschlüsse für Frühstück: Nudeln, Pasta, schweres Essen
        final breakfastExclusions = [
          'pasta', 'nudel', 'spaghetti', 'bolognese', 'carbonara',
          'lasagne', 'ravioli', 'pizza', 'burger', 'steak',
          'schnitzel', 'curry', 'stir-fry', 'pfanne', 'gulasch'
        ];
        if (breakfastExclusions.any((ex) => allText.contains(ex))) {
          return false;
        }
        return breakfastKeywords.any((keyword) => allText.contains(keyword));

      case MealType.lunch:
        // Mittagessen: Hauptgerichte, Salate, Nudeln, etc. - fast alles außer typischem Frühstück/Abendessen
        final lunchExclusions = [
          'frühstück', 'breakfast', 'müsli', 'cereal', 'overnight',
          'smoothie', 'toast', 'brötchen' // Leichte Frühstücks-Ausschlüsse
        ];
        if (lunchExclusions.any((ex) => allText.contains(ex))) {
          // Nur wenn es auch typische Mittags-Zutaten hat
          final lunchKeywords = ['salat', 'salad', 'pasta', 'nudel', 'reis', 'rice', 'fleisch', 'fish', 'fisch'];
          return lunchKeywords.any((keyword) => allText.contains(keyword));
        }
        return true; // Standard: Mittagessen kann fast alles sein

      case MealType.dinner:
        // Abendessen: Leichtes, Salate, Suppen, aber auch Hauptgerichte
        final dinnerKeywords = [
          'salat', 'salad', 'suppe', 'soup', 'brühe', 'broth',
          'leicht', 'light', 'bowl', 'wrap', 'sandwich',
          'quiche', 'frittata', 'omelett', 'pfanne', 'stir-fry'
        ];
        // Abendessen kann auch Hauptgerichte sein, aber bevorzuge Leichtes
        // Keine schweren Ausschlüsse, aber wenn es Frühstück-Keywords hat, eher nicht
        final dinnerExclusions = [
          'frühstück', 'breakfast', 'müsli', 'cereal', 'porridge'
        ];
        if (dinnerExclusions.any((ex) => allText.contains(ex))) {
          return false;
        }
        // Wenn es Dinner-Keywords hat, ist es gut, sonst auch ok (kann Hauptgericht sein)
        return dinnerKeywords.any((keyword) => allText.contains(keyword)) || 
               !allText.contains('breakfast') && !allText.contains('frühstück');
      
      case MealType.snack1:
      case MealType.snack2:
        // Snacks: fast alles geeignet, aber bevorzuge leichte Sachen
        final snackExclusions = [
          'frühstück', 'breakfast', 'müsli', 'cereal',
          'hauptgericht', 'dinner', 'mittagessen'
        ];
        if (snackExclusions.any((ex) => allText.contains(ex))) {
          return false;
        }
        return true; // Snacks können fast alles sein
    }
  }

  /// Get recipes suitable for a meal type
  List<Recipe> _getRecipesForMealType(List<Recipe> recipes, MealType mealType) {
    final suitable = recipes.where((r) => _isRecipeSuitableForMealType(r, mealType)).toList();
    // Wenn keine passenden gefunden, nimm alle (Fallback)
    return suitable.isNotEmpty ? suitable : recipes;
  }

  /// Generate a weekly plan automatically with intelligent recipe assignment
  /// Fills each day with the specified number of meals from the provided recipe list
  /// 
  /// [mealsPerDay] - Number of meals to plan per day (1-3)
  /// [availableRecipes] - List of recipes to choose from
  /// 
  /// Returns the number of recipes successfully planned
  int generateWeeklyPlan({
    required int mealsPerDay,
    required List<Recipe> availableRecipes,
  }) {
    if (availableRecipes.isEmpty) return 0;
    if (mealsPerDay < 1 || mealsPerDay > 3) return 0;
    
    // Get week start (Monday)
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    
    // Available meal types in order: breakfast, lunch, dinner, snack1, snack2
    final mealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner, MealType.snack1, MealType.snack2];
    
    // Prepare recipes by meal type
    final recipesByMealType = {
      for (var mealType in mealTypes)
        mealType: _getRecipesForMealType(availableRecipes, mealType)
          ..shuffle(),
    };
    
    // Track used recipes to avoid duplicates in same week
    final usedRecipeIds = <String>{};
    int plannedCount = 0;
    
    // Plan for each day of the week (Monday to Sunday)
    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final date = weekStart.add(Duration(days: dayOffset));
      final dateKey = DateTime(date.year, date.month, date.day);
      
      // Ensure we have a map for this date
      _plan.putIfAbsent(dateKey, () => {});
      
      // Plan meals for this day
      int mealsPlannedForDay = 0;
      final mealTypeIterators = {
        for (var mealType in mealTypes)
          mealType: 0, // Index für jede MealType-Liste
      };
      
      for (final mealType in mealTypes) {
        if (mealsPlannedForDay >= mealsPerDay) break;
        
        // Skip if already planned
        if (_plan[dateKey]![mealType] != null) continue;
        
        // Get suitable recipes for this meal type
        final suitableRecipes = recipesByMealType[mealType] ?? [];
        if (suitableRecipes.isEmpty) continue;
        
        // Find a recipe that hasn't been used this week
        Recipe? selectedRecipe;
        int attempts = 0;
        int startIndex = mealTypeIterators[mealType] ?? 0;
        
        while (attempts < suitableRecipes.length) {
          final index = (startIndex + attempts) % suitableRecipes.length;
          final candidate = suitableRecipes[index];
          
          if (!usedRecipeIds.contains(candidate.id)) {
            selectedRecipe = candidate;
            mealTypeIterators[mealType] = (index + 1) % suitableRecipes.length;
            break;
          }
          attempts++;
        }
        
        // If all recipes were used, reset and use any (but still suitable for meal type)
        if (selectedRecipe == null && suitableRecipes.isNotEmpty) {
          selectedRecipe = suitableRecipes[startIndex % suitableRecipes.length];
          mealTypeIterators[mealType] = (startIndex + 1) % suitableRecipes.length;
        }
        
        if (selectedRecipe != null) {
          _plan[dateKey]![mealType] = selectedRecipe;
          usedRecipeIds.add(selectedRecipe.id);
          mealsPlannedForDay++;
          plannedCount++;
          
          // Add ingredients to shopping list
          _addIngredientsToShoppingList(selectedRecipe);
        }
      }
    }
    
    notifyListeners();
    return plannedCount;
  }
}

/// Meal types for planning
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack1,
  snack2,
}

extension MealTypeX on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Frühstück',
        MealType.lunch => 'Mittagessen',
        MealType.dinner => 'Abendessen',
        MealType.snack1 => 'Snack',
        MealType.snack2 => 'Snack',
      };

  IconData get icon => switch (this) {
        MealType.breakfast => Icons.free_breakfast_rounded,
        MealType.lunch => Icons.lunch_dining_rounded,
        MealType.dinner => Icons.dinner_dining_rounded,
        MealType.snack1 => Icons.cookie_outlined,
        MealType.snack2 => Icons.cookie_outlined,
      };
  
  Color get color => switch (this) {
        MealType.breakfast => const Color(0xFFFFB800),
        MealType.lunch => GrocifyTheme.primary,
        MealType.dinner => GrocifyTheme.success,
        MealType.snack1 => const Color(0xFFFF9800),
        MealType.snack2 => const Color(0xFFFF9800),
      };
}

