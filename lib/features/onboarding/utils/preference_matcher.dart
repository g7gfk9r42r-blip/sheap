/// Preference Matcher - Hilft Rezepte nach User-Präferenzen zu sortieren
import '../../../data/models/recipe.dart';
import '../models/user_profile_local.dart';

class PreferenceMatcher {
  /// Berechnet einen Score (0-100) wie gut ein Rezept zu den Präferenzen passt
  static double calculatePreferenceScore(Recipe recipe, UserProfileLocal? profile) {
    if (profile == null) return 0.0;
    
    double score = 0.0;
    final maxScore = 100.0;
    
    // Ernährungspräferenzen (60 Punkte)
    final dietScore = _calculateDietScore(recipe, profile.dietPreferences);
    score += dietScore * 0.6;
    
    // Kochzeit-Präferenz (20 Punkte)
    final cookingTimeScore = _calculateCookingTimeScore(recipe, profile.preferredCookingTime);
    score += cookingTimeScore * 0.2;
    
    // Supermarkt-Präferenz (20 Punkte)
    final supermarketScore = _calculateSupermarketScore(
      recipe,
      profile.favoriteSupermarkets.isNotEmpty ? profile.favoriteSupermarkets : _legacySingle(profile.preferredSupermarket),
    );
    score += supermarketScore * 0.2;
    
    return score.clamp(0.0, maxScore);
  }
  
  static double _calculateDietScore(Recipe recipe, Set<DietPreference> preferences) {
    if (preferences.isEmpty) return 0.0;
    
    final titleLower = recipe.title.toLowerCase();
    final descLower = recipe.description.toLowerCase();
    final tags = recipe.tags?.map((t) => t.toLowerCase()).toList() ?? [];
    final text = '$titleLower $descLower ${tags.join(' ')}';
    
    double score = 0.0;
    
    // Vegetarisch
    if (preferences.contains(DietPreference.vegetarian)) {
      if (!text.contains('fleisch') && 
          !text.contains('meat') &&
          !text.contains('hähnchen') &&
          !text.contains('chicken') &&
          !text.contains('lachs') &&
          !text.contains('salmon') &&
          !text.contains('fisch') &&
          !text.contains('fish')) {
        score += 50.0;
      }
    }
    
    // Vegan
    if (preferences.contains(DietPreference.vegan)) {
      if (!text.contains('fleisch') && 
          !text.contains('meat') &&
          !text.contains('milch') &&
          !text.contains('milk') &&
          !text.contains('käse') &&
          !text.contains('cheese') &&
          !text.contains('ei') &&
          !text.contains('egg')) {
        score += 60.0;
      }
    }
    
    // Low Carb
    if (preferences.contains(DietPreference.lowCarb)) {
      if (text.contains('low carb') || 
          text.contains('keto') ||
          text.contains('kohlenhydratarm')) {
        score += 40.0;
      }
    }
    
    // High Protein
    if (preferences.contains(DietPreference.highProtein)) {
      if (text.contains('protein') || 
          text.contains('hähnchen') ||
          text.contains('chicken') ||
          text.contains('lachs') ||
          text.contains('salmon') ||
          text.contains('thunfisch') ||
          text.contains('tuna') ||
          (recipe.calories != null && recipe.calories! > 400)) {
        score += 40.0;
      }
    }
    
    // Laktosefrei
    if (preferences.contains(DietPreference.lactoseFree)) {
      if (!text.contains('milch') && 
          !text.contains('milk') &&
          !text.contains('käse') &&
          !text.contains('cheese')) {
        score += 30.0;
      }
    }
    
    // Glutenfrei
    if (preferences.contains(DietPreference.glutenFree)) {
      if (text.contains('glutenfrei') || 
          text.contains('gluten-free')) {
        score += 30.0;
      }
    }
    
    return (score / preferences.length).clamp(0.0, 100.0);
  }
  
  static double _calculateCookingTimeScore(Recipe recipe, int? preferredCookingTime) {
    if (preferredCookingTime == null) return 0.0;
    
    final recipeTime = recipe.durationMinutes ?? 30;
    
    // Präferenz: 10-20 min → Score für Rezepte 10-25 min
    // Präferenz: 20-40 min → Score für Rezepte 20-45 min
    // Präferenz: 40+ min → Score für Rezepte 40+ min
    
    if (preferredCookingTime <= 20) {
      if (recipeTime >= 10 && recipeTime <= 25) return 100.0;
      if (recipeTime < 10 || recipeTime > 25) return 50.0;
    } else if (preferredCookingTime <= 40) {
      if (recipeTime >= 20 && recipeTime <= 45) return 100.0;
      if (recipeTime < 20 || recipeTime > 45) return 50.0;
    } else {
      if (recipeTime >= 40) return 100.0;
      if (recipeTime < 40) return 50.0;
    }
    
    return 0.0;
  }
  
  static List<String> _legacySingle(String? preferredSupermarket) {
    final s = (preferredSupermarket ?? '').trim();
    return s.isEmpty ? const <String>[] : <String>[s];
  }

  static double _calculateSupermarketScore(Recipe recipe, List<String> favoriteSupermarkets) {
    if (favoriteSupermarkets.isEmpty) return 0.0;

    final recipeRetailer = recipe.retailer.toUpperCase();
    final favUpper = favoriteSupermarkets.map((s) => s.toUpperCase()).toSet();
    return favUpper.contains(recipeRetailer) ? 100.0 : 0.0;
  }
  
  /// Sortiert Rezepte nach Präferenz-Score (höchster zuerst)
  static List<Recipe> sortByPreferences(List<Recipe> recipes, UserProfileLocal? profile) {
    final hasMarketPref = profile != null &&
        (profile.favoriteSupermarkets.isNotEmpty || ((profile.preferredSupermarket ?? '').trim().isNotEmpty));
    if (profile == null || (profile.dietPreferences.isEmpty && !hasMarketPref)) {
      return recipes;
    }
    
    final recipesWithScores = recipes.map((recipe) {
      return MapEntry(calculatePreferenceScore(recipe, profile), recipe);
    }).toList();
    
    recipesWithScores.sort((a, b) => b.key.compareTo(a.key));
    
    return recipesWithScores.map((e) => e.value).toList();
  }
}

