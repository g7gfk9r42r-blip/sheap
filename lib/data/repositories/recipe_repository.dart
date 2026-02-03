import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/recipe.dart';
import '../models/recipe_offer.dart';
import '../models/extra_ingredient.dart';
import '../services/supermarket_recipe_repository.dart';
import '../services/image_validator.dart';
import '../../utils/week.dart';
import '../../features/recipes/data/recipe_loader_from_prospekte.dart';

class RecipeRepository {
  // Mapping from UI retailer names to asset file keys
  // EDEKA und DENNS entfernt, da keine Rezepte vorhanden
  static const Map<String, String> _retailerToAssetKey = {
    'REWE': 'rewe',
    'LIDL': 'lidl',
    'ALDI': 'aldi_nord', // Default to ALDI Nord, could be extended
    'ALDI NORD': 'aldi_nord',
    'ALDI SÜD': 'aldi_sued',
    'NETTO': 'netto',
    'KAUFLAND': 'kaufland',
    'PENNY': 'penny',
    'NORMA': 'norma',
    'NAHKAUF': 'nahkauf',
    'TEGUT': 'tegut',
    'BIOMARKT': 'biomarkt',
  };

  // Fallback: Bekannte Asset-Pfade (wenn AssetManifest nicht verfügbar)
  static const Map<String, String> _fallbackAssetPaths = {
    'rewe': 'assets/recipes/rewe/rewe_recipes.json',
    'lidl': 'assets/recipes/lidl/lidl_recipes.json',
    'aldi_nord': 'assets/recipes/aldi_nord/aldi_nord_recipes.json',
    'aldi_sued': 'assets/recipes/aldi_sued/aldi_sued_recipes.json',
    'netto': 'assets/recipes/netto/netto_recipes.json',
    'kaufland': 'assets/recipes/kaufland/kaufland_recipes.json',
    'penny': 'assets/recipes/penny/penny_recipes.json',
    'norma': 'assets/recipes/norma/norma_recipes.json',
    'nahkauf': 'assets/recipes/nahkauf/nahkauf_recipes.json',
    'tegut': 'assets/recipes/tegut/tegut_recipes.json',
    'biomarkt': 'assets/recipes/biomarkt/biomarkt_recipes.json',
  };

  // Cache für Asset Manifest
  static Map<String, dynamic>? _assetManifestCache;
  static Map<String, String>? _discoveredRecipeFilesCache;

