/// Asset Audit - Robust Asset Validation & Debug Output
/// 
/// Validiert alle Rezept-JSON-Dateien und Bilder beim App-Start.
/// Lädt direkt aus assets/prospekte/ und assets/images/
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../data/models/recipe.dart';
import '../../../features/recipes/data/recipe_loader_from_prospekte.dart';

class AssetAudit {
  static bool _hasRun = false;

  /// Führt vollständiges Asset-Audit durch
  /// Läuft nur einmal pro App-Start
  static Future<void> run() async {
    if (!kDebugMode) return;
    if (_hasRun) return;
    _hasRun = true;

    print('\n' + '=' * 80);
    print('🔍 ASSET AUDIT');
    print('=' * 80);

    try {
      // 1. Lade Asset Manifest und extrahiere alle Pfade
      final allAssetPaths = await _getAllAssetPaths();
      debugPrint('📦 Total assets in manifest: ${allAssetPaths.length}');
      
      if (allAssetPaths.isEmpty) {
        print('❌ ERROR: No assets found in AssetManifest.json');
        print('   → Check if pubspec.yaml assets are correctly configured');
        print('=' * 80 + '\n');
        return;
      }

      // Debug: Zeige erste 30 Asset-Pfade
      if (kDebugMode && allAssetPaths.length > 0) {
        debugPrint('📋 Sample asset paths (first ${allAssetPaths.length > 30 ? 30 : allAssetPaths.length}):');
        for (final path in allAssetPaths.take(30)) {
          debugPrint('   - $path');
        }
        if (allAssetPaths.length > 30) {
          debugPrint('   ... and ${allAssetPaths.length - 30} more');
        }
        
        // Debug: Zeige ALLE Pfade die "prospekte" enthalten
        final prospektePaths = allAssetPaths.where((p) => p.contains('prospekte')).toList();
        debugPrint('\n🔍 All paths containing "prospekte": ${prospektePaths.length}');
        for (final path in prospektePaths) {
          debugPrint('   - $path');
        }
        
        // Debug: Zeige ALLE JSON-Dateien unter prospekte
        final prospekteJsonPaths = allAssetPaths.where((p) => 
          p.startsWith('assets/prospekte/') && p.endsWith('.json')
        ).toList();
        debugPrint('\n📄 All JSON files under assets/prospekte/: ${prospekteJsonPaths.length}');
        for (final path in prospekteJsonPaths) {
          debugPrint('   - $path');
        }
      }

      // 2. Finde alle Rezept-JSON-Dateien (aus assets/prospekte/)
      final recipeFiles = _findRecipeJsonFiles(allAssetPaths);
      print('\n📄 Recipe JSON Files Found: ${recipeFiles.length}');
      
      if (recipeFiles.isEmpty) {
        print('   ⚠️  No recipe files found in assets/prospekte/');
        debugPrint('   → Filtered from ${allAssetPaths.length} total assets');
        debugPrint('   → Looking for: prefix="assets/prospekte/" suffix="_recipes.json"');
      } else {
        for (final entry in recipeFiles.entries) {
          print('   ✅ ${entry.key}: ${entry.value}');
        }
        debugPrint('   → Found ${recipeFiles.length} recipe JSON files');
      }

      // 3. Lade und parse alle Rezepte pro Market
      final recipesByMarket = <String, List<Recipe>>{};
      final marketErrors = <String, String>{};
      
      for (final entry in recipeFiles.entries) {
        final market = entry.key;
        final filePath = entry.value;
        try {
          final recipes = await RecipeLoaderFromProspekte.loadRecipesForMarket(market);
          recipesByMarket[market] = recipes;
          print('   ✅ $market: ${recipes.length} recipes loaded from $filePath');
        } catch (e) {
          marketErrors[market] = e.toString();
          recipesByMarket[market] = [];
          print('   ❌ $market: Failed to load (error: $e)');
        }
      }

      final totalRecipes = recipesByMarket.values.fold<int>(0, (sum, recipes) => sum + recipes.length);
      print('\n📊 Total Recipes: $totalRecipes loaded');

      // 4. Finde alle Rezept-Bilder (aus assets/images/, flat structure)
      final imageFiles = _findRecipeImageFiles(allAssetPaths);
      final totalImages = imageFiles.length;
      print('\n🖼️  Images: $totalImages found');

      // Gruppiere Bilder nach Markt (aus Dateinamen: <market>_R###.png)
      final imagesByMarket = <String, List<String>>{};
      for (final imagePath in imageFiles) {
        final market = _extractMarketFromImagePath(imagePath);
        if (market != null) {
          imagesByMarket.putIfAbsent(market, () => []).add(imagePath);
        }
      }

      if (imagesByMarket.isNotEmpty) {
        for (final entry in imagesByMarket.entries) {
          print('   • ${entry.key}: ${entry.value.length}');
        }
      } else {
        print('   ⚠️  No images found with market prefix');
      }

      // 5. Match Rezepte mit Bildern
      final allRecipes = recipesByMarket.values.expand((list) => list).toList();
      final matchingResults = await _matchRecipesWithImages(allRecipes, allAssetPaths);

      final totalMatched = matchingResults.values
          .fold<int>(0, (sum, data) => sum + (data['matched'] as int));
      final totalMissing = matchingResults.values
          .fold<int>(0, (sum, data) => sum + (data['missing'] as int));

      print('\n🔗 Matched: $totalMatched recipes have images');
      print('❌ Missing images: $totalMissing recipes without images');

      // Zeige Details pro Market
      if (matchingResults.isNotEmpty) {
        for (final entry in matchingResults.entries) {
          final market = entry.key;
          final data = entry.value;
          final matched = data['matched'] as int;
          final missing = data['missing'] as int;
          final total = matched + missing;
          if (total > 0) {
            final percentage = ((matched / total) * 100).toStringAsFixed(1);
            print('   • $market: $matched/$total matched ($percentage%)');
          }
        }
      }

      // 6. Zeige fehlende Bilder (erste 10)
      final missingImagePaths = matchingResults.values
          .expand((data) => data['missingPaths'] as List<String>)
          .toList();

      if (missingImagePaths.isNotEmpty) {
        print('\n   Missing image paths (first ${missingImagePaths.length > 10 ? 10 : missingImagePaths.length}):');
        for (final path in missingImagePaths.take(10)) {
          print('   - $path');
        }
        if (missingImagePaths.length > 10) {
          print('   ... and ${missingImagePaths.length - 10} more');
        }
      }

      print('=' * 80 + '\n');
    } catch (e, stackTrace) {
      print('\n❌ ERROR during asset audit:');
      print('   $e');
      if (kDebugMode) {
        print('   Stack trace: $stackTrace');
      }
      print('=' * 80 + '\n');
    }
  }

