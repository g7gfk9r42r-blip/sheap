/// Asset Path Resolver
/// Zentraler Helper für konsistente Asset-Pfade
/// 
/// Standard-Struktur:
/// - Rezepte: assets/recipes/<market>/<weekKey>/<market>_recipes.json
/// - Bilder: assets/recipes/<market>/images/<recipe_id>.png
import 'package:flutter/foundation.dart';

class AssetPathResolver {
  /// Market-Namen Mapping (UI → Slug)
  /// Unterstützt sowohl neue als auch alte Market-Namen
  static const Map<String, String> _marketMapping = {
    // ALDI
    'ALDI NORD': 'aldi_nord',
    'ALDI SÜD': 'aldi_sued',
    'ALDI SUED': 'aldi_sued',
    'ALDI': 'aldi_nord', // Default zu Nord
    // Standard-Märkte
    'REWE': 'rewe',
    'EDEKA': 'edeka',
    'LIDL': 'lidl',
    'NETTO': 'netto',
    'PENNY': 'penny',
    'NORMA': 'norma',
    'KAUFLAND': 'kaufland',
    'NAHKAUF': 'nahkauf',
    'TEGUT': 'tegut',
    'BIOMARKT': 'biomarkt',
  };

  /// Normalisiert Market-Namen zu Slug
  /// "ALDI NORD" -> "aldi_nord"
  /// "aldi_nord" -> "aldi_nord" (bereits normalisiert)
  /// "ALDI NORD" -> "aldi_nord" (großgeschrieben)
  static String normalizeMarketSlug(String market) {
    final trimmed = market.trim();
    
    // 1. Direktes Mapping (großgeschrieben, prioritär)
    final upperKey = trimmed.toUpperCase();
    if (_marketMapping.containsKey(upperKey)) {
      return _marketMapping[upperKey]!;
    }
    
    // 2. Bereits normalisiert? (prüfe lowercase)
    final lower = trimmed.toLowerCase();
    if (_marketMapping.values.contains(lower)) {
      return lower;
    }
    
    // 3. Automatische Normalisierung (Fallback)
    final normalized = lower
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll('ü', 'ue')
        .replaceAll('ö', 'oe')
        .replaceAll('ä', 'ae')
        .replaceAll('ß', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    
    return normalized;
  }

  /// Generiert Rezept-Dateipfad (NEUE Struktur)
  /// assets/recipes/<market>/<weekKey>/<market>_recipes.json
  /// 
  /// Beispiel: assets/recipes/aldi_nord/2026-W03/aldi_nord_recipes.json
  static String recipeFilePath(String market, String weekKey) {
    final slug = normalizeMarketSlug(market);
    return 'assets/recipes/$slug/$weekKey/${slug}_recipes.json';
  }

  /// Generiert Bild-Pfad (NEUE Struktur)
  /// assets/recipes/<market>/images/<recipe_id>.png
  /// 
  /// Beispiel: assets/recipes/aldi_nord/images/R001.png
  static String imageAssetPath(String market, String recipeId) {
    final slug = normalizeMarketSlug(market);
    // Normalisiere Recipe ID (R001 -> R001.png, R001.webp -> R001.png)
    final normalizedId = recipeId.replaceAll(RegExp(r'\.(png|webp|jpg|jpeg)$'), '');
    
    // Validiere ID-Format (R###)
    if (!RegExp(r'^R\d{1,3}$').hasMatch(normalizedId)) {
      debugPrint('⚠️  Ungültige Recipe ID: $recipeId (erwartet: R###)');
      // Trotzdem zurückgeben, aber warnen
    }
    
    return 'assets/recipes/$slug/images/$normalizedId.png';
  }

  /// Alte Bild-Pfad-Struktur (Fallback)
  /// assets/images/recipes/<market>/<recipe_id>.png
  /// 
  /// Wird verwendet, wenn neue Struktur nicht existiert
  static String oldImageAssetPath(String market, String recipeId) {
    final slug = normalizeMarketSlug(market);
    final normalizedId = recipeId.replaceAll(RegExp(r'\.(png|webp|jpg|jpeg)$'), '');
    return 'assets/images/recipes/$slug/$normalizedId.png';
  }

  /// Validiert Recipe ID Format
  /// Muss exakt R### Format sein (R001-R999)
  static bool isValidRecipeId(String recipeId) {
    final normalized = recipeId.replaceAll(RegExp(r'\.(png|webp|jpg|jpeg)$'), '');
    return RegExp(r'^R\d{1,3}$').hasMatch(normalized);
  }

  /// Extrahiert Recipe ID aus Dateinamen
  /// "R001.png" -> "R001"
  /// "R050.webp" -> "R050"
  static String? extractRecipeIdFromFilename(String filename) {
    final match = RegExp(r'^(R\d{1,3})\.').firstMatch(filename);
    return match?.group(1);
  }
}
