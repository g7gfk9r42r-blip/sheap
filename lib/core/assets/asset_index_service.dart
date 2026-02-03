import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Asset-Index Service
/// Lädt asset_index.json und bietet API zum Prüfen ob Assets existieren
class AssetIndexService {
  AssetIndexService._();
  static AssetIndexService? _instance;
  static AssetIndexService get instance {
    _instance ??= AssetIndexService._();
    return _instance!;
  }

  Map<String, dynamic>? _index;
  bool _loaded = false;
  bool _loading = false;

  /// Lädt Asset-Index (einmalig beim ersten Aufruf)
  /// Fallback: Wenn asset_index.json nicht existiert, wird ein leerer Index verwendet
  Future<void> loadIndex() async {
    if (_loaded || _loading) return;
    _loading = true;

    try {
      final jsonString = await rootBundle.loadString('assets/index/asset_index.json');
      _index = json.decode(jsonString) as Map<String, dynamic>;
      _loaded = true;
      if (kDebugMode) {
        debugPrint('✅ Asset-Index geladen: ${_index?['recipes']?.length ?? 0} Markets');
      }
    } catch (e) {
      // Fallback: Leerer Index (asset_index.json ist optional)
      if (kDebugMode) {
        debugPrint('ℹ️  Asset-Index nicht gefunden (optional): assets/index/asset_index.json');
        debugPrint('   → App funktioniert ohne Index, verwendet AssetManifest.json stattdessen');
      }
      _index = {
        'recipes': <String>[],
        'recipe_images': <String, dynamic>{},
      };
      _loaded = true;
    } finally {
      _loading = false;
    }
  }

  /// Prüft ob ein Rezept-Bild existiert
  bool hasRecipeImage(String market, String recipeId) {
    if (_index == null) {
      // Index noch nicht geladen → false (sicherer Fallback)
      return false;
    }

    final recipeImages = _index!['recipe_images'] as Map<String, dynamic>?;
    if (recipeImages == null) return false;

    final marketImages = recipeImages[market] as List<dynamic>?;
    if (marketImages == null) return false;

    // Normalisiere Recipe-ID (R001, r001, R1 -> R001)
    final normalizedId = _normalizeRecipeId(recipeId);
    
    return marketImages.contains(normalizedId);
  }

  /// Gibt Asset-Pfad zurück oder Fallback
  String recipeImagePathOrFallback(String market, String recipeId) {
    // Normalisiere Market-Slug
    final marketSlug = _normalizeMarketSlug(market);
    
    // Normalisiere Recipe-ID
    final normalizedId = _normalizeRecipeId(recipeId);
    
    // Prüfe ob Bild existiert
    if (hasRecipeImage(marketSlug, normalizedId)) {
      // Default to PNG (matches server/media). WebP is optional.
      return 'assets/recipe_images/$marketSlug/$normalizedId.png';
    }
    
    // Fallback: keep a tiny bundled UI asset (we don't bundle recipe images in release).
    return 'assets/logo/sheep transp.png';
  }

  /// Gibt Recipe-Count für einen Market zurück
  int getRecipeCount(String market) {
    if (_index == null) return 0;
    final marketSlug = _normalizeMarketSlug(market);
    
    final recipes = _index!['recipes'] as Map<String, dynamic>?;
    if (recipes == null) return 0;
    
    final marketData = recipes[marketSlug] as Map<String, dynamic>?;
    if (marketData == null) return 0;
    
    return marketData['count'] as int? ?? 0;
  }

  /// Liste aller Markets mit Rezepten
  List<String> getAvailableMarkets() {
    if (_index == null) return [];
    final recipes = _index!['recipes'] as List<dynamic>?;
    if (recipes == null) return [];
    return recipes.map((e) => e.toString()).toList();
  }

  /// Liste aller Recipe-IDs für einen Market
  List<String> getRecipeImageIds(String market) {
    if (_index == null) return [];
    final marketSlug = _normalizeMarketSlug(market);
    
    final recipeImages = _index!['recipe_images'] as Map<String, dynamic>?;
    if (recipeImages == null) return [];
    
    final marketImages = recipeImages[marketSlug] as List<dynamic>?;
    if (marketImages == null) return [];
    
    return marketImages.map((e) => e.toString()).toList();
  }

  /// Normalisiert Market-Name zu Slug
  String _normalizeMarketSlug(String market) {
    String normalized = market.toLowerCase().trim();
    
    // Spezielle Mappings
    if (normalized == 'aldi nord' || normalized == 'aldi nörd') {
      return 'aldi_nord';
    }
    if (normalized == 'aldi süd' || normalized == 'aldi sued') {
      return 'aldi_sued';
    }
    if (normalized == 'biomarkt' || normalized == 'bio markt') {
      return 'denns';
    }
    
    // Ersetze Sonderzeichen
    normalized = normalized.replaceAll(' ', '_').replaceAll('-', '_');
    normalized = normalized.replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ä', 'a');
    
    return normalized;
  }

  /// Normalisiert Recipe-ID zu R001 Format
  String _normalizeRecipeId(String recipeId) {
    if (recipeId.isEmpty) return '';
    
    // Entferne Datei-Endungen
    String cleaned = recipeId.replaceAll('.webp', '').replaceAll('.png', '').replaceAll('.jpg', '');
    
    // Entferne Präfixe (z.B. "aldi_sued-")
    if (cleaned.contains('-')) {
      cleaned = cleaned.split('-').last;
    }
    
    // Extrahiere Zahl
    final regex = RegExp(r'[rR]?(\d+)');
    final match = regex.firstMatch(cleaned);
    
    if (match != null) {
      final num = int.tryParse(match.group(1) ?? '');
      if (num != null) {
        return 'R${num.toString().padLeft(3, '0')}';
      }
    }
    
    // Fallback: Uppercase
    return cleaned.toUpperCase();
  }
}

