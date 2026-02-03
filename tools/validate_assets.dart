import 'dart:convert';
import 'dart:io';

/// Validation Tool für Assets (Debug/CLI)
/// 
/// Nutzung: dart run tools/validate_assets.dart
/// 
/// Prüft:
/// - Asset-Index lädt korrekt
/// - Beispiel-Rezepte haben Bilder
/// - Pfade sind korrekt

Future<void> main() async {
  print('🔍 Asset Validation Tool\n');
  
  try {
    // Lade Asset-Index
    final indexFile = File('assets/index/asset_index.json');
    if (!indexFile.existsSync()) {
      print('❌ asset_index.json nicht gefunden!');
      print('   Führe zuerst aus: python3 tools/build_offline_assets.py');
      exit(1);
    }
    
    final indexContent = await indexFile.readAsString();
    final index = json.decode(indexContent) as Map<String, dynamic>;
    
    print('✅ Asset-Index geladen');
    print('   Markets: ${index['recipes']?.length ?? 0}');
    
    final recipeMarkets = (index['recipes'] as List<dynamic>?)?.cast<String>() ?? [];
    final imageMarkets = (index['recipe_images'] as Map<String, dynamic>?)?.keys.toList() ?? [];
    
    print('\n📋 Verfügbare Markets:');
    for (final market in recipeMarkets) {
      final imageCount = (index['recipe_images']?[market] as List<dynamic>?)?.length ?? 0;
      print('   - $market: ${imageCount} Bilder');
    }
    
    // Prüfe Beispiel-Rezepte
    print('\n🔍 Prüfe Beispiel-Rezepte:');
    for (final market in recipeMarkets.take(3)) {
      final imageIds = (index['recipe_images']?[market] as List<dynamic>?)?.cast<String>() ?? [];
      if (imageIds.isNotEmpty) {
        final exampleId = imageIds.first;
        final expectedPath = 'assets/recipe_images/$market/$exampleId.webp';
        final path = File(expectedPath);
        print('   $market/$exampleId: ${path.existsSync() ? "✅" : "❌"} ($expectedPath)');
      }
    }
    
    print('\n✅ Validation abgeschlossen');
  } catch (e) {
    print('❌ Fehler: $e');
    exit(1);
  }
}

