/// Stats Service
/// Calculates daily and weekly overview statistics
import 'meal_plan_service.dart';

/// Today's overview data
class TodayOverview {
  final int plannedMeals;
  final double estimatedCost;

  const TodayOverview({
    required this.plannedMeals,
    required this.estimatedCost,
  });

  bool get isEmpty => plannedMeals == 0;
}

/// Stats Service - calculates daily and weekly statistics
class StatsService {
  StatsService._();
  static final StatsService instance = StatsService._();

  final MealPlanService _mealPlanService = MealPlanService.instance;

  /// Calculate today's overview
  TodayOverview calculateTodayOverview() {
    final today = DateTime.now();
    
    final todayRecipes = _mealPlanService.getRecipesForDate(today);
    final plannedMeals = todayRecipes.values.where((r) => r != null).length;
    
    double estimatedCost = 0.0;
    
    for (final recipe in todayRecipes.values) {
      if (recipe != null) {
        // Use price if available, otherwise estimate (stub: 8€ per meal)
        estimatedCost += recipe.price ?? 8.0;
      }
    }
    
    return TodayOverview(
      plannedMeals: plannedMeals,
      estimatedCost: estimatedCost,
    );
  }
}

