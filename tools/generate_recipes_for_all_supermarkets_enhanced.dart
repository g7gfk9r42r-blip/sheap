#!/usr/bin/env dart
/// Enhanced Recipe Generator für alle Supermärkte
/// 
/// Dieses Tool:
/// 1. Lädt alle Angebots-JSONs aus assets/data/
/// 2. Filtert Nicht-Lebensmittel heraus
/// 3. Generiert Rezepte mit OpenAI
/// 4. Speichert Rezepte in assets/recipes/
/// 5. Erstellt file_index.json
/// 
/// Verwendung:
///   dart run tools/generate_recipes_for_all_supermarkets_enhanced.dart
/// 
/// Voraussetzungen:
///   - .env Datei mit OPENAI_API_KEY
///   - Angebots-JSONs in assets/data/ (Format: angebote_<retailer>_YYYY-WW.json)

import 'dart:io';
import 'dart:convert';
import '../lib/tools/offer_json_loader.dart';
import '../lib/tools/offer_filter.dart';
import '../lib/tools/ai_recipe_service.dart';
import '../lib/data/models/offer.dart';
import '../lib/utils/week.dart';

Future<void> main(List<String> args) async {
  print('🍳 Grocify Enhanced Recipe Generator');
  print('=' * 60);
  print('');

  try {
    // 1. Lade Environment-Variablen
    final apiKey = await _loadApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'OPENAI_API_KEY not found.\n'
        'Please either:\n'
        '  - Create a .env file in project root with: OPENAI_API_KEY=your_key_here\n'
        '  - Or set environment variable: export OPENAI_API_KEY=your_key_here',
      );
    }
    
    if (apiKey.contains('your-key') || apiKey.contains('sk-your')) {
      throw Exception(
        '⚠️  Invalid API Key detected!\n'
        'Your .env file still contains the placeholder: "$apiKey"\n'
        'Please replace it with your real OpenAI API key.',
      );
    }
    
    print('✅ Environment loaded');
    print('');

    // 2. Bestimme Pfade
    final projectRoot = Directory.current.path;
    final assetsOffersDir = '$projectRoot/assets/data';
    final recipesDir = '$projectRoot/assets/recipes';

    print('📂 Offers directory: $assetsOffersDir');
    print('📂 Recipes directory: $recipesDir');
    print('');

    // 3. Lade Angebotsdaten
    print('📥 Loading offers from JSON files...');
    final offersByRetailer = await OfferJsonLoader.loadOffersFromAssetsData(assetsOffersDir);
    
    if (offersByRetailer.isEmpty) {
      print('');
      print('❌ No offers found in $assetsOffersDir');
      print('');
      print('Please ensure you have offer JSON files with the format:');
      print('  angebote_<supermarket>_<date>.json');
      print('');
      exit(1);
    }

    print('');
    print('📊 Loaded offers (before filtering):');
    for (final entry in offersByRetailer.entries) {
      print('   ${entry.key}: ${entry.value.length} offers');
    }
    print('');

    // 4. Filtere Nicht-Lebensmittel
    print('🔍 Filtering food offers (removing non-food items)...');
    final filteredOffersByRetailer = <String, List<Offer>>{};
    for (final entry in offersByRetailer.entries) {
      final filtered = OfferFilter.filterFoodOffers(entry.value);
      filteredOffersByRetailer[entry.key] = filtered;
      final removed = entry.value.length - filtered.length;
      if (removed > 0) {
        print('   ${entry.key}: ${entry.value.length} → ${filtered.length} (removed $removed non-food items)');
      } else {
        print('   ${entry.key}: ${filtered.length} offers (all food items)');
      }
    }
    print('');

    // 5. Initialisiere AI Service
    final aiService = AIRecipeService(apiKey: apiKey);

    // 6. Generiere Rezepte für jeden Supermarkt
    final allRecipesBySupermarket = <String, List<Map<String, dynamic>>>{};
    final currentWeekKey = isoWeekKey(DateTime.now());
    
    for (final entry in filteredOffersByRetailer.entries) {
      final supermarket = entry.key;
      final offers = entry.value;

      if (offers.isEmpty) {
        print('⚠️  Skipping $supermarket (no food offers after filtering)');
        continue;
      }

      print('🤖 Generating recipes for $supermarket...');
      print('   Target: 30-50 unique recipes');
      print('   Food offers available: ${offers.length}');
      print('');
      
      try {
        final recipes = await aiService.generateRecipes(
          supermarket: supermarket,
          offers: offers,
          minRecipes: 30,
          maxRecipes: 50,
        );
        
        allRecipesBySupermarket[supermarket] = recipes;
        print('');
        print('   ✅ Generated ${recipes.length} recipes for $supermarket');
        print('');
      } catch (e, stackTrace) {
        print('');
        print('   ❌ Failed to generate recipes for $supermarket: $e');
        if (args.contains('--verbose')) {
          print('   Stack trace: $stackTrace');
        }
        print('');
      }
    }

    // 7. Speichere Rezepte als JSON
    if (allRecipesBySupermarket.isEmpty) {
      print('⚠️  No recipes generated, nothing to save');
      return;
    }

    print('💾 Saving recipes to JSON files...');
    print('');
    
    // Erstelle Ausgabeverzeichnis falls nicht vorhanden
    final recipesDirectory = Directory(recipesDir);
    if (!await recipesDirectory.exists()) {
      await recipesDirectory.create(recursive: true);
      print('📁 Created directory: $recipesDir');
    }

    final marketIndex = <Map<String, dynamic>>[];

    // Schreibe für jeden Supermarket eine Datei
    for (final entry in allRecipesBySupermarket.entries) {
      final supermarket = entry.key;
      final supermarketRecipes = entry.value;
      
      final filename = 'recipes_${supermarket.toLowerCase().replaceAll(' ', '_')}.json';
      final filePath = '$recipesDir/$filename';
      final file = File(filePath);

      // Konvertiere zu JSON (bereits im korrekten Format von AIRecipeService)
      final jsonString = const JsonEncoder.withIndent('  ').convert(supermarketRecipes);
      await file.writeAsString(jsonString);
      
      print('✅ Wrote ${supermarketRecipes.length} recipes to $filename');
      
      // Füge zum Index hinzu
      marketIndex.add({
        'name': supermarket,
        'file': 'assets/recipes/$filename',
        'recipeCount': supermarketRecipes.length,
      });
    }

    // 8. Erstelle file_index.json
    final indexData = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'weekKey': currentWeekKey,
      'markets': marketIndex,
    };
    
    final indexFile = File('$recipesDir/file_index.json');
    await indexFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(indexData),
    );
    
    print('');
    print('✅ Created file_index.json');
    print('');

    // 9. Zusammenfassung
    final totalRecipes = allRecipesBySupermarket.values
        .fold(0, (sum, recipes) => sum + recipes.length);
    
    print('✅ Success! Generated $totalRecipes recipes total');
    print('📁 Recipes saved to: $recipesDir');
    print('');
    
    print('📊 Summary:');
    for (final entry in allRecipesBySupermarket.entries) {
      print('   ${entry.key}: ${entry.value.length} recipes');
    }
    print('');
    print('📄 Index file: assets/recipes/file_index.json');
    print('');
  } catch (e, stackTrace) {
    print('');
    print('❌ Error: $e');
    if (args.contains('--verbose')) {
      print('Stack trace:');
      print(stackTrace);
    }
    exit(1);
  }
}

/// Lädt API Key aus .env Datei oder Environment-Variablen
Future<String?> _loadApiKey() async {
  // 1. Versuche Environment-Variable
  final envKey = Platform.environment['OPENAI_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) {
    return envKey;
  }

  // 2. Versuche .env Datei
  final projectRoot = Directory.current.path;
  final envFile = File('$projectRoot/.env');
  
  if (await envFile.exists()) {
    final content = await envFile.readAsString();
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('OPENAI_API_KEY=')) {
        return trimmed.substring('OPENAI_API_KEY='.length).trim();
      }
    }
  }

  // 3. Versuche .env.local
  final envLocalFile = File('$projectRoot/.env.local');
  if (await envLocalFile.exists()) {
    final content = await envLocalFile.readAsString();
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('OPENAI_API_KEY=')) {
        return trimmed.substring('OPENAI_API_KEY='.length).trim();
      }
    }
  }

  return null;
}

