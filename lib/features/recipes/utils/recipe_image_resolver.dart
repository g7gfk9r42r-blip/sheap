/// Recipe Image Resolver - Ermittelt Asset-Pfad für Recipe-Bilder
/// 
/// Unterstützt beide Bild-Formate:
/// 1. Aktuell vorhanden: assets/images/recipes/<market>_R###.png
/// 2. Ziel: assets/images/<market>/R###_<market>.png
/// Prüft Existenz im AssetManifest.json
import 'package:flutter/services.dart';
import 'dart:convert';

class RecipeImageResolver {
  // Cache für Asset Manifest
  static Map<String, dynamic>? _assetManifestCache;

  /// Lädt Asset Manifest und cached es
  static Future<Map<String, dynamic>?> _loadAssetManifest() async {
    if (_assetManifestCache != null) return _assetManifestCache;

    try {
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      final manifest = json.decode(manifestString) as Map<String, dynamic>;

      // Normalisiere Pfade (entferne doppelte "assets/assets")
      final normalizedManifest = <String, dynamic>{};
      for (final entry in manifest.entries) {
        String normalizedKey = entry.key;
        if (normalizedKey.startsWith('assets/assets/')) {
          normalizedKey = normalizedKey.substring(7); // Entferne "assets/"
        }
        normalizedManifest[normalizedKey] = entry.value;
      }

      _assetManifestCache = normalizedManifest;
      return _assetManifestCache;
    } catch (e) {
      return null;
    }
  }

  /// Generiert Asset-Pfad für Recipe-Bild
  /// Format: assets/images/<market>_R###.png (flat structure)
  /// 
  /// Beispiel:
  ///   resolveImagePath(recipeId: 'R042', market: 'rewe')
  ///   → 'assets/images/rewe_R042.png'
  static String resolveImagePath({
    required String recipeId,
    required String market,
  }) {
    final m = market.toLowerCase().trim();
    final id = recipeId.toUpperCase().trim();
    
    // Format: assets/images/<market>_R###.png (flat structure)
    return 'assets/images/${m}_$id.png';
  }

  /// Prüft ob ein Recipe-Bild im Asset Manifest existiert
  /// Unterstützt verschiedene Datei-Endungen und beide Pfad-Formate
  static Future<bool> hasImage({
    required String recipeId,
    required String market,
  }) async {
    final path = await resolveImagePathOrNull(recipeId: recipeId, market: market);
    return path != null;
  }

  /// Gibt Asset-Pfad zurück wenn existiert, sonst null
  /// Prüft verschiedene Datei-Endungen
  /// Format: assets/images/<market>_R###.png (flat structure)
  static Future<String?> resolveImagePathOrNull({
    required String recipeId,
    required String market,
  }) async {
    final manifest = await _loadAssetManifest();
    if (manifest == null) return null;

    final extensions = ['.png', '.jpg', '.jpeg', '.webp'];
    
    // Format: assets/images/<market>_R###.png
    final basePath = resolveImagePath(recipeId: recipeId, market: market);
    for (final ext in extensions) {
      final imagePath = basePath.replaceAll('.png', ext);
      if (manifest.containsKey(imagePath)) {
        return imagePath;
      }
    }

    return null;
  }

  /// Findet alle Recipe-Bilder für einen Market
  /// Format: assets/images/<market>_R###.png (flat structure)
  static Future<List<String>> findImagesForMarket(String market) async {
    final manifest = await _loadAssetManifest();
    if (manifest == null) return [];

    final images = <String>[];
    final marketLower = market.toLowerCase();
    final imagePrefix = 'assets/images/${marketLower}_';

    for (final key in manifest.keys) {
      if (key.startsWith(imagePrefix) &&
          (key.endsWith('.png') ||
              key.endsWith('.jpg') ||
              key.endsWith('.jpeg') ||
              key.endsWith('.webp'))) {
        images.add(key);
      }
    }

    return images;
  }

  /// Cleared Cache (für Debugging/Tests)
  static void clearCache() {
    _assetManifestCache = null;
  }
}
