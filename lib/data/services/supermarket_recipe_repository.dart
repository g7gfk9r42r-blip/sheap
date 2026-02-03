/// Supermarket Recipe Repository
/// Lädt Rezepte aus allen Supermärkten im /server/media/prospekte/ Verzeichnis
/// Unterstützt sowohl Web (HTTP) als auch Mobile (HTTP)
/// Caching: Rezepte werden einmal pro Woche gespeichert
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import '../../utils/week.dart';
import '../../core/config/app_privacy_config.dart';

class SupermarketRecipeRepository {
  // Bump this when cached recipe JSON schema/normalization changes.
  // This forces a fresh fetch instead of reusing older cached objects with missing `market` etc.
  static const String _cachePrefix = 'supermarket_recipes_cache_v3_';
  static const String _cacheWeekKey = 'supermarket_recipes_cache_week_v3';
  static bool _serverOffline = false;
  static bool _offlineHintPrinted = false;

  /// Liste aller Supermärkte (Ordner-Namen)
  static const List<String> supermarkets = [
    'kaufland',
    'lidl',
    'rewe',
    'aldi_nord',
    'aldi_sued',
    'netto',
    'penny',
    'norma',
    'nahkauf',
    'tegut',
    'biomarkt',
  ];

  /// Mapping von Ordner-Namen zu möglichen Dateinamen
  static const Map<String, List<String>> _supermarketToFiles = {
    // Prefer the unified weekly pipeline output: <market>_recipes.json
    // Keep legacy fallbacks for older files.
    'kaufland': ['kaufland_recipes.json', 'kauflan_recipes.json'],
    'lidl': ['lidl_recipes.json', 'recipes_lidl.json', 'lidl.json'],
    'rewe': ['rewe_recipes.json'],
    'aldi_nord': ['aldi_nord_recipes.json', '_recipes.json'],
    'aldi_sued': ['aldi_sued_recipes.json', '_recipes.json', 'aldi_sued.json'],
    'netto': ['netto_recipes.json'],
    'penny': ['penny_recipes.json', 'edeka_recipes.json'],
    'norma': ['norma_recipes.json', 'norma.json'],
    'nahkauf': ['nahkauf_recipes.json', '_recipes.json'],
    'tegut': ['tegut_recipes.json'],
    'biomarkt': ['biomarkt_recipes.json', 'biomarkt_new.json'],
  };

  /// Basis-Pfad für Rezepte (kann über Umgebungsvariable konfiguriert werden)
  static String get basePath {
    final envBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();
    // Dev UX: default to localhost when NOT in release (saves you from always passing dart-define).
    // Release safety: never default to localhost.
    final apiBaseUrl = envBase.isNotEmpty ? envBase : (kReleaseMode ? '' : 'http://localhost:3000');

    // If API_BASE_URL is not provided, do NOT fall back to a relative "/media/..." URL,
    // because on Flutter Web it would hit the Flutter dev server and return HTML (index.html).
    if (apiBaseUrl.trim().isEmpty) {
      _serverOffline = true;
      if (!_offlineHintPrinted) {
        _offlineHintPrinted = true;
        debugPrint('⚠️ API_BASE_URL is not set. Remote recipes/images are disabled.');
        debugPrint('   Tip (dev): start `python3 server/dev_media_server.py` and run:');
        debugPrint('   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000');
      }
      return '';
    }
    // Safety: never default to localhost in release builds (closed test users won't have it).
    if (kReleaseMode && (apiBaseUrl.isEmpty || apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1'))) {
      _serverOffline = true;
      if (!_offlineHintPrinted) {
        _offlineHintPrinted = true;
        debugPrint('⚠️ API_BASE_URL is not set for release. Remote recipes/images are disabled.');
        debugPrint('   Build fix: pass --dart-define=API_BASE_URL=https://<your-public-server>');
      }
      return '';
    }
    return '$apiBaseUrl/media/prospekte';
  }

  /// Lädt alle Rezepte von allen Supermärkten
  /// Gibt ein Map zurück: { "kaufland": [Recipe...], "lidl": [Recipe...], ... }
  /// Verwendet Caching: Rezepte werden einmal pro Woche geladen und gespeichert
  static Future<Map<String, List<Recipe>>> loadAllSupermarketRecipes({
    bool forceRefresh = false,
    String? weekKeyOverride,
  }) async {
    // Pro-level weekly sync:
    // Prefer server week_key (if known) over device week (timezone-safe).
    String currentWeekKey = weekKeyOverride ?? isoWeekKey(DateTime.now());
    if (weekKeyOverride == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final serverWeek = (prefs.getString('remote_meta_week_key') ?? '').trim();
        if (serverWeek.isNotEmpty) currentWeekKey = serverWeek;
      } catch (_) {}
    }

    // Prüfe Cache
    if (!forceRefresh && AppPrivacyConfig.persistRecipeCacheLocal) {
      final cachedData = await _loadFromCache(currentWeekKey);
      if (cachedData != null && cachedData.isNotEmpty) {
        return cachedData;
      }
    }

    // Lade frische Daten
    final result = <String, List<Recipe>>{};

    for (final supermarket in supermarkets) {
      try {
        final recipes = await loadSupermarketRecipes(supermarket);
        if (recipes.isNotEmpty) {
          result[supermarket] = recipes;
        }
      } catch (e) {
        debugPrint('⚠️ Fehler beim Laden von $supermarket: $e');
        // Weiter mit nächstem Supermarkt
        continue;
      }
    }

    // Speichere im Cache
    if (result.isNotEmpty && AppPrivacyConfig.persistRecipeCacheLocal) {
      await _saveToCache(result, currentWeekKey);
    }

    return result;
  }

