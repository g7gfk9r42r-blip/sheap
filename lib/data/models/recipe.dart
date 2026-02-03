import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../utils/json_helpers.dart';
import 'recipe_offer.dart';
import 'extra_ingredient.dart';

/// Nutrition Range: Min-Max Werte für Nährwerte
class RecipeNutritionRange {
  final int? caloriesMin;
  final int? caloriesMax;
  final double? proteinMin; // in Gramm
  final double? proteinMax;
  final double? carbsMin;
  final double? carbsMax;
  final double? fatMin;
  final double? fatMax;

  const RecipeNutritionRange({
    this.caloriesMin,
    this.caloriesMax,
    this.proteinMin,
    this.proteinMax,
    this.carbsMin,
    this.carbsMax,
    this.fatMin,
    this.fatMax,
  });

  /// Formatiert Kalorien als Range: "520-650" oder "520" wenn nur ein Wert
  String get caloriesDisplay {
    if (caloriesMin != null && caloriesMax != null) {
      if (caloriesMin == caloriesMax) return '$caloriesMin';
      return '$caloriesMin–$caloriesMax';
    }
    if (caloriesMin != null) return '$caloriesMin+';
    if (caloriesMax != null) return 'bis $caloriesMax';
    return '';
  }

  /// Formatiert Protein als Range: "32-40g" oder "32g"
  String get proteinDisplay {
    if (proteinMin != null && proteinMax != null) {
      if (proteinMin == proteinMax) return '${proteinMin!.toStringAsFixed(0)}g';
      return '${proteinMin!.toStringAsFixed(0)}–${proteinMax!.toStringAsFixed(0)}g';
    }
    if (proteinMin != null) return '${proteinMin!.toStringAsFixed(0)}g+';
    if (proteinMax != null) return 'bis ${proteinMax!.toStringAsFixed(0)}g';
    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      if (caloriesMin != null) 'caloriesMin': caloriesMin,
      if (caloriesMax != null) 'caloriesMax': caloriesMax,
      if (proteinMin != null) 'proteinMin': proteinMin,
      if (proteinMax != null) 'proteinMax': proteinMax,
      if (carbsMin != null) 'carbsMin': carbsMin,
      if (carbsMax != null) 'carbsMax': carbsMax,
      if (fatMin != null) 'fatMin': fatMin,
      if (fatMax != null) 'fatMax': fatMax,
    };
  }

  factory RecipeNutritionRange.fromJson(Map<String, dynamic> json) {
    return RecipeNutritionRange(
      caloriesMin: json['caloriesMin'] != null ? (json['caloriesMin'] as num).toInt() : null,
      caloriesMax: json['caloriesMax'] != null ? (json['caloriesMax'] as num).toInt() : null,
      proteinMin: json['proteinMin'] != null ? (json['proteinMin'] as num).toDouble() : null,
      proteinMax: json['proteinMax'] != null ? (json['proteinMax'] as num).toDouble() : null,
      carbsMin: json['carbsMin'] != null ? (json['carbsMin'] as num).toDouble() : null,
      carbsMax: json['carbsMax'] != null ? (json['carbsMax'] as num).toDouble() : null,
      fatMin: json['fatMin'] != null ? (json['fatMin'] as num).toDouble() : null,
      fatMax: json['fatMax'] != null ? (json['fatMax'] as num).toDouble() : null,
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final String retailer; // REWE | EDEKA | LIDL | ALDI | NETTO
  final String weekKey;
  final DateTime createdAt;
  
  // Extended fields for YAZIO-style highlights
  final int? calories; // Kalorien pro Portion (für Rückwärtskompatibilität)
  final double? price; // Preis in Euro (Standardpreis)
  final double? savings; // Ersparnis in Euro
  
  // Nutrition Range (min-max Werte)
  final RecipeNutritionRange? nutritionRange;
  
  // Price Range (Standard vs. Loyalty)
  final double? priceStandard; // Standardpreis
  final double? priceLoyalty; // Preis mit Bonus/Karte
  final String? loyaltyCondition; // z.B. "Mit K-Card", "Mit REWE Bonus"
  
  // Warnings/Flags
  final List<String>? warnings; // Validierungswarnungen
  
  // Image (DEPRECATED: Verwende image statt heroImageUrl)
  final String? heroImageUrl; // URL oder Asset-Pfad für Rezeptbild
  
  // Image Schema (NEU): Strukturierte Bild-Informationen
  final Map<String, dynamic>? image; // { "source": "asset"|"none", "asset_path": string|null, "status": "ready"|"missing" }
  final Map<String, dynamic>? imageSpec; // { "source":"stock_candidate", "query": string }
  
  // Extended fields for detailed recipes
  final int? servings; // Portionen
  final int? durationMinutes; // Zubereitungszeit in Minuten
  final int? prepMinutes; // Vorbereitungszeit (neue Rezepte)
  final int? cookMinutes; // Kochzeit (neue Rezepte)
  final String? difficulty; // "easy" | "medium" | "hard"
  final List<String>? categories; // z.B. ["Low Carb", "High Protein"]
  final List<String>? tags; // z.B. ["quick", "family", "budget"]
  final List<String>? steps; // Zubereitungsschritte
  
  // Recipe Pricing (neue Rezepte) - DEPRECATED: Verwende offersUsed statt recipe_pricing
  final double? priceBeforeEur; // Vorher-Preis
  final double? priceNowEur; // Aktueller Preis
  final double? savingsPercent; // Ersparnis in Prozent
  
  // Offers used in this recipe (preferred over recipe_pricing)
  final List<RecipeOfferUsed>? offersUsed;
  
  // Extra ingredients (nicht aus Angeboten)
  final List<ExtraIngredient>? extraIngredients;

  // New schema support
  // - base_ingredients: string list (e.g. "Salz", "Pfeffer")
  // - without_offers: string list (explicit non-offer ingredients)
  // - valid_from: arbitrary string (date/range)
  final List<String>? baseIngredients;
  final List<String>? withoutOffers;
  final String? validFrom;
  
  // Market slug (optional, z.B. "aldi_nord", "rewe")
  final String? market;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.retailer,
    required this.weekKey,
    required this.createdAt,
    this.calories,
    this.price,
    this.savings,
    this.servings,
    this.durationMinutes,
    this.prepMinutes,
    this.cookMinutes,
    this.difficulty,
    this.categories,
    this.tags,
    this.steps,
    this.nutritionRange,
    this.priceStandard,
    this.priceLoyalty,
    this.loyaltyCondition,
    this.warnings,
    this.heroImageUrl,
    this.image,
    this.imageSpec,
    this.priceBeforeEur,
      this.priceNowEur,
      this.savingsPercent,
      this.offersUsed,
      this.extraIngredients,
      this.baseIngredients,
      this.withoutOffers,
      this.validFrom,
      this.market,
  });

  /// Parses `validFrom` (supports "YYYY-MM-DD" or any string containing that date).
  /// Returns a local DateTime at 00:00.
  DateTime? get validFromDate {
    final raw = (validFrom ?? '').trim();
    if (raw.isEmpty) return null;
    final m = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(raw);
    final s = m?.group(0);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  /// True if the recipe is available "now" (or if no `validFrom` is set).
  bool get isAvailableNow {
    final d = validFromDate;
    if (d == null) return true;
    return !DateTime.now().isBefore(d);
  }

  /// UI label like: "Gültig ab 13.01."
  String? get validFromUiLabel {
    final d = validFromDate;
    if (d == null) return null;
    final date = DateFormat('dd.MM.').format(d);
    return 'Gültig ab $date';
  }

  /// Extrahiert price_before_eur aus recipe_pricing
  static double? _parsePriceBefore(Map<String, dynamic> json) {
    final pricing = JsonHelpers.asMap(json['recipe_pricing']);
    if (pricing != null) {
      final before = JsonHelpers.asDouble(pricing['price_before_eur']) ?? 
                     JsonHelpers.asDouble(pricing['total_before']);
      if (before != null) return before;
    }
    // Support snake_case: price_total_before_eur
    return JsonHelpers.asDouble(json['price_total_before_eur']) ??
           JsonHelpers.asDouble(json['priceTotalBeforeEur']) ??
           JsonHelpers.asDouble(json['price_before_eur']);
  }

  /// Extrahiert price_now_eur aus recipe_pricing
  static double? _parsePriceNow(Map<String, dynamic> json) {
    final pricing = JsonHelpers.asMap(json['recipe_pricing']);
    if (pricing != null) {
      final now = JsonHelpers.asDouble(pricing['price_now_eur']) ?? 
                  JsonHelpers.asDouble(pricing['total_now']);
      if (now != null) return now;
    }
    // Support snake_case: price_total_eur
    return JsonHelpers.asDouble(json['price_total_eur']) ??
           JsonHelpers.asDouble(json['priceTotalEur']) ??
           JsonHelpers.asDouble(json['price_eur']);
  }

  /// Extrahiert savings_percent aus recipe_pricing
  static double? _parseSavingsPercent(Map<String, dynamic> json) {
    final pricing = JsonHelpers.asMap(json['recipe_pricing']);
    if (pricing != null) {
      final percent = JsonHelpers.asDouble(pricing['savings_percent']);
      if (percent != null) return percent;
    }
    // Support snake_case: savings_percent
    return JsonHelpers.asDouble(json['savings_percent']) ??
           JsonHelpers.asDouble(json['savingsPercent']);
  }

  /// Berechnet Savings aus verschiedenen JSON-Formaten
  static double? _parseSavings(Map<String, dynamic> json) {
    // Fall 1: Direktes 'savings' Feld
    final savings = JsonHelpers.asDouble(json['savings']);
    if (savings != null && savings > 0) return savings;
    
    // Fall 2: price_total_before_eur vs price_total_eur (neue Rezepte)
    final before1 = JsonHelpers.asDouble(json['price_total_before_eur']);
    final now1 = JsonHelpers.asDouble(json['price_total_eur']);
    if (before1 != null && now1 != null && before1 > now1) {
      return before1 - now1;
    }
    
    // Fall 3: recipe_pricing Objekt (neue Rezepte)
    final pricing = JsonHelpers.asMap(json['recipe_pricing']);
    if (pricing != null) {
      final savingsAmount = JsonHelpers.asDouble(pricing['savings_amount']);
      if (savingsAmount != null && savingsAmount > 0) return savingsAmount;
      
      // Fallback: price_before_eur - price_now_eur
      final before2 = JsonHelpers.asDouble(pricing['price_before_eur']) ?? JsonHelpers.asDouble(pricing['total_before']);
      final now2 = JsonHelpers.asDouble(pricing['price_now_eur']) ?? JsonHelpers.asDouble(pricing['total_now']);
      if (before2 != null && now2 != null && before2 > now2) {
        return before2 - now2;
      }
    }
    
    return null;
  }

  /// Konvertiert server/media/... Pfad zu assets/... Pfad für lokale Assets
  static String? _convertToAssetPath(String path) {
    // IMPORTANT (store size): we do NOT bundle recipe images into the app by default.
    // If you explicitly want bundled images for a special build, enable:
    //   --dart-define=BUNDLE_RECIPE_IMAGES=true
    const bundleRecipeImages = bool.fromEnvironment('BUNDLE_RECIPE_IMAGES', defaultValue: false);
    if (!bundleRecipeImages) return null;

    // server/media/recipe_images/aldi_nord/R000.webp -> assets/recipe_images/aldi_nord/R000.webp
    // media/recipe_images/aldi_nord/R000.webp -> assets/recipe_images/aldi_nord/R000.webp
    String cleanPath = path;
    
    // Entferne server/media/ oder media/
    if (cleanPath.contains('server/media/')) {
      cleanPath = cleanPath.substring(cleanPath.indexOf('server/media/') + 13);
    } else if (cleanPath.contains('media/')) {
      cleanPath = cleanPath.substring(cleanPath.indexOf('media/') + 6);
    }
    
    // Prüfe ob es ein recipe_images Pfad ist
    if (cleanPath.contains('recipe_images/')) {
      final relativePath = cleanPath.substring(cleanPath.indexOf('recipe_images/'));
      
      // Handle "unknown/" Verzeichnis: versuche Supermarkt-Name aus Dateinamen zu extrahieren
      if (relativePath.contains('/unknown/')) {
        final fileName = relativePath.split('/').last;
        // Versuche Supermarkt-Name aus Dateinamen zu extrahieren (z.B. "nahkauf-1.webp" -> "nahkauf")
        final nameMatch = RegExp(r'^([a-z]+)-').firstMatch(fileName.toLowerCase());
        if (nameMatch != null) {
          final supermarket = nameMatch.group(1);
          return 'assets/recipe_images/$supermarket/$fileName';
        }
        // Fallback: behalte original (aber mit assets/)
        return 'assets/$relativePath';
      }
      
      return 'assets/$relativePath';
    }
    
    return null;
  }

  /// Konvertiert lokalen image_path zu Server-URL
  static String _convertImagePathToUrl(String imagePath) {
    // Nutze API_BASE_URL aus Umgebung oder Default
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (baseUrl.isEmpty) return imagePath;
    
    // Entferne absolute Pfade (alles vor "server/" oder direkte Pfade)
    String cleanPath = imagePath.trim();
    
    // Entferne alles vor "server/media/" oder "recipe_images"
    final serverMediaIndex = cleanPath.indexOf('server/media/');
    if (serverMediaIndex != -1) {
      cleanPath = cleanPath.substring(serverMediaIndex + 7); // Nach "server"
    } else {
      // Entferne absolute Pfade (alles vor "media/" oder "recipe_images")
      final mediaIndex = cleanPath.indexOf('media/');
      if (mediaIndex != -1) {
        cleanPath = cleanPath.substring(mediaIndex);
      } else {
        final recipeImagesIndex = cleanPath.indexOf('recipe_images');
        if (recipeImagesIndex != -1) {
          cleanPath = 'media/${cleanPath.substring(recipeImagesIndex)}';
        }
      }
    }
    
    // Stelle sicher, dass Pfad mit / beginnt
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    
    return '$baseUrl$cleanPath';
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // Normalisiere 'name' zu 'title' falls vorhanden
    if (!json.containsKey('title') && json.containsKey('name')) {
      json = Map<String, dynamic>.from(json);
      json['title'] = json['name'];
    }
    
    // Parse ingredients: kann String-Liste oder Objekt-Liste sein
    final List<String> ingredientsList = [];
    List<RecipeOfferUsed>? offersUsedFromIngredients;
    
    if (json['ingredients'] is List) {
      offersUsedFromIngredients = [];
      
      // Durchlaufe ALLE ingredients und erstelle RecipeOfferUsed für JEDES from_offer=true
      for (final ing in json['ingredients'] as List) {
        if (ing is String) {
          ingredientsList.add(ing);
        } else if (ing is Map) {
          // Format: {"name": "...", "amount": "..."} oder detailliert mit brand, quantity, unit, price, etc.
          final name = ing['name']?.toString() ?? '';
          final amount = ing['amount']?.toString() ?? ing['amountText']?.toString() ?? '';
          
          if (name.isNotEmpty) {
            ingredientsList.add(amount.isNotEmpty ? '$name ($amount)' : name);
          }
          
          // Wenn detaillierte Informationen vorhanden sind, erstelle RecipeOfferUsed
          final ingMap = Map<String, dynamic>.from(ing);
          
          // Prüfe ob from_offer=true ist (WICHTIG: Jedes from_offer=true muss erfasst werden!)
          final fromOffer = ingMap['from_offer'] == true || 
                           ingMap['fromOffer'] == true ||
                           ingMap['from_offer'] == 'true' ||
                           ingMap['fromOffer'] == 'true';
          
          // Erstelle RecipeOfferUsed wenn from_offer=true ODER wenn relevante Felder vorhanden sind
          final hasOfferFields = ingMap.containsKey('offer_id') || 
                                 ingMap.containsKey('offerId') ||
                                 ingMap.containsKey('price_eur') ||
                                 ingMap.containsKey('priceEur') ||
                                 ingMap.containsKey('price');
          
          if (fromOffer || hasOfferFields) {
            // Support snake_case keys: offer_id, offer_product, from_offer
            final offerId = ingMap['offer_id']?.toString() ?? 
                           ingMap['offerId']?.toString() ?? 
                           '';
            
            // Support 'product' als Fallback zu 'offer_product'
            final exactName = name.isNotEmpty 
                ? name 
                : (ingMap['offer_product']?.toString() ?? 
                   ingMap['offerProduct']?.toString() ??
                   ingMap['product']?.toString() ??
                   ingMap['exact_name']?.toString() ?? 
                   '');
            final brand = ingMap['brand']?.toString();
            final unit = ingMap['unit']?.toString() ?? '';
            
            // Parse price - ROBUST: Versuche alle möglichen Keys
            double? priceEur;
            final priceKeys = ['price_eur', 'priceEur', 'price'];
            for (final key in priceKeys) {
              if (ingMap.containsKey(key)) {
                priceEur = JsonHelpers.asDouble(ingMap[key]);
                if (priceEur != null) break;
              }
            }
            
            // Parse price_before - ROBUST: Versuche alle möglichen Keys
            double? priceBeforeEur;
            final priceBeforeKeys = ['price_before_eur', 'priceBeforeEur', 'price_before', 'uvp_eur', 'uvpEur'];
            for (final key in priceBeforeKeys) {
              if (ingMap.containsKey(key)) {
                priceBeforeEur = JsonHelpers.asDouble(ingMap[key]);
                if (priceBeforeEur != null) break;
              }
            }
            
            // Parse quantity - ROBUST
            double? quantityValue;
            final quantityRaw = ingMap['quantity'];
            if (quantityRaw != null) {
              if (quantityRaw is num) {
                quantityValue = quantityRaw.toDouble();
              } else if (quantityRaw is String) {
                // Unterstütze Komma als Dezimaltrennzeichen
                quantityValue = double.tryParse(quantityRaw.replaceAll(',', '.'));
              }
            }
            
            // WICHTIG: Erstelle RecipeOfferUsed IMMER wenn from_offer=true
            if (fromOffer) {
              // Verwende name als Fallback, wenn exactName leer ist
              final finalName = exactName.isNotEmpty ? exactName : (name.isNotEmpty ? name : 'Unbekannte Zutat');
              
              offersUsedFromIngredients.add(
                RecipeOfferUsed(
                  offerId: offerId,
                  exactName: finalName,
                  brand: brand,
                  unit: unit,
                  priceEur: priceEur ?? 0.0, // Default 0.0 wenn fehlt
                  priceBeforeEur: priceBeforeEur,
                  uvpEur: priceBeforeEur,
                  quantity: quantityValue,
                ),
              );
            } else if (!fromOffer && hasOfferFields && (offerId.isNotEmpty || priceEur != null)) {
              // Fallback: Auch ohne from_offer=true, wenn offer-Felder vorhanden sind
              final finalName = exactName.isNotEmpty ? exactName : (name.isNotEmpty ? name : 'Unbekannte Zutat');
              
                offersUsedFromIngredients.add(
                RecipeOfferUsed(
                  offerId: offerId,
                  exactName: finalName,
                  brand: brand,
                  unit: unit,
                  priceEur: priceEur ?? 0.0,
                  priceBeforeEur: priceBeforeEur,
                  uvpEur: priceBeforeEur,
                  quantity: quantityValue,
                ),
              );
            }
          }
        }
      }
      
      // Nur setzen wenn tatsächlich Einträge vorhanden sind
      if (offersUsedFromIngredients.isEmpty) {
        offersUsedFromIngredients = null;
      }
    }
    
    // Parse steps: kann String-Liste sein
    final List<String>? stepsList = JsonHelpers.asStringList(json['steps']) ?? 
        JsonHelpers.asStringList(json['instructions']);
    
    // Parse categories
    final List<String>? categoriesList = JsonHelpers.asStringList(json['categories']) ??
        (json['category'] != null ? [JsonHelpers.asString(json['category']) ?? ''].where((s) => s.isNotEmpty).toList() : null);
    
    // Parse tags (kann auch 'diet_categories' heißen in neuen Rezepten)
    List<String>? tagsList = JsonHelpers.asStringList(json['tags']) ??
        JsonHelpers.asStringList(json['diet_categories']) ??
        JsonHelpers.asStringList(json['dietTags']);
    
    // Parse offers_used (neue Rezepte)
    List<RecipeOfferUsed>? offersUsedList;
    if (json['offers_used'] is List) {
      try {
        offersUsedList = (json['offers_used'] as List)
            .map((item) {
              if (item is Map<String, dynamic> || item is Map) {
                return RecipeOfferUsed.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<RecipeOfferUsed>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing offers_used: $e');
        offersUsedList = null;
      }
    }
    
    // Falls offers_used nicht vorhanden, aber offersUsedFromIngredients erstellt wurde, nutze diese
    if (offersUsedList == null && offersUsedFromIngredients != null && offersUsedFromIngredients.isNotEmpty) {
      offersUsedList = offersUsedFromIngredients;
    } else if (offersUsedList != null && offersUsedFromIngredients != null && offersUsedFromIngredients.isNotEmpty) {
      // Kombiniere beide Listen (offers_used hat Priorität)
      offersUsedList = [...offersUsedList, ...offersUsedFromIngredients];
    }
    
    // Parse extra_ingredients (neue Rezepte)
    List<ExtraIngredient>? extraIngredientsList;
    if (json['extra_ingredients'] is List) {
      try {
        extraIngredientsList = (json['extra_ingredients'] as List)
            .map((item) {
              if (item is Map<String, dynamic> || item is Map) {
                return ExtraIngredient.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            })
            .whereType<ExtraIngredient>()
            .toList();
      } catch (e) {
        debugPrint('Error parsing extra_ingredients: $e');
        extraIngredientsList = null;
      }
    }

    // New schema: base_ingredients (strings)
    final List<String>? baseIngredientsList = JsonHelpers.asStringList(json['base_ingredients']) ??
        JsonHelpers.asStringList(json['baseIngredients']);

    // New schema: without_offers (strings)
    final List<String>? withoutOffersList = JsonHelpers.asStringList(json['without_offers']) ??
        JsonHelpers.asStringList(json['withoutOffers']);

    // New schema: valid_from (string/range)
    final String? validFromValue = json['valid_from']?.toString() ?? json['validFrom']?.toString();

    // If base_ingredients is present but extra_ingredients is missing, map base_ingredients to extraIngredients (UI uses it)
    if ((extraIngredientsList == null || extraIngredientsList.isEmpty) &&
        baseIngredientsList != null &&
        baseIngredientsList.isNotEmpty) {
      extraIngredientsList = baseIngredientsList
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => ExtraIngredient(name: s, amount: 'Basis'))
          .toList();
    }
    
    // Parse image Schema (NEU)
    Map<String, dynamic>? imageValue;
    if (json['image'] is Map) {
      imageValue = Map<String, dynamic>.from(json['image'] as Map);
    }
    
    // Parse image_spec Schema (NEU)
    Map<String, dynamic>? imageSpecValue;
    if (json['image_spec'] is Map) {
      imageSpecValue = Map<String, dynamic>.from(json['image_spec'] as Map);
    }
    
    // Parse heroImageUrl (kann direkt vorhanden sein oder aus image_path konvertiert werden)
    // WICHTIG: Bevorzuge image_path für Asset-Pfade
    String? heroImageUrlValue;
    
    // Prüfe zuerst image_path (für Asset-Pfade) - PRIORITÄT
    final imagePath = json['image_path']?.toString();
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        // Direkt Asset-Pfad verwenden (NICHT konvertieren!)
        heroImageUrlValue = imagePath;
      } else {
        // Konvertiere zu Asset-Pfad oder Server-URL
        heroImageUrlValue = _convertImagePathToUrl(imagePath);
      }
    }
    
    // Fallback zu heroImageUrl (falls image_path nicht vorhanden)
    if (heroImageUrlValue == null || heroImageUrlValue.isEmpty) {
      heroImageUrlValue = json['heroImageUrl']?.toString();
    }
    
    // Wenn heroImageUrl bereits gesetzt ist, aber mit server/media/ beginnt, konvertiere es
    if (heroImageUrlValue != null && heroImageUrlValue.isNotEmpty) {
      // Wenn heroImageUrl bereits gesetzt ist, aber mit server/media/ beginnt, konvertiere es
      // Prüfe auf verschiedene Pfad-Formate
      if (heroImageUrlValue.startsWith('server/media/') || 
          heroImageUrlValue.startsWith('server/') ||
          heroImageUrlValue.contains('recipe_images')) {
        // Versuche zuerst Asset-Pfad zu extrahieren
        final assetPath = _convertToAssetPath(heroImageUrlValue);
        if (assetPath != null) {
          heroImageUrlValue = assetPath; // Versuche Asset zuerst
        } else {
          // Fallback: Server-URL
          heroImageUrlValue = _convertImagePathToUrl(heroImageUrlValue);
        }
      }
      // Wenn es bereits eine vollständige URL ist (http://), behalte es
      else if (!heroImageUrlValue.startsWith('http://') && !heroImageUrlValue.startsWith('https://')) {
        // Falls es ein relativer Pfad ist, prüfe ob es ein Asset ist
        if (heroImageUrlValue.startsWith('assets/')) {
          // Bereits ein Asset-Pfad - OK
        } else {
          // Konvertiere zu Server-URL
          heroImageUrlValue = _convertImagePathToUrl(heroImageUrlValue);
        }
      }
    }
    
    // Debug: Logge nur bei Problemen (nicht für jedes Rezept)
    
    // Parse servings (kann "portions" oder "servings" heißen)
    final int? servingsValue = json['servings'] != null
        ? (json['servings'] as num?)?.toInt()
        : json['portions'] != null
            ? (json['portions'] as num?)?.toInt()
            : null;
    
    // Parse duration (kann "durationMinutes", "estimated_total_time_minutes", oder prep_minutes + cook_minutes sein)
    int? durationValue = json['durationMinutes'] != null
        ? (json['durationMinutes'] as num?)?.toInt()
        : json['estimated_total_time_minutes'] != null
            ? (json['estimated_total_time_minutes'] as num?)?.toInt()
            : null;
    
    // Neue Rezepte: prep_minutes + cook_minutes
    final int? prepMinutesValue = json['prep_minutes'] != null ? (json['prep_minutes'] as num?)?.toInt() : null;
    final int? cookMinutesValue = json['cook_minutes'] != null ? (json['cook_minutes'] as num?)?.toInt() : null;
    if (durationValue == null && prepMinutesValue != null && cookMinutesValue != null) {
      durationValue = prepMinutesValue + cookMinutesValue;
    }
    
    // Parse difficulty
    final String? difficultyValue = json['difficulty']?.toString();
    
    // Parse calories (kann auch in nutrition_estimate sein)
    int? caloriesValue = json['calories'] as int?;
    if (caloriesValue == null && json['nutrition_estimate'] is Map) {
      final nutrition = json['nutrition_estimate'] as Map<String, dynamic>;
      caloriesValue = nutrition['kcal_per_portion'] as int?;
    }
    
    // Parse nutrition range
    RecipeNutritionRange? nutritionRangeValue;
    final nutritionJson = JsonHelpers.asMap(json['nutritionRange']);
    if (nutritionJson != null) {
      try {
        // Handle both formats: {"kcal": [min, max]} and {"kcalMin": ..., "kcalMax": ...}
        if (nutritionJson.containsKey('kcal') && nutritionJson['kcal'] is List) {
          final kcalList = nutritionJson['kcal'] as List;
          final proteinList = nutritionJson['protein_g'] as List?;
          final carbsList = nutritionJson['carbs_g'] as List?;
          final fatList = nutritionJson['fat_g'] as List?;
          
          nutritionRangeValue = RecipeNutritionRange(
            caloriesMin: kcalList.isNotEmpty ? JsonHelpers.asInt(kcalList[0]) : null,
            caloriesMax: kcalList.length > 1 ? JsonHelpers.asInt(kcalList[1]) : (kcalList.isNotEmpty ? JsonHelpers.asInt(kcalList[0]) : null),
            proteinMin: proteinList != null && proteinList.isNotEmpty ? JsonHelpers.asDouble(proteinList[0]) : null,
            proteinMax: proteinList != null && proteinList.length > 1 ? JsonHelpers.asDouble(proteinList[1]) : (proteinList != null && proteinList.isNotEmpty ? JsonHelpers.asDouble(proteinList[0]) : null),
            carbsMin: carbsList != null && carbsList.isNotEmpty ? JsonHelpers.asDouble(carbsList[0]) : null,
            carbsMax: carbsList != null && carbsList.length > 1 ? JsonHelpers.asDouble(carbsList[1]) : (carbsList != null && carbsList.isNotEmpty ? JsonHelpers.asDouble(carbsList[0]) : null),
            fatMin: fatList != null && fatList.isNotEmpty ? JsonHelpers.asDouble(fatList[0]) : null,
            fatMax: fatList != null && fatList.length > 1 ? JsonHelpers.asDouble(fatList[1]) : (fatList != null && fatList.isNotEmpty ? JsonHelpers.asDouble(fatList[0]) : null),
          );
        } else {
          // Fallback: Try standard fromJson
          nutritionRangeValue = RecipeNutritionRange.fromJson(nutritionJson);
        }
      } catch (e) {
        // Skip nutrition range if parsing fails
        nutritionRangeValue = null;
      }
    } else if (json['nutrition_estimate'] is Map) {
      // Fallback: Konvertiere nutrition_estimate zu Range falls möglich
      final nutrition = json['nutrition_estimate'] as Map<String, dynamic>;
      final kcal = nutrition['kcal_per_portion'] as int?;
      final protein = nutrition['protein_g'] as num?;
      if (kcal != null || protein != null) {
        nutritionRangeValue = RecipeNutritionRange(
          caloriesMin: kcal,
          caloriesMax: kcal,
          proteinMin: protein?.toDouble(),
          proteinMax: protein?.toDouble(),
          carbsMin: nutrition['carbs_g'] != null ? (nutrition['carbs_g'] as num).toDouble() : null,
          carbsMax: nutrition['carbs_g'] != null ? (nutrition['carbs_g'] as num).toDouble() : null,
          fatMin: nutrition['fat_g'] != null ? (nutrition['fat_g'] as num).toDouble() : null,
          fatMax: nutrition['fat_g'] != null ? (nutrition['fat_g'] as num).toDouble() : null,
        );
      }
    }
    
    // Parse price (kann auch "priceEstimate" heißen)
    final double? priceValue = JsonHelpers.asDouble(json['price']) ?? JsonHelpers.asDouble(json['priceEstimate']);
    
    // Parse price ranges
    final double? priceStandardValue = JsonHelpers.asDouble(json['priceStandard']) ?? priceValue;
    final double? priceLoyaltyValue = JsonHelpers.asDouble(json['priceLoyalty']);
    final String? loyaltyConditionValue = json['loyaltyCondition']?.toString();
    
    // Parse warnings
    final List<String>? warningsValue = JsonHelpers.asStringList(json['warnings']);
    
    // Parse market (optional, z.B. "aldi_nord")
    final String? marketValue = json['market']?.toString() ?? json['slug']?.toString();
    
    return Recipe(
      id: json['id']?.toString() ?? 'UNKNOWN',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Unbekanntes Rezept',
      description: json['description']?.toString() ?? '',
      ingredients: ingredientsList,
      retailer: json['retailer']?.toString() ?? json['supermarket']?.toString() ?? 'UNKNOWN',
      weekKey: json['weekKey']?.toString() ?? _extractWeekKey(json),
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now())
          : DateTime.now(),
      calories: caloriesValue,
      price: priceValue,
      savings: _parseSavings(json),
      servings: servingsValue,
      durationMinutes: durationValue,
      prepMinutes: prepMinutesValue,
      cookMinutes: cookMinutesValue,
      difficulty: difficultyValue,
      categories: categoriesList,
      tags: tagsList,
      steps: stepsList,
      priceBeforeEur: _parsePriceBefore(json),
      priceNowEur: _parsePriceNow(json),
      savingsPercent: _parseSavingsPercent(json),
      offersUsed: offersUsedList,
      nutritionRange: nutritionRangeValue,
      priceStandard: priceStandardValue,
      priceLoyalty: priceLoyaltyValue,
      loyaltyCondition: loyaltyConditionValue,
      warnings: warningsValue,
      heroImageUrl: heroImageUrlValue,
      image: imageValue,
      imageSpec: imageSpecValue,
      extraIngredients: extraIngredientsList,
      baseIngredients: baseIngredientsList,
      withoutOffers: withoutOffersList,
      validFrom: validFromValue,
      market: marketValue,
    );
  }
  
  /// Berechnet Asset-Pfad für Rezept-Bild basierend auf market und id
  /// Format: assets/images/<market>_<recipeId>.png
  String? get imageAssetPath {
    if (heroImageUrl != null && heroImageUrl!.startsWith('assets/images/')) {
      return heroImageUrl;
    }
    return null;
  }

  /// Best effort hero image URL for UI.
  /// Prefers the new `image` schema (asset_path), falls back to legacy heroImageUrl.
  ///
  /// Behavior:
  /// - If `image.asset_path` is an asset path (assets/recipe_images/...), it returns:
  ///   - a network URL when API_BASE_URL is set (recommended for release)
  ///   - otherwise the asset path (useful in dev / when bundling images)
  /// - If only legacy `heroImageUrl` exists, returns it unchanged (it may already be a URL or an asset path).
  String? get resolvedHeroImageUrlForUi {
    final img = image;
    final assetPath = (img is Map<String, dynamic>) ? (img['asset_path']?.toString() ?? '') : '';
    final ap = assetPath.trim();
    if (ap.isNotEmpty) {
      if (ap.startsWith('assets/recipe_images/')) {
        final envBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '').trim();
        final baseUrl = (envBase.isNotEmpty ? envBase : (kReleaseMode ? '' : 'http://localhost:3000'))
            .replaceAll(RegExp(r'/$'), '');
        if (baseUrl.isNotEmpty) {
          final rel = ap.replaceFirst('assets/', '');
          return '$baseUrl/media/$rel';
        }
        return ap;
      }
      // If it's already a URL or another asset path, return as-is.
      return ap;
    }

    final legacy = (heroImageUrl ?? '').trim();
    if (legacy.isNotEmpty) return legacy;
    return null;
  }
  
  /// Extrahiert weekKey aus verschiedenen möglichen Feldern
  static String _extractWeekKey(Map<String, dynamic> json) {
    if (json['weekKey'] != null) return json['weekKey']?.toString() ?? '';
    if (json['week'] != null) return json['week']?.toString() ?? '';
    // Fallback: aktuelle Woche
    final now = DateTime.now();
    final year = now.year;
    final week = _getWeekNumber(now);
    return '$year-W$week';
  }
  
  /// Berechnet Kalenderwoche
  static int _getWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }

  Map<String, dynamic> toJson() {
    // Persist a stable image_path for weekly caching so heroImageUrl can be reconstructed reliably.
    // If heroImageUrl points at the dev/prod media server, derive image_path = "media/..." for storage.
    String? imagePath;
    if (heroImageUrl != null && heroImageUrl!.isNotEmpty) {
      final s = heroImageUrl!;
      // e.g. http://localhost:3000/media/recipe_images/lidl/R001.png -> media/recipe_images/lidl/R001.png
      final idx = s.indexOf('/media/');
      if (idx != -1) {
        imagePath = s.substring(idx + 1); // drop leading '/'
      } else if (s.startsWith('media/')) {
        imagePath = s;
      }
    }
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'retailer': retailer,
      'weekKey': weekKey,
      'createdAt': createdAt.toIso8601String(),
      'calories': calories,
      'price': price,
      'savings': savings,
      if (servings != null) 'servings': servings,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (prepMinutes != null) 'prepMinutes': prepMinutes,
      if (cookMinutes != null) 'cookMinutes': cookMinutes,
      if (difficulty != null) 'difficulty': difficulty,
      if (categories != null) 'categories': categories,
      if (tags != null) 'tags': tags,
      if (steps != null) 'steps': steps,
      if (nutritionRange != null) 'nutritionRange': nutritionRange!.toJson(),
      if (priceStandard != null) 'priceStandard': priceStandard,
      if (priceLoyalty != null) 'priceLoyalty': priceLoyalty,
      if (loyaltyCondition != null) 'loyaltyCondition': loyaltyCondition,
      if (warnings != null) 'warnings': warnings,
      if (imagePath != null) 'image_path': imagePath,
      if (heroImageUrl != null) 'heroImageUrl': heroImageUrl,
      if (image != null) 'image': image,
      if (imageSpec != null) 'image_spec': imageSpec,
      if (priceBeforeEur != null) 'priceBeforeEur': priceBeforeEur,
      if (priceNowEur != null) 'priceNowEur': priceNowEur,
      if (savingsPercent != null) 'savingsPercent': savingsPercent,
      if (offersUsed != null) 'offersUsed': offersUsed!.map((o) => o.toJson()).toList(),
      if (extraIngredients != null) 'extra_ingredients': extraIngredients!.map((e) => e.toJson()).toList(),
      if (baseIngredients != null) 'base_ingredients': baseIngredients,
      if (withoutOffers != null) 'without_offers': withoutOffers,
      if (validFrom != null) 'valid_from': validFrom,
      if (market != null) 'market': market,
    };
  }

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, retailer: $retailer, weekKey: $weekKey)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Recipe && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
