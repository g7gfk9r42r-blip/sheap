#!/usr/bin/env dart
/// Tool zur Generierung von KI-Rezepten aus Angebots-JSON-Dateien
/// 
/// Verwendung:
///   dart run bin/generate_recipes_from_offers.dart
/// 
/// Voraussetzungen:
///   - .env Datei mit OPENAI_API_KEY
///   - Angebots-JSONs in assets/data/ (Format: angebote_<retailer>_YYYYMMDD.json)
/// 
/// Ausgabe:
///   - Rezepte in assets/recipes/recipes_<supermarket>.json
///   - Format: 20-50 Rezepte pro Supermarkt mit ingredients als Objekte

import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/tools/offer_json_loader.dart';
import '../lib/tools/ai_recipe_service.dart';
import '../lib/tools/recipe_json_writer.dart';

Future<void> main(List<String> args) async {
  print('🍳 Grocify Recipe Generator');
  print('=' * 50);
  print('');

  try {
    // 1. Lade Environment-Variablen
    await _loadEnvironment();
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'OPENAI_API_KEY not found in .env file. '
        'Please create a .env file with: OPENAI_API_KEY=your_key_here',
      );
    }
    print('✅ Environment loaded');

    // 2. Bestimme Pfade
    final projectRoot = Directory.current.path;
    final offersDir = '$projectRoot/assets/data';
    final recipesDir = '$projectRoot/assets/recipes';

    print('📂 Offers directory: $offersDir');
    print('📂 Recipes directory: $recipesDir');
    print('');

    // 3. Lade Angebotsdaten aus assets/data/
    print('📥 Loading offers from JSON files in assets/data/...');
    print('   Looking for files matching: angebote_<retailer>_YYYYMMDD.json');
    print('');
    
    final offersByRetailer = await OfferJsonLoader.loadOffersFromAssetsData(offersDir);
    
    if (offersByRetailer.isEmpty) {
      throw Exception(
        'No offers found in $offersDir\n'
        'Expected files: angebote_rewe_YYYYMMDD.json, angebote_lidl_YYYYMMDD.json, etc.'
      );
    }

    print('');
    print('📊 Loaded offers:');
    for (final entry in offersByRetailer.entries) {
      print('   ${entry.key}: ${entry.value.length} offers');
    }
    print('');

    // 4. Initialisiere AI Service
    final aiService = AIRecipeService(apiKey: apiKey);

    // 5. Generiere Rezepte für jeden Supermarkt (20-50 pro Supermarkt)
    final allRecipes = <Map<String, dynamic>>[];
    
    for (final entry in offersByRetailer.entries) {
      final supermarket = entry.key;
      final offers = entry.value;

      if (offers.isEmpty) {
        print('⚠️  Skipping $supermarket (no offers)');
        continue;
      }

      print('🤖 Generating recipes for $supermarket...');
      print('   Target: 20-50 unique recipes');
      print('');
      
      try {
        final recipes = await aiService.generateRecipes(
          supermarket: supermarket,
          offers: offers,
          minRecipes: 20,
          maxRecipes: 50,
        );
        
        allRecipes.addAll(recipes);
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

    // 6. Speichere Rezepte als JSON
    if (allRecipes.isEmpty) {
      print('⚠️  No recipes generated, nothing to save');
      return;
    }

    print('💾 Saving recipes to JSON files...');
    print('');
    await RecipeJsonWriter.writeRecipes(
      recipes: allRecipes,
      outputDir: recipesDir,
    );

    print('');
    print('✅ Success! Generated ${allRecipes.length} recipes total');
    print('📁 Recipes saved to: $recipesDir');
    print('');
    
    // Zeige Zusammenfassung
    final bySupermarket = <String, int>{};
    for (final recipe in allRecipes) {
      final sm = recipe['supermarket'] as String? ?? 'UNKNOWN';
      bySupermarket[sm] = (bySupermarket[sm] ?? 0) + 1;
    }
    
    print('📊 Summary:');
    for (final entry in bySupermarket.entries) {
      print('   ${entry.key}: ${entry.value} recipes');
    }
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

/// Lädt Environment-Variablen aus .env Datei
Future<void> _loadEnvironment() async {
  final projectRoot = Directory.current.path;
  final envFile = File('$projectRoot/.env');
  
  if (await envFile.exists()) {
    await dotenv.load(fileName: '.env');
  } else {
    // Versuche auch .env.local
    final envLocalFile = File('$projectRoot/.env.local');
    if (await envLocalFile.exists()) {
      await dotenv.load(fileName: '.env.local');
    } else {
      print('⚠️  No .env file found, trying environment variables...');
    }
  }
}
