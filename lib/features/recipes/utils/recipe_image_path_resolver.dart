/// Recipe Image Path Resolver
/// Baut Image-Pfade basierend auf Market + Recipe-ID
/// Prüft Existenz im AssetManifest.json
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class RecipeImagePathResolver {
  static Set<String>? _assetPathsCache;
  static int _debugResolvedCount = 0;
  static int _debugNotFoundCount = 0;
  static bool _debugSuppressedResolved = false;
  static bool _debugSuppressedNotFound = false;
  static const int _debugLogLimit = 8;
  // IMPORTANT: We do not bundle recipe images by default (keeps app size small).
  // Only run asset-manifest checks when explicitly enabled.
  static const bool _bundleRecipeImages =
      bool.fromEnvironment('BUNDLE_RECIPE_IMAGES', defaultValue: false);

  /// Lädt alle Asset-Pfade aus AssetManifest.json als Set
  static Future<Set<String>> _loadAssetPaths() async {
    if (_assetPathsCache != null) return _assetPathsCache!;

    try {
      final manifestString = await rootBundle.loadString('AssetManifest.json');
      final manifestData = json.decode(manifestString);

      final assetPaths = <String>{};

      if (manifestData is Map) {
        for (final entry in manifestData.entries) {
          String key = entry.key.toString();
          if (key.startsWith('assets/assets/')) {
            key = key.substring(7);
          }
          if (!key.endsWith('.DS_Store')) {
            assetPaths.add(key);
          }
        }

        if (manifestData.values.any((v) => v is List)) {
          for (final value in manifestData.values) {
            if (value is List) {
              for (final item in value) {
                if (item is String) {
                  String normalizedItem = item;
                  if (normalizedItem.startsWith('assets/assets/')) {
                    normalizedItem = normalizedItem.substring(7);
                  }
                  if (!normalizedItem.endsWith('.DS_Store')) {
                    assetPaths.add(normalizedItem);
                  }
                }
              }
            }
          }
        }
      } else if (manifestData is List) {
        for (final item in manifestData) {
          if (item is String) {
            String normalizedItem = item;
            if (normalizedItem.startsWith('assets/assets/')) {
              normalizedItem = normalizedItem.substring(7);
            }
            if (!normalizedItem.endsWith('.DS_Store')) {
              assetPaths.add(normalizedItem);
            }
          }
        }
      }

      _assetPathsCache = assetPaths;
      return assetPaths;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️  Failed to load AssetManifest.json: $e');
      }
      return {};
    }
  }

  /// Baut Image-Pfad im Bundle (nur wenn BUNDLE_RECIPE_IMAGES=true):
  /// assets/recipe_images/<market>/<recipeId>.png
  static String buildImagePath(String market, String recipeId) {
    final m = market.toLowerCase().trim();
    final id = recipeId.toUpperCase().trim();
    return 'assets/recipe_images/$m/$id.png';
  }

  /// Prüft ob Image existiert und gibt Asset-Pfad zurück (mit Fallback auf .jpg/.webp).
  /// Läuft nur, wenn `BUNDLE_RECIPE_IMAGES=true` gesetzt ist.
  static Future<String?> resolveImagePath({
    required String market,
    required String recipeId,
  }) async {
    if (!_bundleRecipeImages) {
      // Recipe images are remote-first. Avoid confusing "NOT found" logs in dev.
      return null;
    }
    final assetPaths = await _loadAssetPaths();
    final extensions = ['.png', '.jpg', '.jpeg', '.webp'];

    final basePath = buildImagePath(market, recipeId);
    for (final ext in extensions) {
      final imagePath = basePath.replaceAll('.png', ext);
      if (assetPaths.contains(imagePath)) {
        if (kDebugMode) {
          _debugResolvedCount++;
          if (_debugResolvedCount <= _debugLogLimit) {
            debugPrint('✅ Image resolved (bundle): $imagePath');
          } else if (!_debugSuppressedResolved) {
            _debugSuppressedResolved = true;
            debugPrint('ℹ️ Image resolved logs suppressed (>${_debugLogLimit}).');
          }
        }
        return imagePath;
      }
    }

    // Kein Bild gefunden
    if (kDebugMode) {
      _debugNotFoundCount++;
      if (_debugNotFoundCount <= _debugLogLimit) {
        debugPrint('⚠️  Image NOT found for ${market}_$recipeId');
        debugPrint('   Tried: $basePath (and variants)');
      } else if (!_debugSuppressedNotFound) {
        _debugSuppressedNotFound = true;
        debugPrint('ℹ️ Image NOT found logs suppressed (>${_debugLogLimit}).');
      }
    }
    return null;
  }

  static void clearCache() {
    _assetPathsCache = null;
    _debugResolvedCount = 0;
    _debugNotFoundCount = 0;
    _debugSuppressedResolved = false;
    _debugSuppressedNotFound = false;
  }
}

