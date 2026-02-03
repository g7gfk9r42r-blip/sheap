#!/usr/bin/env dart
/// Tool zur Generierung von KI-Rezepten für spezifische Supermärkte
/// 
/// Verwendung:
///   dart run tools/generate_recipes_for_specific_supermarkets.dart
/// 
/// Oder mit spezifischen Supermärkten:
///   dart run tools/generate_recipes_for_specific_supermarkets.dart aldi_nord rewe
/// 
/// Voraussetzungen:
///   - .env Datei mit OPENAI_API_KEY
///   - Angebots-JSONs in server/media/prospekte/ oder assets/data/

import 'dart:io';
import 'dart:convert';
import '../lib/tools/offer_json_loader.dart';
import '../lib/tools/ai_recipe_service.dart';
import '../lib/data/models/offer.dart';

Future<void> main(List<String> args) async {
  print('🍳 Grocify Recipe Generator (Specific Supermarkets)');
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
    
    // Prüfe ob API Key noch der Platzhalter ist
    if (apiKey.contains('your-key') || apiKey.contains('sk-your')) {
      throw Exception(
        '⚠️  Invalid API Key detected!\n'
        'Your .env file still contains the placeholder: "$apiKey"\n'
        'Please replace it with your real OpenAI API key:\n'
        '  1. Get your API key from: https://platform.openai.com/account/api-keys\n'
        '  2. Update .env file: OPENAI_API_KEY=sk-your-real-key-here\n'
        '  3. Run the script again',
      );
    }
    
    print('✅ Environment loaded');

    // 2. Bestimme welche Supermärkte verarbeitet werden sollen
    final targetSupermarkets = args.isNotEmpty 
        ? args.map((s) => s.toUpperCase()).toList()
        : ['ALDI_NORD', 'REWE']; // Default
    
    print('🎯 Target supermarkets: ${targetSupermarkets.join(", ")}');
    print('');

    // 3. Bestimme Pfade
    final projectRoot = Directory.current.path;
    final serverOffersDir = '$projectRoot/server/media/prospekte';
    final assetsOffersDir = '$projectRoot/assets/data';
    final recipesDir = '$projectRoot/assets/recipes';

    final serverDir = Directory(serverOffersDir);
    final offersDir = await serverDir.exists() ? serverOffersDir : assetsOffersDir;
    
    print('📂 Offers directory: $offersDir');
    print('📂 Recipes directory: $recipesDir');
    print('');

    // 4. Lade Angebotsdaten
    print('📥 Loading offers from JSON files...');
    final Map<String, List<Offer>> allOffersByRetailer;
    if (await serverDir.exists()) {
      print('   Reading from server/media/prospekte/ (scanning all subdirectories)');
      print('');
      allOffersByRetailer = await OfferJsonLoader.loadOffersFromDirectory(offersDir);
    } else {
      print('   Reading from assets/data/ (matching: angebote_<retailer>_<date>.json)');
      print('');
      allOffersByRetailer = await OfferJsonLoader.loadOffersFromAssetsData(offersDir);
    }

    // 5. Filtere nur die gewünschten Supermärkte
    final offersByRetailer = <String, List<Offer>>{};
    for (final target in targetSupermarkets) {
      // Suche nach exakter Übereinstimmung oder ähnlichen Namen
      final matchingKey = allOffersByRetailer.keys.firstWhere(
        (key) => key.toUpperCase() == target.toUpperCase() || 
                 key.toUpperCase().replaceAll('_', ' ') == target.toUpperCase().replaceAll('_', ' '),
        orElse: () => target,
      );
      
      if (allOffersByRetailer.containsKey(matchingKey)) {
        offersByRetailer[matchingKey] = allOffersByRetailer[matchingKey]!;
        print('✅ Found ${allOffersByRetailer[matchingKey]!.length} offers for $matchingKey');
      } else {
        print('⚠️  No offers found for $target (searched for: $matchingKey)');
        print('   Available supermarkets: ${allOffersByRetailer.keys.join(", ")}');
      }
    }
    
    if (offersByRetailer.isEmpty) {
      print('');
      print('❌ No offers found for any of the target supermarkets');
      print('   Requested: ${targetSupermarkets.join(", ")}');
      print('   Available: ${allOffersByRetailer.keys.join(", ")}');
      print('');
      exit(1);
    }

    print('');
    print('📊 Loaded offers:');
    for (final entry in offersByRetailer.entries) {
      print('   ${entry.key}: ${entry.value.length} offers');
    }
    print('');

    // 6. Initialisiere AI Service
    final aiService = AIRecipeService(apiKey: apiKey);

    // 7. Generiere Rezepte für jeden Supermarkt (30-50 pro Supermarkt)
    final allRecipes = <Map<String, dynamic>>[];
    
    for (final entry in offersByRetailer.entries) {
      final supermarket = entry.key;
      final offers = entry.value;

      if (offers.isEmpty) {
        print('⚠️  Skipping $supermarket (no offers)');
        continue;
      }

      print('🤖 Generating recipes for $supermarket...');
      print('   Target: 30-50 unique recipes');
      print('   Offers available: ${offers.length}');
      print('   Using 75-100% of available offers');
      print('');
      
      try {
        final recipes = await aiService.generateRecipes(
          supermarket: supermarket,
          offers: offers,
          minRecipes: 30,
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

    // 8. Speichere Rezepte als JSON
    if (allRecipes.isEmpty) {
      print('⚠️  No recipes generated, nothing to save');
      return;
    }

    print('💾 Saving recipes to JSON files...');
    print('');
    
    // Gruppiere nach Supermarket und speichere
    final recipesBySupermarket = <String, List<Map<String, dynamic>>>{};
    for (final recipe in allRecipes) {
      final supermarket = recipe['supermarket'] as String? ?? 'UNKNOWN';
      recipesBySupermarket.putIfAbsent(supermarket, () => []).add(recipe);
    }

    // Erstelle Ausgabeverzeichnis falls nicht vorhanden
    final recipesDirectory = Directory(recipesDir);
    if (!await recipesDirectory.exists()) {
      await recipesDirectory.create(recursive: true);
      print('📁 Created directory: $recipesDir');
    }

    // Schreibe für jeden Supermarket eine Datei
    for (final entry in recipesBySupermarket.entries) {
      final supermarket = entry.key;
      final supermarketRecipes = entry.value;
      
      final filename = 'recipes_${supermarket.toLowerCase()}.json';
      final filePath = '$recipesDir/$filename';
      final file = File(filePath);

      // Konvertiere zu JSON (bereits im korrekten Format)
      final jsonList = supermarketRecipes.map((recipe) {
        return {
          'id': recipe['id'] as String? ?? '${supermarket.toLowerCase()}-${supermarketRecipes.indexOf(recipe) + 1}',
          'title': recipe['title'] as String,
          'description': recipe['description'] as String? ?? 'Ein leckeres Rezept aus aktuellen Angeboten.',
          'category': recipe['category'] as String? ?? 'balanced',
          'supermarket': recipe['supermarket'] as String,
          'estimated_total_time_minutes': recipe['estimated_total_time_minutes'] as int? ?? 30,
          'portions': recipe['portions'] as int? ?? 2,
          'ingredients': recipe['ingredients'] as List,
          'instructions': recipe['instructions'] as List? ?? ['Anleitung folgt...'],
          'nutrition_estimate': recipe['nutrition_estimate'] as Map<String, dynamic>? ??
              {
                'kcal_per_portion': 500,
                'protein_g': 25,
                'carbs_g': 50,
                'fat_g': 15,
              },
          'image_prompt': recipe['image_prompt'] as String? ??
              'Realistische Food-Fotografie dieses Gerichts',
          'tags': recipe['tags'] as List,
        };
      }).toList();
      
      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
      await file.writeAsString(jsonString);
      
      print('✅ Wrote ${supermarketRecipes.length} recipes to $filePath');
    }

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