  /// Reset für Tests
  static void reset() {
    _hasRun = false;
  }

  /// Lädt Asset Manifest und extrahiert alle Asset-Pfade
  /// Unterstützt verschiedene Manifest-Strukturen:
  /// - Map<String, dynamic>
  /// - Map<String, List<dynamic>>
  /// - List<dynamic> (selten)
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
            debugPrint('⚠️  Normalized path: $key -> $normalizedKey');
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
      debugPrint('❌ Failed to load AssetManifest.json: $e');
      return [];
    }
  }

  /// Findet alle Rezept-JSON-Dateien
  /// Filter: prefix == "assets/prospekte/" AND suffix == "_recipes.json"
  /// Unterstützt auch Unterordner: assets/prospekte/<market>/<subfolder>/<market>_recipes.json
  static Map<String, String> _findRecipeJsonFiles(List<String> allAssetPaths) {
    final recipeFiles = <String, String>{};

    if (kDebugMode) {
      debugPrint('🔍 _findRecipeJsonFiles: Scanning ${allAssetPaths.length} paths...');
      
      // Zeige alle prospekte-Pfade
      final prospektePaths = allAssetPaths.where((p) => p.contains('prospekte')).toList();
      debugPrint('   → Found ${prospektePaths.length} paths containing "prospekte"');
      if (prospektePaths.isNotEmpty) {
        debugPrint('   → Sample prospekte paths:');
        for (final path in prospektePaths.take(10)) {
          debugPrint('      - $path');
        }
      }
      
      // Zeige alle JSON-Dateien unter prospekte
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

    for (final path in allAssetPaths) {
      // Filter: prefix == "assets/prospekte/" AND suffix == "_recipes.json"
      // IGNORIERE: <market>.json (nur *_recipes.json)
      if (path.startsWith('assets/prospekte/') && path.endsWith('_recipes.json')) {
        final parts = path.split('/');
        if (parts.length >= 3 && parts[0] == 'assets' && parts[1] == 'prospekte') {
          final market = parts[2];
          final filename = parts.last;
          if (filename == '${market}_recipes.json') {
            recipeFiles[market] = path;
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint('📄 Found ${recipeFiles.length} recipe JSON files');
      if (recipeFiles.isNotEmpty) {
        debugPrint('   Sample paths:');
        for (final entry in recipeFiles.entries.take(5)) {
          debugPrint('     - ${entry.key}: ${entry.value}');
        }
      } else {
        debugPrint('   ⚠️  No recipe files found!');
      }
    }

    return recipeFiles;
  }

  /// Findet alle Rezept-Bilder im Asset Manifest
  /// Format: assets/images/<market>_R###.png (flat structure)
  static List<String> _findRecipeImageFiles(List<String> allAssetPaths) {
    final imageFiles = <String>[];
    final imageExtensions = ['.png', '.jpg', '.jpeg', '.webp'];

    for (final path in allAssetPaths) {
      if (path.startsWith('assets/images/')) {
        final hasImageExtension =
            imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
        if (hasImageExtension) {
          // Nur Dateien direkt unter assets/images/ (flat structure)
          // Format: assets/images/<market>_R###.png
          final parts = path.split('/');
          if (parts.length == 3 && parts[0] == 'assets' && parts[1] == 'images') {
            imageFiles.add(path);
          }
        }
      }
    }

    return imageFiles;
  }

  /// Extrahiert Markt-Namen aus Bild-Pfad
  /// Format: assets/images/<market>_R###.png
  /// Extrahiert Market aus Dateinamen-Pattern: "<market>_R"
  static String? _extractMarketFromImagePath(String imagePath) {
    // Pattern: assets/images/<market>_R###.png
    // Extrahiere Dateinamen
    final parts = imagePath.split('/');
    if (parts.length < 3) return null;
    
    final filename = parts.last;
    // Pattern: <market>_R###.png
    final match = RegExp(r'^([^_]+)_R\d+\.').firstMatch(filename);
    if (match != null) {
      return match.group(1);
    }
    
    return null;
  }

  /// Matcht Rezepte mit Bildern
  /// Für jedes Rezept: bilde erwarteten Bildnamen:
  /// "<market>_<recipe_id>.<ext>"
  /// wobei recipe_id im JSON z.B. "R042" ist.
  static Future<Map<String, Map<String, dynamic>>> _matchRecipesWithImages(
    List<Recipe> recipes,
    List<String> allAssetPaths,
  ) async {
    final results = <String, Map<String, dynamic>>{};
    
    // Konvertiere zu Set für schnelleres Lookup
    final assetPathsSet = allAssetPaths.toSet();

    // Gruppiere Rezepte nach Markt
    final recipesByMarket = <String, List<Recipe>>{};
    for (final recipe in recipes) {
      final market = (recipe.market ?? recipe.retailer.toLowerCase()).trim();
      recipesByMarket.putIfAbsent(market, () => []).add(recipe);
    }

    for (final entry in recipesByMarket.entries) {
      final market = entry.key;
      final marketRecipes = entry.value;

      int matched = 0;
      int missing = 0;
      final missingPaths = <String>[];

      for (final recipe in marketRecipes) {
        // Bilde erwarteten Bildnamen: "<market>_<recipe_id>.<ext>"
        final recipeId = recipe.id.toUpperCase().trim();
        final extensions = ['.png', '.jpg', '.jpeg', '.webp'];
        
        bool hasImage = false;
        String? expectedPath;

        // Prüfe alle möglichen Datei-Endungen
        for (final ext in extensions) {
          final imagePath = 'assets/images/${market}_$recipeId$ext';
          if (assetPathsSet.contains(imagePath)) {
            hasImage = true;
            break;
          }
          // Setze erwarteten Pfad für Fehlermeldung (nur einmal)
          if (expectedPath == null) {
            expectedPath = imagePath;
          }
        }

        if (hasImage) {
          matched++;
        } else {
          missing++;
          if (expectedPath != null) {
            missingPaths.add(expectedPath);
          }
        }
      }

      results[market] = {
        'matched': matched,
        'missing': missing,
        'missingPaths': missingPaths,
      };
    }

    return results;
  }
}
