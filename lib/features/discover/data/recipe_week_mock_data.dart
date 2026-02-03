import '../../../data/models/recipe.dart';
import '../models/recipe_week.dart';

/// Mock-Daten Generator für RecipeWeek
/// Generiert Wochen aus vorhandenen Rezepten
class RecipeWeekMockData {
  /// Generiere RecipeWeeks aus Rezepten
  /// Gruppiert Rezepte nach Kalenderwoche
  static List<RecipeWeek> generateWeeksFromRecipes(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return _generateFallbackWeeks();
    }

    // Gruppiere Rezepte nach weekKey
    final recipesByWeek = <String, List<Recipe>>{};
    for (final recipe in recipes) {
      final weekKey = recipe.weekKey;
      recipesByWeek.putIfAbsent(weekKey, () => []).add(recipe);
    }

    // Erstelle RecipeWeeks
    final weeks = <RecipeWeek>[];
    int weekNumber = 1;

    // Sortiere Wochen nach Datum (neueste zuerst)
    final sortedWeekKeys = recipesByWeek.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Umgekehrte Sortierung

    for (final weekKey in sortedWeekKeys.take(5)) {
      // Max 5 Wochen für Carousel
      final weekRecipes = recipesByWeek[weekKey] ?? [];
      if (weekRecipes.isNotEmpty) {
        weeks.add(
          RecipeWeek(
            id: weekKey,
            weekNumber: 'Woche ${_extractWeekNumber(weekKey) ?? weekNumber}',
            recipeCount: weekRecipes.length,
            subtitle: 'Basierend auf Angeboten',
            imageUrl: _getWeekEmoji(weekRecipes),
            recipes: weekRecipes,
            weekStart: _extractWeekStart(weekKey),
          ),
        );
        weekNumber++;
      }
    }

    // Falls keine Wochen gefunden, generiere Fallback
    if (weeks.isEmpty) {
      return _generateFallbackWeeks();
    }

    return weeks;
  }

  /// Extrahiert Wochendatum aus weekKey (z.B. "2024-W52" → DateTime)
  static DateTime _extractWeekStart(String weekKey) {
    try {
      final parts = weekKey.split('-W');
      if (parts.length == 2) {
        final year = int.parse(parts[0]);
        final week = int.parse(parts[1]);
        // Berechne Start-Datum der Woche (Montag)
        final jan4 = DateTime(year, 1, 4);
        final daysToMonday = (jan4.weekday - 1) % 7;
        final firstMonday = jan4.subtract(Duration(days: daysToMonday));
        return firstMonday.add(Duration(days: (week - 1) * 7));
      }
    } catch (e) {
      // Fallback
    }
    return DateTime.now();
  }

  /// Extrahiert Wochendatum aus weekKey (z.B. "2024-W52" → 52)
  static int? _extractWeekNumber(String weekKey) {
    try {
      final parts = weekKey.split('-W');
      if (parts.length == 2) {
        return int.parse(parts[1]);
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  /// Wählt ein passendes Emoji basierend auf den Rezepten der Woche
  static String _getWeekEmoji(List<Recipe> recipes) {
    // Analysiere Rezepte und wähle passendes Emoji
    final titles = recipes.map((r) => r.title.toLowerCase()).join(' ');
    
    if (titles.contains('pasta') || titles.contains('nudel')) return '🍝';
    if (titles.contains('salat') || titles.contains('salad')) return '🥗';
    if (titles.contains('fisch') || titles.contains('fish')) return '🐟';
    if (titles.contains('hähnchen') || titles.contains('chicken')) return '🍗';
    if (titles.contains('pizza')) return '🍕';
    if (titles.contains('curry')) return '🍛';
    if (titles.contains('suppe') || titles.contains('soup')) return '🍲';
    
    // Default: Emoji basierend auf erstem Rezept
    if (recipes.isNotEmpty) {
      final firstTitle = recipes.first.title.toLowerCase();
      if (firstTitle.contains('pasta')) return '🍝';
      if (firstTitle.contains('salat')) return '🥗';
      if (firstTitle.contains('fisch')) return '🐟';
      if (firstTitle.contains('hähnchen')) return '🍗';
    }
    
    return '🍽️'; // Fallback
  }

  /// Fallback-Wochen falls keine Rezepte vorhanden
  static List<RecipeWeek> _generateFallbackWeeks() {
    final now = DateTime.now();
    final currentWeek = _getWeekNumber(now);
    
    return List.generate(3, (index) {
      final weekNum = currentWeek - index;
      return RecipeWeek(
        id: '${now.year}-W$weekNum',
        weekNumber: 'Woche $weekNum',
        recipeCount: 7 + index * 2,
        subtitle: 'Basierend auf Angeboten',
        imageUrl: ['🍝', '🥗', '🍗'][index],
        recipes: [],
        weekStart: now.subtract(Duration(days: index * 7)),
      );
    });
  }

  /// Berechnet Kalenderwoche
  static int _getWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }
}
