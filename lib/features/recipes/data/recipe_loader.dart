import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:roman_app/data/models/recipe.dart';

/// Index-Datenstruktur für Recipes
class RecipeIndex {
  final String generatedAt;
  final List<RecipeIndexMarket> markets;

  RecipeIndex({
    required this.generatedAt,
    required this.markets,
  });

  factory RecipeIndex.fromJson(Map<String, dynamic> json) {
    return RecipeIndex(
      generatedAt: json['generated_at'] ?? '',
      markets: (json['markets'] as List<dynamic>? ?? [])
          .map((m) => RecipeIndexMarket.fromJson(m))
          .toList(),
    );
  }
}

class RecipeIndexMarket {
  final String market;
  final String file;
  final int count;

  RecipeIndexMarket({
    required this.market,
    required this.file,
    required this.count,
  });

  factory RecipeIndexMarket.fromJson(Map<String, dynamic> json) {
    return RecipeIndexMarket(
      market: json['market'] ?? '',
      file: json['file'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

/// Loader für Offline-Rezepte aus Assets
class RecipeLoader {
  /// Lädt den Recipe-Index
  static Future<RecipeIndex> loadIndex() async {
    try {
      final String jsonString =
          await rootBundle.loadString('assets/recipes/recipes_index.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);
      return RecipeIndex.fromJson(jsonData);
    } catch (e) {
      throw Exception('Fehler beim Laden des Recipe-Index: $e');
    }
  }

  /// Lädt alle Rezepte für einen Market
  /// Neue Struktur: assets/recipes/<market>/<market>_recipes.json
  static Future<List<Recipe>> loadRecipesForMarket(String market) async {
    try {
      // Versuche neue Struktur: assets/recipes/<market>/<market>_recipes.json
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/recipes/$market/${market}_recipes.json');
      } catch (e) {
        // Fallback: alte Struktur assets/recipes/<market>_recipes.json
        jsonString = await rootBundle.loadString('assets/recipes/${market}_recipes.json');
      }
      
      final dynamic jsonData = json.decode(jsonString);

      List<Recipe> recipes = [];

      if (jsonData is List) {
        recipes = jsonData
            .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
            .toList();
      } else if (jsonData is Map && jsonData.containsKey('recipes')) {
        final recipesList = jsonData['recipes'] as List;
        recipes = recipesList
            .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
            .toList();
      }

      return recipes;
    } catch (e) {
      throw Exception(
          'Fehler beim Laden der Rezepte für $market: $e');
    }
  }

  /// Lädt alle Rezepte für alle Markets
  static Future<Map<String, List<Recipe>>> loadAllRecipes() async {
    final index = await loadIndex();
    final Map<String, List<Recipe>> allRecipes = {};

    for (final marketInfo in index.markets) {
      try {
        final recipes = await loadRecipesForMarket(marketInfo.market);
        allRecipes[marketInfo.market] = recipes;
      } catch (e) {
        // Logge Fehler, aber fahre mit anderen Markets fort
        print('⚠️  Fehler beim Laden von ${marketInfo.market}: $e');
      }
    }

    return allRecipes;
  }

  /// Lädt Rezepte für mehrere Markets
  static Future<Map<String, List<Recipe>>> loadRecipesForMarkets(
      List<String> markets) async {
    final Map<String, List<Recipe>> recipes = {};

    for (final market in markets) {
      try {
        recipes[market] = await loadRecipesForMarket(market);
      } catch (e) {
        print('⚠️  Fehler beim Laden von $market: $e');
      }
    }

    return recipes;
  }
}

