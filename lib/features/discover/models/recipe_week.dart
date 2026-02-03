import '../../../data/models/recipe.dart';

/// Model für eine Rezepte-Woche (für Wochen-Carousel)
class RecipeWeek {
  final String id;
  final String weekNumber; // z.B. "Woche 77"
  final int recipeCount; // Anzahl Rezepte in dieser Woche
  final String? subtitle; // z.B. "Basierend auf Angeboten"
  final String imageUrl; // Hero-Bild URL (optional, kann auch Emoji/Placeholder sein)
  final List<Recipe> recipes; // Rezepte dieser Woche
  final DateTime weekStart; // Start-Datum der Woche

  const RecipeWeek({
    required this.id,
    required this.weekNumber,
    required this.recipeCount,
    this.subtitle,
    required this.imageUrl,
    required this.recipes,
    required this.weekStart,
  });

  factory RecipeWeek.fromJson(Map<String, dynamic> json) {
    return RecipeWeek(
      id: json['id'] as String,
      weekNumber: json['weekNumber'] as String,
      recipeCount: json['recipeCount'] as int,
      subtitle: json['subtitle'] as String?,
      imageUrl: json['imageUrl'] as String? ?? '🍽️',
      recipes: (json['recipes'] as List<dynamic>?)
              ?.map((r) => Recipe.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      weekStart: json['weekStart'] != null
          ? DateTime.parse(json['weekStart'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weekNumber': weekNumber,
      'recipeCount': recipeCount,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'recipes': recipes.map((r) => r.toJson()).toList(),
      'weekStart': weekStart.toIso8601String(),
    };
  }
}
