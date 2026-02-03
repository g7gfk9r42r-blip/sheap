/// RecipeJsonWriter
/// Schreibt Rezepte als JSON-Dateien in assets/recipes/
/// 
/// Format: assets/recipes/recipes_<supermarket>.json
/// Output-Format:
/// [
///   {
///     "title": "...",
///     "ingredients": [{"name": "...", "amount": "..."}],
///     "priceEstimate": 4.79,
///     "instructions": "...",
///     "source": "GPT",
///     "supermarket": "REWE"
///   }
/// ]

import 'dart:convert';
import 'dart:io';

class RecipeJsonWriter {
  /// Schreibt Rezepte als JSON-Datei im neuen Format
  /// 
  /// [recipes] - Liste der zu speichernden Rezepte (Map<String, dynamic>)
  /// [outputDir] - Ausgabeverzeichnis (z.B. "assets/recipes")
  static Future<void> writeRecipes({
    required List<Map<String, dynamic>> recipes,
    required String outputDir,
  }) async {
    if (recipes.isEmpty) {
      print('⚠️  No recipes to write');
      return;
    }

    // Gruppiere nach Supermarket
    final recipesBySupermarket = <String, List<Map<String, dynamic>>>{};
    for (final recipe in recipes) {
      final supermarket = recipe['supermarket'] as String? ?? 'UNKNOWN';
      recipesBySupermarket.putIfAbsent(supermarket, () => []).add(recipe);
    }

    // Erstelle Ausgabeverzeichnis
    final directory = Directory(outputDir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('📁 Created directory: $outputDir');
    }

    // Schreibe für jeden Supermarket eine Datei
    for (final entry in recipesBySupermarket.entries) {
      final supermarket = entry.key;
      final supermarketRecipes = entry.value;
      
      // Bestimme Dateinamen: recipes_<supermarket>.json
      final filename = 'recipes_${supermarket.toLowerCase()}.json';
      final filePath = '${directory.path}/$filename';

      // Konvertiere zu JSON (bereits im richtigen Format)
      final jsonString = const JsonEncoder.withIndent('  ').convert(supermarketRecipes);

      // Schreibe Datei
      final file = File(filePath);
      await file.writeAsString(jsonString);
      
      print('✅ Wrote ${supermarketRecipes.length} recipes to $filePath');
    }
  }
}
