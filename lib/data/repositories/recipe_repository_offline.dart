import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../services/supermarket_recipe_repository.dart';

/// Offline Recipe Repository - Lädt Rezepte aus Assets
/// Neue Struktur: assets/recipes/<market>/<market>_recipes.json
class RecipeRepositoryOffline {
  /// Mapping von UI Retailer-Namen zu Asset-Market-Keys
  static const Map<String, String> _retailerToMarketKey = {
    'REWE': 'rewe',
    'EDEKA': 'edeka',
    'LIDL': 'lidl',
    'ALDI': 'aldi_nord',
    'ALDI NORD': 'aldi_nord',
    'ALDI SÜD': 'aldi_sued',
    'ALDI SUD': 'aldi_sued',
    'NETTO': 'netto',
    'KAUFLAND': 'kaufland',
    'PENNY': 'penny',
    'NORMA': 'norma',
    'NAHKAUF': 'nahkauf',
    'TEGUT': 'tegut',
    'BIOMARKT': 'biomarkt',
  };

  /// Lädt Rezepte für einen bestimmten Market aus Assets
  /// Neue Struktur: assets/recipes/<market>/<market>_recipes.json
  /// Fallback: assets/recipes/<market>_recipes.json (alte Struktur)
  static Future<List<Recipe>> loadRecipesForMarket(String market) async {
    try {
      final marketKey = _normalizeMarketKey(market);
      if (marketKey == null) {
        debugPrint('⚠️  Unbekannter Market: $market');
        return [];
      }

      // 1) Remote-first (weekly cached) if server is configured/reachable.
      try {
        final remote = await SupermarketRecipeRepository.loadSupermarketRecipes(marketKey);
        if (remote.isNotEmpty) {
          return remote;
        }
      } catch (_) {
        // ignore and fallback to assets
      }

      // Versuche neue Struktur: assets/recipes/<market>/<market>_recipes.json
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/recipes/$marketKey/${marketKey}_recipes.json');
      } catch (e) {
        // Fallback: alte Struktur assets/recipes/<market>_recipes.json
        try {
          jsonString = await rootBundle.loadString('assets/recipes/${marketKey}_recipes.json');
        } catch (e2) {
          debugPrint('⚠️  Keine Rezepte gefunden für $marketKey: $e2');
          return [];
        }
      }

      final dynamic jsonData = json.decode(jsonString);

      List<Recipe> recipes = [];

      if (jsonData is List) {
        recipes = jsonData
            .map((r) {
              try {
                final recipeMap = Map<String, dynamic>.from(r as Map);
                // Füge market Feld hinzu (falls nicht vorhanden)
                recipeMap['market'] ??= marketKey;
                return Recipe.fromJson(recipeMap);
              } catch (e) {
                debugPrint('⚠️  Fehler beim Parsen eines Rezepts: $e');
                return null;
              }
            })
            .whereType<Recipe>()
            .toList();
      } else if (jsonData is Map && jsonData.containsKey('recipes')) {
        final recipesList = jsonData['recipes'] as List;
        recipes = recipesList
            .map((r) {
              try {
                final recipeMap = Map<String, dynamic>.from(r as Map);
                recipeMap['market'] ??= marketKey;
                return Recipe.fromJson(recipeMap);
              } catch (e) {
                debugPrint('⚠️  Fehler beim Parsen eines Rezepts: $e');
                return null;
              }
            })
            .whereType<Recipe>()
            .toList();
      }

      // Sortiere nach ID (R001, R002, ...)
      recipes.sort((a, b) => a.id.compareTo(b.id));

      return recipes;
    } catch (e) {
      debugPrint('❌ Fehler beim Laden der Rezepte für $market: $e');
      return [];
    }
  }

  /// Normalisiert Market-Key (z.B. "ALDI NORD" -> "aldi_nord")
  static String? _normalizeMarketKey(String market) {
    final upper = market.toUpperCase().trim();
    
    // Direktes Mapping
    if (_retailerToMarketKey.containsKey(upper)) {
      return _retailerToMarketKey[upper];
    }
    
    // Prüfe ob Market-Key bereits normalisiert ist
    final lower = market.toLowerCase().trim();
    if (_retailerToMarketKey.containsValue(lower)) {
      return lower;
    }
    
    return null;
  }

  /// Lädt Rezepte für mehrere Markets
  static Future<Map<String, List<Recipe>>> loadRecipesForMarkets(
      List<String> markets) async {
    final Map<String, List<Recipe>> recipes = {};

    for (final market in markets) {
      try {
        final marketRecipes = await loadRecipesForMarket(market);
        final marketKey = _normalizeMarketKey(market);
        if (marketKey != null && marketRecipes.isNotEmpty) {
          recipes[marketKey] = marketRecipes;
        }
      } catch (e) {
        debugPrint('⚠️  Fehler beim Laden von $market: $e');
      }
    }

    return recipes;
  }

  /// Lädt alle verfügbaren Markets und deren Rezept-Anzahl
  static Future<Map<String, int>> getAvailableMarkets() async {
    final markets = <String, int>{};
    final marketKeys = _retailerToMarketKey.values.toSet();

    for (final marketKey in marketKeys) {
      try {
        final recipes = await loadRecipesForMarket(marketKey);
        if (recipes.isNotEmpty) {
          markets[marketKey] = recipes.length;
        }
      } catch (e) {
        // Market nicht verfügbar - ignorieren
      }
    }

    return markets;
  }
}