  /// Lädt Rezepte für einen spezifischen Supermarkt
  static Future<List<Recipe>> loadSupermarketRecipes(String supermarket) async {
    // If the media server is offline, do not spam retries per market.
    if (_serverOffline) return [];
    final fileNames = _supermarketToFiles[supermarket.toLowerCase()] ?? [];

    for (final fileName in fileNames) {
      try {
        final recipes = await _loadRecipeFile(supermarket, fileName);
        if (recipes.isNotEmpty) {
          return recipes;
        }
      } catch (e) {
        if (!_serverOffline) {
          debugPrint(
            '⚠️ Datei $fileName für $supermarket nicht gefunden, versuche nächste...',
          );
        }
        continue;
      }
    }

    if (!_serverOffline) {
      debugPrint('⚠️ Keine Rezepte-Datei für $supermarket gefunden');
    }
    return [];
  }

  /// Lädt eine spezifische Rezepte-Datei
  static Future<List<Recipe>> _loadRecipeFile(
    String supermarket,
    String fileName,
  ) async {
    try {
      if (_serverOffline) return [];
      // Versuche HTTP-Request (für Web/Development)
      final url = '$basePath/$supermarket/$fileName';

      if (kIsWeb) {
        // Für Web: HTTP Request
        final response = await _fetchHttp(url);
        if (response != null) {
          return _parseRecipeJson(response, supermarket);
        }
      } else {
        // Für Mobile: Versuche HTTP (falls Server läuft)
        try {
          final response = await _fetchHttp(url);
          if (response != null) {
            return _parseRecipeJson(response, supermarket);
          }
        } catch (e) {
          debugPrint(
            '⚠️ HTTP Request fehlgeschlagen für $url, versuche Assets...',
          );
        }
      }

      return [];
    } catch (e) {
      debugPrint('⚠️ Fehler beim Laden von $fileName für $supermarket: $e');
      return [];
    }
  }

