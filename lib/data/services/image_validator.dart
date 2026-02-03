import 'package:flutter/services.dart';
import '../models/recipe.dart';

/// Service zur Validierung von Rezept-Bildern
/// Prüft, ob alle Bilder für Rezepte vorhanden sind
class ImageValidator {
  /// Validiert alle Bilder für eine Liste von Rezepten
  /// Gibt ein Ergebnis zurück mit:
  /// - totalImages: Anzahl erwarteter Bilder
  /// - foundImages: Anzahl gefundener Bilder
  /// - missingImages: Liste der fehlenden Bildpfade
  static Future<ImageValidationResult> validateRecipeImages(
    List<Recipe> recipes,
  ) async {
    int totalImages = 0;
    int foundImages = 0;
    final List<String> missingImages = [];
    final Map<String, List<String>> missingByMarket = {};

    for (final recipe in recipes) {
      final imagePath = recipe.heroImageUrl;
      
      if (imagePath != null && imagePath.isNotEmpty) {
        totalImages++;
        
        // Prüfe ob Asset existiert
        final exists = await _checkAssetExists(imagePath);
        
        if (exists) {
          foundImages++;
        } else {
          missingImages.add(imagePath);
          
          // Gruppiere nach Markt
          final market = _extractMarketFromPath(imagePath);
          if (market != null) {
            missingByMarket.putIfAbsent(market, () => []).add(recipe.id);
          }
        }
      }
    }

    return ImageValidationResult(
      totalImages: totalImages,
      foundImages: foundImages,
      missingImages: missingImages,
      missingByMarket: missingByMarket,
    );
  }

  /// Validiert Bilder für alle Rezepte eines bestimmten Markts
  static Future<ImageValidationResult> validateMarketImages(
    String market,
    List<Recipe> recipes,
  ) async {
    final marketRecipes = recipes.where((r) => 
      r.retailer.toUpperCase() == market.toUpperCase() ||
      r.market?.toLowerCase() == market.toLowerCase()
    ).toList();
    
    return validateRecipeImages(marketRecipes);
  }

  /// Prüft ob ein Asset existiert
  static Future<bool> _checkAssetExists(String assetPath) async {
    try {
      // Versuche Asset zu laden
      await rootBundle.load(assetPath);
      return true;
    } catch (e) {
      // Asset nicht gefunden
      return false;
    }
  }

  /// Extrahiert Markt aus Asset-Pfad
  /// z.B. "assets/images/recipes/lidl/R001.png" -> "lidl"
  static String? _extractMarketFromPath(String path) {
    final match = RegExp(r'/recipes/([^/]+)/').firstMatch(path);
    return match?.group(1);
  }
}

/// Ergebnis einer Bild-Validierung
class ImageValidationResult {
  final int totalImages;
  final int foundImages;
  final List<String> missingImages;
  final Map<String, List<String>> missingByMarket; // market -> [recipe_ids]

  ImageValidationResult({
    required this.totalImages,
    required this.foundImages,
    required this.missingImages,
    required this.missingByMarket,
  });

  int get missingCount => totalImages - foundImages;
  
  double get completionRate => totalImages > 0 
    ? (foundImages / totalImages) * 100 
    : 100.0;

  bool get allImagesPresent => missingCount == 0;

  String get summary {
    if (allImagesPresent) {
      return '✅ Alle $totalImages Bilder vorhanden!';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('📊 Bilder-Status:');
    buffer.writeln('   ✅ Gefunden: $foundImages / $totalImages');
    buffer.writeln('   ❌ Fehlend: $missingCount');
    buffer.writeln('   📈 Fertig: ${completionRate.toStringAsFixed(1)}%');
    
    if (missingByMarket.isNotEmpty) {
      buffer.writeln('\n❌ Fehlende Bilder nach Markt:');
      missingByMarket.forEach((market, recipeIds) {
        buffer.writeln('   $market: ${recipeIds.length} Rezepte');
        if (recipeIds.length <= 10) {
          buffer.writeln('      IDs: ${recipeIds.join(", ")}');
        } else {
          buffer.writeln('      IDs: ${recipeIds.take(10).join(", ")}, ... (${recipeIds.length - 10} weitere)');
        }
      });
    }
    
    return buffer.toString();
  }
}

