#!/usr/bin/env dart
/// Grocify Recipe Generator CLI
/// 
/// Generates AI-powered recipes for all supermarkets based on weekly offer JSON files.
/// 
/// Usage:
///   dart run tools/generate_recipes_for_all_supermarkets.dart
/// 
/// Requirements:
///   - .env file with OPENAI_API_KEY in project root
///   - Offer JSON files in assets/data/ matching pattern: angebote_<supermarket>_<date>.json
/// 
/// Output:
///   - Recipe JSON files in assets/recipes/recipes_<supermarket>.json

import 'dart:io';
import 'dart:convert';
import '../lib/tools/offer_json_loader.dart';
import '../lib/tools/ai_recipe_service.dart';
import '../lib/data/models/offer.dart';

Future<void> main(List<String> args) async {
  print('[Grocify] Starting recipe generation for all supermarkets...');
  print('=' * 60);
  print('');

  try {
    // 1. Load environment variables
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
    
    print('[Grocify] ✅ Environment loaded');
    print('');

    // 2. Determine paths
    final projectRoot = Directory.current.path;
    // Try server/media/prospekte/ first, then assets/data/
    final serverOffersDir = '$projectRoot/server/media/prospekte';
    final assetsOffersDir = '$projectRoot/assets/data';
    final recipesDir = '$projectRoot/assets/recipes';

    // Check which directory exists
    final serverDir = Directory(serverOffersDir);
    
    final offersDir = await serverDir.exists() ? serverOffersDir : assetsOffersDir;

    // Ensure recipes directory exists
    final recipesDirectory = Directory(recipesDir);
    if (!await recipesDirectory.exists()) {
      await recipesDirectory.create(recursive: true);
      print('[Grocify] 📁 Created directory: $recipesDir');
    }

    print('[Grocify] 📂 Offers directory: $offersDir');
    print('[Grocify] 📂 Recipes directory: $recipesDir');
    print('');

    // 3. Load offer files
    print('[Grocify] 📥 Scanning for offer JSON files...');
    final Map<String, List<Offer>> offersBySupermarket;
    if (await serverDir.exists()) {
      print('[Grocify]    Reading from server/media/prospekte/ (scanning all subdirectories)');
      print('');
      offersBySupermarket = await OfferJsonLoader.loadOffersFromDirectory(offersDir);
    } else {
      print('[Grocify]    Reading from assets/data/ (matching: angebote_<supermarket>_<date>.json)');
      print('');
      offersBySupermarket = await OfferJsonLoader.loadOffersFromAssetsData(offersDir);
    }

    if (offersBySupermarket.isEmpty) {
      print('');
      print('[Grocify] ❌ No offer files found in $offersDir');
      print('');
      print('[Grocify] Please ensure you have offer JSON files in assets/data/ with the format:');
      print('[Grocify]   angebote_<supermarket>_<date>.json');
      print('');
      print('[Grocify] Examples:');
      print('[Grocify]   assets/data/angebote_lidl_2025-W49.json');
      print('[Grocify]   assets/data/angebote_rewe_20250101.json');
      print('[Grocify]   assets/data/angebote_edeka_2025-W49.json');
      print('');
      print('[Grocify] Supported date formats:');
      print('[Grocify]   - YYYYMMDD (e.g., 20250101)');
      print('[Grocify]   - YYYY-Www (e.g., 2025-W49)');
      print('');
      exit(1);
    }

    print('');
    print('[Grocify] 📊 Found offers for ${offersBySupermarket.length} supermarket(s):');
    for (final entry in offersBySupermarket.entries) {
      print('[Grocify]    ${entry.key}: ${entry.value.length} offers');
    }
    print('');

    // 4. Initialize AI service
    final aiService = AIRecipeService(apiKey: apiKey);

    // 5. Generate recipes for each supermarket
    int totalRecipesGenerated = 0;
    int successfulSupermarkets = 0;
    int failedSupermarkets = 0;

    for (final entry in offersBySupermarket.entries) {
      final supermarket = entry.key;
      final offers = entry.value;

      if (offers.isEmpty) {
        print('[Grocify] ⚠️  Skipping $supermarket (no offers found)');
        failedSupermarkets++;
        continue;
      }

      print('[Grocify] 🤖 Generating recipes for $supermarket...');
      print('[Grocify]    Offers available: ${offers.length}');
      print('[Grocify]    Target: 30-50 unique recipes');
      print('[Grocify]    Using 75-100% of available offers');
      print('');

      try {
        final recipes = await aiService.generateRecipes(
          supermarket: supermarket,
          offers: offers,
          minRecipes: 30,
          maxRecipes: 50,
        );

        if (recipes.isEmpty) {
          print('[Grocify] ⚠️  No recipes generated for $supermarket');
          failedSupermarkets++;
          continue;
        }

        // 6. Save recipes to JSON file
        final filename = 'recipes_${supermarket.toLowerCase()}.json';
        final filePath = '$recipesDir/$filename';
        final file = File(filePath);

        // Ensure recipe format is correct (already in correct format from AI service)
        final jsonList = recipes.map((recipe) {
          return {
            'id': recipe['id'] as String,
            'title': recipe['title'] as String,
            'description': recipe['description'] as String,
            'category': recipe['category'] as String,
            'supermarket': recipe['supermarket'] as String,
            'estimated_total_time_minutes': recipe['estimated_total_time_minutes'] as int,
            'portions': recipe['portions'] as int,
            'ingredients': recipe['ingredients'] as List,
            'instructions': recipe['instructions'] as List,
            'nutrition_estimate': recipe['nutrition_estimate'] as Map<String, dynamic>,
            'image_prompt': recipe['image_prompt'] as String,
            'tags': recipe['tags'] as List,
          };
        }).toList();

        final jsonString = const JsonEncoder.withIndent('  ').convert(jsonList);
        await file.writeAsString(jsonString);

        totalRecipesGenerated += recipes.length;
        successfulSupermarkets++;

        print('[Grocify] ✅ Generated ${recipes.length} recipes for $supermarket');
        print('[Grocify] 💾 Saved to $filePath');
        print('');

      } catch (e, stackTrace) {
        print('[Grocify] ❌ Failed to generate recipes for $supermarket: $e');
        if (args.contains('--verbose')) {
          print('[Grocify] Stack trace:');
          print(stackTrace);
        }
        failedSupermarkets++;
        print('');
      }
    }

    // 7. Summary
    print('');
    print('=' * 60);
    print('[Grocify] 📊 Summary:');
    print('[Grocify]    Successful: $successfulSupermarkets supermarket(s)');
    if (failedSupermarkets > 0) {
      print('[Grocify]    Failed: $failedSupermarkets supermarket(s)');
    }
    print('[Grocify]    Total recipes generated: $totalRecipesGenerated');
    print('[Grocify]    Output directory: $recipesDir');
    print('');

    if (totalRecipesGenerated == 0) {
      print('[Grocify] ⚠️  No recipes were generated. Check the logs above for errors.');
      exit(1);
    }

    print('[Grocify] ✅ Recipe generation completed successfully!');
    print('');

  } catch (e, stackTrace) {
    print('');
    print('[Grocify] ❌ Fatal error: $e');
    if (args.contains('--verbose')) {
      print('[Grocify] Stack trace:');
      print(stackTrace);
    }
    exit(1);
  }
}

/// Loads API Key from .env file or environment variables
Future<String?> _loadApiKey() async {
  // 1. Try environment variable
  final envKey = Platform.environment['OPENAI_API_KEY'];
  if (envKey != null && envKey.isNotEmpty) {
    return envKey;
  }

  // 2. Try .env file
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

  // 3. Try .env.local
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