  /// HTTP Request (für Web und Mobile mit Server)
  static Future<String?> _fetchHttp(String url) async {
    // If we already detected the dev media server as offline, skip spammy retries.
    if (_serverOffline) return null;
    if (url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return response.body;
      } else {
        debugPrint(
          '⚠️ HTTP Request fehlgeschlagen: Status ${response.statusCode} für $url',
        );
        return null;
      }
    } catch (e) {
      // Typical for Web when localhost:3000 is not running / blocked by browser.
      _serverOffline = true;
      if (!_offlineHintPrinted) {
        _offlineHintPrinted = true;
        debugPrint('⚠️ Media server unreachable (API_BASE_URL=${const String.fromEnvironment('API_BASE_URL', defaultValue: '')}).');
        debugPrint('   Tip (dev): start `python3 server/dev_media_server.py` or set --dart-define=API_BASE_URL=... to your server.');
      }
      return null;
    }
  }

  /// Parst JSON-String zu Recipe-Liste
  static List<Recipe> _parseRecipeJson(String jsonString, String supermarket) {
    try {
      final jsonData = json.decode(jsonString);

      // Handle Array of recipes
      if (jsonData is List) {
        final recipes = <Recipe>[];
        for (final item in jsonData) {
          if (item is Map<String, dynamic>) {
            try {
              final recipe = _parseRecipeJsonObject(item, supermarket);
              if (recipe != null) {
                recipes.add(recipe);
              }
            } catch (e) {
              debugPrint('⚠️ Fehler beim Parsen eines Rezepts: $e');
              continue;
            }
          }
        }
        return recipes;
      }

      // Handle Object with 'recipes' key
      if (jsonData is Map<String, dynamic>) {
        if (jsonData.containsKey('recipes') && jsonData['recipes'] is List) {
          final recipesList = jsonData['recipes'] as List;
          final recipes = <Recipe>[];
          for (final item in recipesList) {
            if (item is Map<String, dynamic>) {
              try {
                final recipe = _parseRecipeJsonObject(item, supermarket);
                if (recipe != null) {
                  recipes.add(recipe);
                }
              } catch (e) {
                debugPrint('⚠️ Fehler beim Parsen eines Rezepts: $e');
                continue;
              }
            }
          }
          return recipes;
        }
      }

      return [];
    } catch (e) {
      debugPrint('⚠️ Fehler beim Parsen von JSON für $supermarket: $e');
      return [];
    }
  }

  /// Parst ein einzelnes Rezept-Objekt
  static Recipe? _parseRecipeJsonObject(
    Map<String, dynamic> json,
    String supermarket,
  ) {
    try {
      // Stelle sicher, dass retailer gesetzt ist
      final recipeJson = Map<String, dynamic>.from(json);
      // IMPORTANT: always set canonical market key from the folder name (used for UI grouping)
      recipeJson['market'] = supermarket.toLowerCase().trim();
      if (!recipeJson.containsKey('retailer')) {
        recipeJson['retailer'] = supermarket.toUpperCase();
      }

      // Validiere Rezept
      final validationErrors = _validateRecipe(recipeJson);
      if (validationErrors.isNotEmpty) {
        debugPrint(
          '⚠️ Validierungsfehler für Rezept ${recipeJson['id']}: ${validationErrors.join(", ")}',
        );
        // Füge Warnung hinzu, aber erstelle Rezept trotzdem
        if (recipeJson['warnings'] == null) {
          recipeJson['warnings'] = [];
        }
        if (recipeJson['warnings'] is List) {
          (recipeJson['warnings'] as List).addAll(validationErrors);
        }
      }

      // Erweitere JSON um image/image_spec Schema (wenn nicht bereits vorhanden)
      if (!recipeJson.containsKey('image')) {
        recipeJson['image'] = buildImageSchema(recipeJson, supermarket);
      }
      if (!recipeJson.containsKey('image_spec')) {
        recipeJson['image_spec'] = buildImageSpec(recipeJson);
      }

      return Recipe.fromJson(recipeJson);
    } catch (e) {
      debugPrint('⚠️ Fehler beim Erstellen von Recipe: $e');
      return null;
    }
  }

  /// Baut image-Schema basierend auf retailer_slug, Stock-Markierung und Asset-Existenz
  /// PUBLIC: Wird auch von RecipeRepository verwendet
  ///
  /// Logik:
  /// - Rezepte mit 'stock': true → source: 'shutterstock', shutterstock_url
  /// - Rezepte ohne 'stock' (oder false) → source: 'ai_generated' oder 'asset', asset_path
  ///
  /// WICHTIG: Kein weekKey mehr im Asset-Pfad!
  static Map<String, dynamic> buildImageSchema(
    Map<String, dynamic> json,
    String supermarket,
  ) {
    // FIX: Verwende IMMER supermarket-Parameter (market aus Ordnername) statt retailer aus JSON
    // supermarket ist der korrekte Market-Key (z.B. "aldi_nord", "biomarkt")
    // retailer aus JSON kann falsch sein (z.B. "BIOMARKT" obwohl market="aldi_nord")
    final marketToUse =
        supermarket; // Verwende market-Parameter (aus Ordnername)

    // Normalisiere market zu slug: "ALDI NORD" -> "aldi_nord", "ALDI SÜD" -> "aldi_sued", etc.
    final marketSlug = normalizeRetailerToSlug(marketToUse);

    final recipeId = json['id']?.toString() ?? '';

    // Prüfe ob Rezept als "Stock" markiert ist
    final isStock = json['stock'] == true;

    // Stock-Rezepte → Shutterstock
    if (isStock) {
      // Shutterstock-URL wird dynamisch generiert oder aus JSON geladen
      final shutterstockUrl =
          json['shutterstock_url']?.toString() ?? json['image_url']?.toString();

      if (shutterstockUrl != null && shutterstockUrl.isNotEmpty) {
        return {
          'source': 'shutterstock',
          'shutterstock_url': shutterstockUrl,
          'status': 'ready',
        };
      } else {
        // URL fehlt, aber Rezept ist als Stock markiert
        return {
          'source': 'shutterstock',
          'shutterstock_url': null,
          'status': 'missing', // URL muss noch geladen werden
        };
      }
    }

    // Nicht-Stock-Rezepte → Asset (OHNE weekKey im Pfad!)
    // FIX: Pfad wird später überschrieben mit korrektem heroImageUrl
    // Temporärer Pfad (wird in recipe_loader_from_prospekte.dart überschrieben)
    // Our pipeline currently generates PNGs under server/media/recipe_images/<market>/R###.png
    // Keep defaults aligned (webp is optional).
    final assetPath = 'assets/recipe_images/$marketSlug/$recipeId.png';

    return {
      'source': 'asset', // Asset aus App-Bundle
      'asset_path': assetPath,
      'status': 'ready', // AssetIndexService prüft zur Laufzeit
    };
  }

  /// Normalisiert Retailer-Namen zu Slug-Format
  /// "ALDI NORD" -> "aldi_nord", "ALDI SÜD" -> "aldi_sued", "ALDI_NORD" -> "aldi_nord"
  /// PUBLIC: Wird auch von RecipeRepository verwendet
  static String normalizeRetailerToSlug(String retailer) {
    if (retailer.isEmpty) return '';

    // Konvertiere zu lowercase und ersetze Leerzeichen/Unterstriche
    String normalized = retailer.toLowerCase().trim();

    // Spezielle Mappings für bekannte Retailer
    final retailerMappings = {
      'aldi nord': 'aldi_nord',
      'aldi nörd': 'aldi_nord',
      'aldi n': 'aldi_nord',
      'aldi süd': 'aldi_sued',
      'aldi sued': 'aldi_sued',
      'aldi s': 'aldi_sued',
      'biomarkt': 'biomarkt',
      'bio markt': 'biomarkt',
    };

    // Prüfe exakte Mappings
    if (retailerMappings.containsKey(normalized)) {
      return retailerMappings[normalized]!;
    }

    // Fallback: Ersetze Leerzeichen mit Unterstrichen
    normalized = normalized.replaceAll(RegExp(r'\s+'), '_');

    return normalized;
  }

  /// Baut image_spec Schema (nur Markierung, kein Download)
  /// PUBLIC: Wird auch von RecipeRepository verwendet
  static Map<String, dynamic> buildImageSpec(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    return {
      'source': 'stock_candidate',
      'query': title, // Kann später für Stock-Image-Suche verwendet werden
    };
  }

  /// Validiert ein Rezept-Objekt
  /// Prüft insbesondere, ob Angebots-Zutaten vollständig sind
  static List<String> _validateRecipe(Map<String, dynamic> json) {
    final errors = <String>[];

    // Prüfe ingredients
    if (json['ingredients'] is List) {
      final ingredients = json['ingredients'] as List;
      for (int i = 0; i < ingredients.length; i++) {
        final ing = ingredients[i];
        if (ing is Map<String, dynamic>) {
          final fromOffer =
              ing['from_offer'] == true || ing['fromOffer'] == true;
          if (fromOffer) {
            // Für Angebots-Zutaten müssen offer_id, price_eur und brand/product vorhanden sein
            final offerId =
                ing['offer_id']?.toString() ?? ing['offerId']?.toString();
            final priceEur = ing['price_eur'] ?? ing['priceEur'];
            final brand = ing['brand']?.toString();
            final product = ing['product']?.toString();

            if (offerId == null || offerId.isEmpty) {
              errors.add('Ingredient $i: from_offer=true aber offer_id fehlt');
            }
            if (priceEur == null) {
              errors.add('Ingredient $i: from_offer=true aber price_eur fehlt');
            }
            if ((brand == null || brand.isEmpty) &&
                (product == null || product.isEmpty)) {
              errors.add(
                'Ingredient $i: from_offer=true aber brand/product fehlt',
              );
            }
          }
        }
      }
    }

    return errors;
  }

  /// Lädt Rezepte aus dem Cache (falls für aktuelle Woche vorhanden)
  static Future<Map<String, List<Recipe>>?> _loadFromCache(
    String weekKey,
  ) async {
    if (!AppPrivacyConfig.persistRecipeCacheLocal) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedWeekKey = prefs.getString(_cacheWeekKey);

      // Prüfe ob Cache für aktuelle Woche vorhanden ist
      if (cachedWeekKey != weekKey) {
        return null;
      }

      // Lade alle Supermärkte aus Cache
      final cachedData = <String, List<Recipe>>{};
      for (final supermarket in supermarkets) {
        final cacheKey = '$_cachePrefix$supermarket';
        final jsonString = prefs.getString(cacheKey);
        if (jsonString != null) {
          try {
            final jsonData = json.decode(jsonString);
            if (jsonData is List) {
              final recipes = jsonData
                  .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
                  .whereType<Recipe>()
                  .toList();
              if (recipes.isNotEmpty) {
                cachedData[supermarket] = recipes;
              }
            }
          } catch (e) {
            debugPrint('⚠️ Fehler beim Laden von Cache für $supermarket: $e');
            continue;
          }
        }
      }

      return cachedData.isNotEmpty ? cachedData : null;
    } catch (e) {
      debugPrint('⚠️ Fehler beim Laden aus Cache: $e');
      return null;
    }
  }

  /// Speichert Rezepte im Cache (für aktuelle Woche)
  static Future<void> _saveToCache(
    Map<String, List<Recipe>> recipesBySupermarket,
    String weekKey,
  ) async {
    if (!AppPrivacyConfig.persistRecipeCacheLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Speichere weekKey
      await prefs.setString(_cacheWeekKey, weekKey);

      // Speichere jede Supermarkt-Liste
      for (final entry in recipesBySupermarket.entries) {
        final supermarket = entry.key;
        final recipes = entry.value;
        final cacheKey = '$_cachePrefix$supermarket';

        // Konvertiere zu JSON
        final jsonList = recipes.map((recipe) => recipe.toJson()).toList();
        final jsonString = json.encode(jsonList);

        await prefs.setString(cacheKey, jsonString);
      }
    } catch (e) {
      debugPrint('⚠️ Fehler beim Speichern in Cache: $e');
    }
  }

  /// Löscht den gesamten Cache
  static Future<void> clearCache() async {
    if (!AppPrivacyConfig.persistRecipeCacheLocal) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Lösche weekKey
      await prefs.remove(_cacheWeekKey);

      // Lösche alle Supermarkt-Caches
      for (final supermarket in supermarkets) {
        final cacheKey = '$_cachePrefix$supermarket';
        await prefs.remove(cacheKey);
      }
    } catch (e) {
      debugPrint('⚠️ Fehler beim Löschen des Caches: $e');
    }
  }
}
