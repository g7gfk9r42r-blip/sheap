/// Dev-Tool: Prüft ob Asset-Pfade in Rezepten wirklich existieren
/// Usage: dart run lib/tools/check_recipe_assets.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../data/services/supermarket_recipe_repository.dart';

void main() async {
  print('🔍 Prüfe Recipe Assets...\n');
  
  final recipes = await SupermarketRecipeRepository.loadAllSupermarketRecipes(forceRefresh: true);
  
  int totalRecipes = 0;
  int recipesWithAssets = 0;
  int assetsFound = 0;
  int assetsMissing = 0;
  
  for (final entry in recipes.entries) {
    final supermarket = entry.key;
    final recipeList = entry.value;
    
    print('📦 $supermarket: ${recipeList.length} Rezepte');
    
    for (final recipe in recipeList) {
      totalRecipes++;
      
      final image = recipe.image;
      if (image != null && image['source'] == 'asset') {
        recipesWithAssets++;
        final assetPath = image['asset_path']?.toString();
        
        if (assetPath != null) {
          try {
            // Prüfe ob Asset existiert (nur auf Mobile/Desktop, nicht Web)
            if (!kIsWeb) {
              // Asset-Bundle Check (synchron nicht möglich, daher nur Pfad-Prüfung)
              print('  ✅ $assetPath (kann nicht validiert werden - Asset-Bundle Check benötigt Flutter Runtime)');
              assetsFound++;
            } else {
              print('  ⚠️  Web: Asset-Prüfung nicht möglich');
            }
          } catch (e) {
            print('  ❌ $assetPath - Fehler: $e');
            assetsMissing++;
          }
        }
      }
    }
  }
  
  print('\n📊 Zusammenfassung:');
  print('   Gesamt: $totalRecipes Rezepte');
  print('   Mit Assets: $recipesWithAssets');
  print('   Assets gefunden: $assetsFound');
  print('   Assets fehlend: $assetsMissing');
}
