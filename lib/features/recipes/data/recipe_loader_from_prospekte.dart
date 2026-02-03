/// Recipe Loader - Lädt Rezepte direkt aus assets/prospekte/
/// 
/// Erkennt dynamisch alle <market>_recipes.json Dateien über AssetManifest.json
/// Unterstützt auch Unterordner: assets/prospekte/<market>/<subfolder>/<market>_recipes.json
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../data/models/recipe.dart';
import '../../../data/models/recipe_offer.dart';
import '../../../data/models/extra_ingredient.dart';
import '../../../utils/week.dart';
import '../../../data/services/supermarket_recipe_repository.dart';
import '../utils/recipe_image_path_resolver.dart';
import '../../../core/diagnostics/startup_diagnostics.dart';

class RecipeLoaderFromProspekte {
  // Cache für entdeckte Recipe-Dateien
  static Map<String, String>? _discoveredRecipeFilesCache;
  
  // Cache für Market Diagnostics
  static Map<String, MarketDiagnostics>? _marketDiagnosticsCache;

  /// Lädt Asset Manifest und extrahiert alle Asset-Pfade
  /// Extrahiert alle Asset-Pfade robust (unterstützt verschiedene Strukturen)
  static Future<List<String>> _getAllAssetPaths() async {
    try {
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      final manifestData = json.decode(manifestString);

      final allPaths = <String>[];

      if (manifestData is Map) {
        // Struktur: Map<String, dynamic> oder Map<String, List<dynamic>>
        for (final entry in manifestData.entries) {
          final key = entry.key.toString();
          
          // Normalisiere Pfade (entferne doppelte "assets/assets")
          String normalizedKey = key;
          if (normalizedKey.startsWith('assets/assets/')) {
            normalizedKey = normalizedKey.substring(7); // Entferne "assets/"
            if (kDebugMode) {
              debugPrint('⚠️  Normalized path: $key -> $normalizedKey');
            }
          }
          
          allPaths.add(normalizedKey);
          
          // Wenn Value eine Liste ist, füge auch diese Pfade hinzu
          if (entry.value is List) {
            for (final item in (entry.value as List)) {
              if (item is String) {
                String normalizedItem = item;
                if (normalizedItem.startsWith('assets/assets/')) {
                  normalizedItem = normalizedItem.substring(7);
                }
                if (!allPaths.contains(normalizedItem)) {
                  allPaths.add(normalizedItem);
                }
              }
            }
          }
        }
      } else if (manifestData is List) {
        // Struktur: List<dynamic>
        for (final item in manifestData) {
          if (item is String) {
            String normalizedItem = item;
            if (normalizedItem.startsWith('assets/assets/')) {
              normalizedItem = normalizedItem.substring(7);
            }
            allPaths.add(normalizedItem);
          }
        }
      }

      return allPaths;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Could not load AssetManifest.json: $e');
      }
      return [];
    }
  }

  /// Entdeckt alle Recipe-JSON-Dateien dynamisch aus AssetManifest
  /// Unterstützt verschiedene Strukturen:
  /// - assets/prospekte/<market>/<market>_recipes.json
  /// - assets/prospekte/<market>/<subfolder>/<market>_recipes.json
  /// Filter: prefix == "assets/prospekte/" AND suffix == "_recipes.json"
  static Future<Map<String, String>> discoverRecipeFiles() async {
    if (_discoveredRecipeFilesCache != null) {
      return _discoveredRecipeFilesCache!;
    }

    final allAssetPaths = await _getAllAssetPaths();
    final recipeFiles = <String, String>{};

    if (kDebugMode) {
      debugPrint('🔍 Scanning ${allAssetPaths.length} assets for recipe JSONs...');
      
      // Debug: Zeige alle Pfade die "prospekte" enthalten
      final prospektePaths = allAssetPaths.where((p) => p.contains('prospekte')).toList();
      debugPrint('   → Found ${prospektePaths.length} paths containing "prospekte"');
      if (prospektePaths.isNotEmpty) {
        debugPrint('   → Sample prospekte paths:');
        for (final path in prospektePaths.take(10)) {
          debugPrint('      - $path');
        }
      }
      
      // Debug: Zeige alle JSON-Dateien unter prospekte
      final prospekteJsonPaths = allAssetPaths.where((p) => 
        p.startsWith('assets/prospekte/') && p.endsWith('.json')
      ).toList();
      debugPrint('   → Found ${prospekteJsonPaths.length} JSON files under assets/prospekte/');
      if (prospekteJsonPaths.isNotEmpty) {
        debugPrint('   → All prospekte JSON files:');
        for (final path in prospekteJsonPaths) {
          debugPrint('      - $path');
        }
      }
    }

    // Schritt 1: Suche nach *_recipes.json Dateien (Priorität)
    for (final path in allAssetPaths) {
      if (path.startsWith('assets/prospekte/') && path.endsWith('_recipes.json')) {
        final parts = path.split('/');
        if (parts.length >= 3 && parts[0] == 'assets' && parts[1] == 'prospekte') {
          final market = parts[2];
          final filename = parts.last;
          
          if (filename == '${market}_recipes.json') {
            recipeFiles[market] = path;
            if (kDebugMode) {
              debugPrint('✅ Found recipe file: $market -> $path');
            }
          }
        }
      }
    }

    // Strict mode (release-ready): only accept *_recipes.json.
    // Any other *.json under assets/prospekte is treated as WRONG FILENAME and will be ignored.
    if (kDebugMode) {
      for (final path in allAssetPaths) {
        if (path.startsWith('assets/prospekte/') &&
            path.endsWith('.json') &&
            !path.endsWith('_recipes.json')) {
          debugPrint('❌ Wrong recipe filename (ignored): $path');
          debugPrint('   Fix: rename to assets/prospekte/<market>/<market>_recipes.json');
        }
      }
    }

    if (kDebugMode) {
      debugPrint('📄 Total recipe JSON files found: ${recipeFiles.length}');
      if (recipeFiles.isNotEmpty) {
        debugPrint('   Markets: ${recipeFiles.keys.join(', ')}');
        debugPrint('   Sample paths:');
        for (final entry in recipeFiles.entries.take(5)) {
          debugPrint('     - ${entry.key}: ${entry.value}');
        }
      }
    }

    _discoveredRecipeFilesCache = recipeFiles;
    return recipeFiles;
  }

  /// Lädt alle Rezepte für einen bestimmten Markt
  static Future<List<Recipe>> loadRecipesForMarket(String market) async {
    try {
      final recipeFiles = await discoverRecipeFiles();
      final recipePath = recipeFiles[market.toLowerCase()];

      if (recipePath == null) {
        if (kDebugMode) {
          debugPrint('⚠️  No recipe file found for market: $market');
          debugPrint('   Available markets: ${recipeFiles.keys.join(', ')}');
        }
        return <Recipe>[];
      }

      return await _loadRecipesFromPath(recipePath, market);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading recipes for market $market: $e');
      }
      return <Recipe>[];
    }
  }

  /// Lädt alle Rezepte von allen verfügbaren Märkten
  /// Gibt auch Market Diagnostics zurück (für StartupDiagnostics)
  static Future<List<Recipe>> loadAllRecipes() async {
    final allRecipes = <Recipe>[];
    final recipeFiles = await discoverRecipeFiles();
    _marketDiagnosticsCache = {};

    for (final entry in recipeFiles.entries) {
      final market = entry.key;
      final recipePath = entry.value;

      try {
        final result = await _loadRecipesFromPathWithDiagnostics(recipePath, market);
        allRecipes.addAll(result.recipes);
        _marketDiagnosticsCache![market] = result.diagnostics;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️  Skipped market $market due to error: $e');
        }
        // Erstelle Diagnostics für fehlgeschlagenen Market
        _marketDiagnosticsCache![market] = MarketDiagnostics(
          market: market,
          recipeFilePath: recipePath,
          jsonParseError: e.toString(),
        );
      }
    }

    // Logge Markets ohne *_recipes.json (z.B. aldi_nord)
    // Diese werden bereits beim discoverRecipeFiles() gefiltert, aber für Klarheit loggen
    if (kDebugMode && recipeFiles.isEmpty) {
      debugPrint('⚠️  No recipe files found matching pattern: assets/prospekte/<market>/<market>_recipes.json');
    }

    return allRecipes;
  }

  /// Gibt Market Diagnostics zurück (nach loadAllRecipes aufgerufen)
  static Map<String, MarketDiagnostics>? getMarketDiagnostics() {
    return _marketDiagnosticsCache;
  }

  /// Lädt Rezepte aus einer bestimmten Datei (alte Methode, für Kompatibilität)
  static Future<List<Recipe>> _loadRecipesFromPath(
    String recipePath,
    String market,
  ) async {
    final result = await _loadRecipesFromPathWithDiagnostics(recipePath, market);
    return result.recipes;
  }

  /// Lädt Rezepte aus einer bestimmten Datei mit Diagnostics
  static Future<({List<Recipe> recipes, MarketDiagnostics diagnostics})> _loadRecipesFromPathWithDiagnostics(
    String recipePath,
    String market,
  ) async {
    final recipes = <Recipe>[];
    final skipReasons = <String>[];
    final invalidIds = <String>[];
    final missingImages = <String>[];
    String? jsonParseError;

    try {
      final jsonString = await rootBundle.loadString(recipePath);
      dynamic jsonData;
      
      try {
        jsonData = json.decode(jsonString);
      } catch (e) {
        jsonParseError = e.toString();
        return (
          recipes: <Recipe>[],
          diagnostics: MarketDiagnostics(
            market: market,
            recipeFilePath: recipePath,
            jsonParseError: jsonParseError,
          ),
        );
      }

      // Handle both array and object with 'recipes' key (strict)
      List recipesList;
      if (jsonData is List) {
        recipesList = jsonData;
      } else if (jsonData is Map && jsonData.containsKey('recipes')) {
        recipesList = jsonData['recipes'] as List;
      } else if (jsonData is Map && jsonData.containsKey('items')) {
        recipesList = jsonData['items'] as List;
      } else {
        jsonParseError = 'Unknown JSON structure (expected List or Map with "recipes" or "items")';
        if (kDebugMode) {
          debugPrint('❌ $jsonParseError');
          debugPrint('   File: $recipePath');
          if (jsonData is Map) {
            debugPrint('   Available keys: ${jsonData.keys.join(", ")}');
          } else {
            debugPrint('   Available keys: N/A');
          }
        }
        return (
          recipes: <Recipe>[],
          diagnostics: MarketDiagnostics(
            market: market,
            recipeFilePath: recipePath,
            jsonParseError: jsonParseError,
          ),
        );
      }

      // Track Image-Pfad-Strategie für Diagnostics
      String? imagePathStrategy;
      String? exampleImagePath;
      int imagesFoundInRecipes = 0;
      int imagesFoundInRoot = 0;

      // Convert JSON to Recipe objects
      for (final item in recipesList) {
        try {
          if (item is Map<String, dynamic>) {
            // Normalisiere Recipe-ID: Versuche id, recipe_id, etc.
            final rawId = (item['id'] ?? item['recipe_id'])?.toString().trim();
            
            if (rawId == null || rawId.isEmpty) {
              skipReasons.add('Empty recipe ID');
              continue;
            }

            // Normalisiere ID zu R### Format
            final normalizedId = _normalizeRecipeId(rawId);
            
            // Validiere: Muss R### Format sein
            if (!RegExp(r'^R\d{3}$').hasMatch(normalizedId)) {
              invalidIds.add(rawId);
              skipReasons.add('Invalid ID format (expected R###)');
              continue;
            }

            // Setze normalisierte ID zurück ins JSON
            final recipeJson = Map<String, dynamic>.from(item);
            recipeJson['id'] = normalizedId;

            // Lade Rezept
            final recipe = await _recipeFromJson(recipeJson, market);
            
            // Prüfe ob Bild existiert und tracke Strategie
            if (recipe.heroImageUrl != null && recipe.heroImageUrl!.isNotEmpty) {
              // Bestimme welche Strategie verwendet wurde
              if (recipe.heroImageUrl!.contains('/recipes/')) {
                imagesFoundInRecipes++;
                if (imagePathStrategy == null) {
                  imagePathStrategy = 'recipes/';
                  exampleImagePath = recipe.heroImageUrl;
                }
              } else {
                imagesFoundInRoot++;
                if (imagePathStrategy == null) {
                  imagePathStrategy = 'root';
                  exampleImagePath = recipe.heroImageUrl;
                }
              }
            } else {
              missingImages.add('${market}_$normalizedId');
            }
            
            recipes.add(recipe);
          }
        } catch (e) {
          skipReasons.add('Parse error: ${e.toString().substring(0, e.toString().length.clamp(0, 50))}');
        }
      }

      // Bestimme primäre Strategie (meiste Treffer)
      if (imagePathStrategy == null && (imagesFoundInRecipes > 0 || imagesFoundInRoot > 0)) {
        if (imagesFoundInRecipes >= imagesFoundInRoot) {
          imagePathStrategy = 'recipes/';
        } else {
          imagePathStrategy = 'root';
        }
      }

      // Strict: only *_recipes.json is accepted by discovery.
      final recipesFileUsed = 'recipes.json';

      return (
        recipes: recipes,
        diagnostics: MarketDiagnostics(
          market: market,
          recipeFilePath: recipePath,
          recipesFileUsed: recipesFileUsed,
          recipesLoaded: recipes.length,
          recipesSkipped: recipesList.length - recipes.length,
          skipReasons: skipReasons,
          invalidIds: invalidIds,
          missingImages: missingImages,
          jsonParseError: jsonParseError,
          imagePathStrategy: imagePathStrategy,
          exampleImagePath: exampleImagePath,
          imageRenderMode: 'asset', // MUSS asset sein für Asset-Pfade
        ),
      );
    } catch (e) {
      jsonParseError = e.toString();
      return (
        recipes: <Recipe>[],
        diagnostics: MarketDiagnostics(
          market: market,
          recipeFilePath: recipePath,
          jsonParseError: jsonParseError,
        ),
      );
    }
  }

  /// Normalisiert Recipe-ID zu R### Format
  /// Unterstützt: R001, r001, R1, 1, "001", etc.
  static String _normalizeRecipeId(String rawId) {
    if (rawId.isEmpty) return '';
    
    // Entferne Whitespace
    String cleaned = rawId.trim();
    
    // Entferne Präfixe wie "recipe_", "id_", etc.
    if (cleaned.contains('_')) {
      final parts = cleaned.split('_');
      cleaned = parts.last;
    }
    
    // Extrahiere Zahl (unterstützt R001, r001, R1, 1, etc.)
    final regex = RegExp(r'[rR]?(\d+)');
    final match = regex.firstMatch(cleaned);
    
    if (match != null) {
      final numStr = match.group(1);
      if (numStr != null) {
        final num = int.tryParse(numStr);
        if (num != null) {
          return 'R${num.toString().padLeft(3, '0')}';
      }
      }
    }
    
    // Fallback: Uppercase und hoffe es ist schon richtig
    return cleaned.toUpperCase();
  }

  /// Konvertiert JSON zu Recipe-Objekt
  static Future<Recipe> _recipeFromJson(Map<String, dynamic> json, String market) async {
    try {
      final recipeJson = Map<String, dynamic>.from(json);

      // Set market IMMER (aus Ordnername)
      recipeJson['market'] = market;
      if (!recipeJson.containsKey('retailer') && !recipeJson.containsKey('supermarket')) {
        recipeJson['retailer'] = market;
      }

      // Map shortTitle to title if title is missing
      if (!recipeJson.containsKey('title') && recipeJson.containsKey('shortTitle')) {
        recipeJson['title'] = recipeJson['shortTitle'];
      }

      // Map cookTimeMinutes to durationMinutes if missing
      if (!recipeJson.containsKey('durationMinutes') &&
          recipeJson.containsKey('cookTimeMinutes')) {
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

      // Setze Image-Pfad basierend auf Market + Recipe-ID (strikt: assets/images/<market>_<recipeId>.png)
      final recipeId = recipeJson['id']?.toString() ?? '';
      if (RegExp(r'^R\d{3}$').hasMatch(recipeId)) {
        final imagePath = await RecipeImagePathResolver.resolveImagePath(
          market: market,
          recipeId: recipeId,
        );
        // Setze imagePath nur wenn gefunden (sonst bleibt null/leer für Diagnostics)
        if (imagePath != null && imagePath.isNotEmpty) {
        recipeJson['heroImageUrl'] = imagePath;
          recipeJson['image_path'] = imagePath; // Auch für Kompatibilität
        }
      }

      // Erweitere JSON um image/image_spec Schema (wenn nicht bereits vorhanden)
      if (!recipeJson.containsKey('image')) {
        final imageSchema = SupermarketRecipeRepository.buildImageSchema(
          recipeJson,
          market,
        );
        // FIX: Setze asset_path auf bereits aufgelösten heroImageUrl (korrekter Pfad)
        if (recipeJson['heroImageUrl'] != null && 
            imageSchema['source'] == 'asset' && 
            recipeJson['heroImageUrl'].toString().startsWith('assets/')) {
          imageSchema['asset_path'] = recipeJson['heroImageUrl'];
        }
        recipeJson['image'] = imageSchema;
      }
      if (!recipeJson.containsKey('image_spec')) {
        recipeJson['image_spec'] = SupermarketRecipeRepository.buildImageSpec(recipeJson);
      }

      return Recipe.fromJson(recipeJson);
    } catch (e) {
      // Fallback für alte Format-Kompatibilität
      if (kDebugMode) {
        debugPrint('⚠️  Error parsing recipe JSON, using fallback: $e');
      }

      // Extract ingredients as simple strings
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
        retailer: market,
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
        market: market,
      );
    }
  }

  /// Cleared Cache (für Debugging/Tests)
  static void clearCache() {
    _discoveredRecipeFilesCache = null;
    _marketDiagnosticsCache = null;
  }
}