  /// Lädt Asset Manifest und cached es
  static Future<Map<String, dynamic>?> _loadAssetManifest() async {
    if (_assetManifestCache != null) return _assetManifestCache;
    
    try {
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      _assetManifestCache = json.decode(manifestString) as Map<String, dynamic>;
      return _assetManifestCache;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Could not load AssetManifest.json: $e');
      }
      return null;
    }
  }

  /// Entdeckt alle Recipe-JSON-Dateien dynamisch aus AssetManifest
  // ignore: unused_element
  static Future<Map<String, String>> _discoverRecipeFiles() async {
    if (_discoveredRecipeFilesCache != null) {
      return _discoveredRecipeFilesCache!;
    }

    final manifest = await _loadAssetManifest();
    final recipeFiles = <String, String>{};

    if (manifest != null) {
      // Suche nach Recipe-JSON-Dateien im Manifest
      final recipePattern = RegExp(r'^assets/recipes/([^/]+)/([^/]+_recipes\.json)$');
      
      for (final key in manifest.keys) {
        if (key.contains('recipes') && key.endsWith('.json')) {
          final match = recipePattern.firstMatch(key);
          if (match != null) {
            final market = match.group(1)!;
            recipeFiles[market] = key;
          } else if (key.contains('_recipes.json')) {
            // Fallback: auch andere Strukturen erkennen
            final parts = key.split('/');
            if (parts.length >= 2) {
              final marketMatch = RegExp(r'^([^_]+)_recipes\.json$').firstMatch(parts.last);
              if (marketMatch != null) {
                final market = marketMatch.group(1)!;
                recipeFiles[market] = key;
              }
            }
          }
        }
      }
    }

    // Fallback: Verwende bekannte Pfade wenn Manifest leer ist
    if (recipeFiles.isEmpty) {
      if (kDebugMode) {
        debugPrint('ℹ️  AssetManifest empty, using fallback paths');
      }
      _discoveredRecipeFilesCache = Map<String, String>.from(_fallbackAssetPaths);
      return _discoveredRecipeFilesCache!;
    }

    _discoveredRecipeFilesCache = recipeFiles;
    return recipeFiles;
  }


  /// Load recipes from assets for a specific retailer
  /// Lädt direkt aus assets/prospekte/<market>/<market>_recipes.json
  static Future<List<Recipe>> loadRecipesFromAssets(String retailer) async {
    try {
      // Map retailer name to market key (normalize)
      final retailerUpper = retailer.toUpperCase();
      final assetKey = _retailerToAssetKey[retailerUpper];
      
      // Fallback: versuche direkt retailer als market zu verwenden
      final market = assetKey ?? retailer.toLowerCase();
      
      // Lade Rezepte direkt aus assets/prospekte/
      return await RecipeLoaderFromProspekte.loadRecipesForMarket(market);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading recipes from assets for $retailer: $e');
      }
      return <Recipe>[];
    }
  }

  /// Load all recipes from all available assets
  /// Lädt direkt aus assets/prospekte/
  static Future<List<Recipe>> loadAllRecipesFromAssets() async {
    return await RecipeLoaderFromProspekte.loadAllRecipes();
  }

  /// Validiert Bilder für alle Rezepte und gibt Ergebnis zurück
  static Future<ImageValidationResult> validateAllRecipeImages() async {
    final allRecipes = await loadAllRecipesFromAssets();
    return await ImageValidator.validateRecipeImages(allRecipes);
  }

  /// Validiert Bilder für einen spezifischen Markt
  static Future<ImageValidationResult> validateMarketRecipeImages(String retailer) async {
    final recipes = await loadRecipesFromAssets(retailer);
    return await ImageValidator.validateRecipeImages(recipes);
  }

  /// Convert asset JSON structure to Recipe model (DEPRECATED - wird nicht mehr verwendet)
  /// @deprecated Verwende RecipeLoaderFromProspekte stattdessen
  @Deprecated('Use RecipeLoaderFromProspekte instead')
  // ignore: unused_element
  static Recipe _recipeFromAssetJson(Map<String, dynamic> json, String retailer) {
    try {
      final recipeJson = Map<String, dynamic>.from(json);
      
      // Set retailer if missing
      if (!recipeJson.containsKey('retailer') && !recipeJson.containsKey('supermarket')) {
        recipeJson['retailer'] = retailer;
      } else if (recipeJson.containsKey('supermarket') && !recipeJson.containsKey('retailer')) {
        recipeJson['retailer'] = recipeJson['supermarket'];
      }
      
      // Map shortTitle to title if title is missing
      if (!recipeJson.containsKey('title') && recipeJson.containsKey('shortTitle')) {
        recipeJson['title'] = recipeJson['shortTitle'];
      }
      
      // Map cookTimeMinutes to durationMinutes if missing
      if (!recipeJson.containsKey('durationMinutes') && recipeJson.containsKey('cookTimeMinutes')) {
        recipeJson['durationMinutes'] = recipeJson['cookTimeMinutes'];
      }
      
      // Map prep_minutes + cook_minutes zu durationMinutes
      if (!recipeJson.containsKey('durationMinutes')) {
        final prep = recipeJson['prep_minutes'];
        final cook = recipeJson['cook_minutes'];
        if (prep != null && cook != null) {
          try {
            final prepInt = prep is int ? prep : (prep is num ? prep.toInt() : null);
            final cookInt = cook is int ? cook : (cook is num ? cook.toInt() : null);
            if (prepInt != null && cookInt != null) {
              recipeJson['durationMinutes'] = prepInt + cookInt;
            }
          } catch (e) {
            // Skip if conversion fails
          }
        }
      }
      
      // Set weekKey if missing
      if (!recipeJson.containsKey('weekKey') && !recipeJson.containsKey('week')) {
        recipeJson['weekKey'] = isoWeekKey(DateTime.now());
      }
      
      // Set createdAt if missing
      if (!recipeJson.containsKey('createdAt')) {
        recipeJson['createdAt'] = DateTime.now().toIso8601String();
      }
      
      // Set description if missing
      if (!recipeJson.containsKey('description')) {
        recipeJson['description'] = '';
      }
      
      // Map image_path zu heroImageUrl (wenn vorhanden)
      if (!recipeJson.containsKey('heroImageUrl') && recipeJson.containsKey('image_path')) {
        recipeJson['heroImageUrl'] = recipeJson['image_path'];
      }
      
      // Erweitere JSON um image/image_spec Schema (wenn nicht bereits vorhanden)
      if (!recipeJson.containsKey('image')) {
        recipeJson['image'] = SupermarketRecipeRepository.buildImageSchema(recipeJson, retailer);
      }
      if (!recipeJson.containsKey('image_spec')) {
        recipeJson['image_spec'] = SupermarketRecipeRepository.buildImageSpec(recipeJson);
      }
      
      // Parse calories from nutritionRange or nutrition_estimate if available
      if (!recipeJson.containsKey('calories')) {
        if (recipeJson.containsKey('nutritionRange')) {
          final nutrition = recipeJson['nutritionRange'] as Map<String, dynamic>?;
          if (nutrition != null && nutrition.containsKey('kcal')) {
            final kcal = nutrition['kcal'];
            if (kcal is List && kcal.isNotEmpty) {
              recipeJson['calories'] = (kcal[0] as num).toInt();
            }
          }
        } else if (recipeJson.containsKey('nutrition_estimate')) {
          final nutrition = recipeJson['nutrition_estimate'] as Map<String, dynamic>?;
          if (nutrition != null && nutrition.containsKey('kcal_per_portion')) {
            recipeJson['calories'] = nutrition['kcal_per_portion'];
          }
        }
      }
      
      return Recipe.fromJson(recipeJson);
    } catch (e) {
      // Fallback für alte Format-Kompatibilität
      if (kDebugMode) {
        debugPrint('⚠️  Error parsing recipe JSON, using fallback: $e');
      }
      
      // Extract ingredients as simple strings from the complex structure
      final ingredientsList = <String>[];
      if (json['ingredients'] is List) {
        for (final ing in json['ingredients'] as List) {
          if (ing is Map<String, dynamic> && ing['name'] != null) {
            final amount = ing['amount'] as String? ?? ing['amountText'] as String? ?? '';
            final name = ing['name'] as String;
            ingredientsList.add(amount.isNotEmpty ? '$name ($amount)' : name);
          } else if (ing is String) {
            ingredientsList.add(ing);
          }
        }
      }

      // Fallback Recipe creation
      return Recipe(
        id: json['id']?.toString() ?? 'unknown_id',
        title: json['title']?.toString() ?? json['name']?.toString() ?? 'Unbekanntes Rezept',
        description: json['description']?.toString() ?? '',
        ingredients: ingredientsList,
        retailer: retailer,
        weekKey: json['weekKey']?.toString() ?? isoWeekKey(DateTime.now()),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        calories: json['calories'] != null ? (json['calories'] as num).toInt() : null,
        price: json['price'] != null ? (json['price'] as num).toDouble() : null,
        savings: json['savings'] != null ? (json['savings'] as num).toDouble() : null,
        servings: json['servings'] != null ? (json['servings'] as num).toInt() : null,
        durationMinutes: json['durationMinutes'] != null ? (json['durationMinutes'] as num).toInt() : null,
        difficulty: json['difficulty']?.toString(),
        categories: (json['categories'] as List?)?.map((e) => e.toString()).toList(),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList(),
        steps: (json['steps'] as List?)?.map((e) => e.toString()).toList(),
        nutritionRange: json['nutritionRange'] != null
            ? RecipeNutritionRange.fromJson(json['nutritionRange'] as Map<String, dynamic>)
            : null,
        priceStandard: json['priceStandard'] != null ? (json['priceStandard'] as num).toDouble() : null,
        priceLoyalty: json['priceLoyalty'] != null ? (json['priceLoyalty'] as num).toDouble() : null,
        loyaltyCondition: json['loyaltyCondition']?.toString(),
        warnings: (json['warnings'] as List?)?.map((e) => e.toString()).toList(),
        heroImageUrl: json['heroImageUrl']?.toString() ?? json['image_path']?.toString(),
        image: json['image'] as Map<String, dynamic>?,
        imageSpec: json['image_spec'] as Map<String, dynamic>?,
        offersUsed: (json['offersUsed'] as List?)
            ?.map((e) => RecipeOfferUsed.fromJson(e as Map<String, dynamic>))
            .toList(),
        extraIngredients: (json['extraIngredients'] as List?)
            ?.map((e) => ExtraIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        market: json['market']?.toString(),
      );
    }
  }
}
