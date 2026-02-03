/// Startup Diagnostics Service
/// Gibt beim App-Start genau einmal einen kompakten Report aus
/// mit allen relevanten Problemen (Missing assets, ungültige IDs, etc.)
import 'package:flutter/foundation.dart';
import '../../data/models/recipe.dart';

/// Diagnose-Ergebnis für einen Market
class MarketDiagnostics {
  final String market;
  final String recipeFilePath;
  final String recipesFileUsed; // "recipes.json" oder "fallback json"
  final int recipesLoaded;
  final int recipesSkipped;
  final List<String> skipReasons;
  final List<String> invalidIds;
  final List<String> missingImages;
  final String? jsonParseError;
  final String? imagePathStrategy; // "recipes/" oder "root"
  final String? exampleImagePath; // Beispiel für erfolgreich aufgelöstes Bild
  final String imageRenderMode; // "asset" oder "network" - MUSS "asset" sein

  MarketDiagnostics({
    required this.market,
    required this.recipeFilePath,
    this.recipesFileUsed = 'recipes.json',
    this.recipesLoaded = 0,
    this.recipesSkipped = 0,
    this.skipReasons = const [],
    this.invalidIds = const [],
    this.missingImages = const [],
    this.jsonParseError,
    this.imagePathStrategy,
    this.exampleImagePath,
    this.imageRenderMode = 'asset',
  });
}

/// Startup Diagnostics Report
class StartupDiagnosticsReport {
  final int marketsFound;
  final int recipeFilesFound;
  final List<MarketDiagnostics> marketResults;
  final List<String> duplicateMarketRecipeIds; // Format: "market_R###"
  final List<String> unknownMarkets;
  final List<String> wrongFilenames;
  final List<String> skippedMarkets; // Markets ohne *_recipes.json

  StartupDiagnosticsReport({
    required this.marketsFound,
    required this.recipeFilesFound,
    this.marketResults = const [],
    this.duplicateMarketRecipeIds = const [],
    this.unknownMarkets = const [],
    this.wrongFilenames = const [],
    this.skippedMarkets = const [],
  });

  /// Gibt den Report als formatierten String aus
  void printReport() {
    if (!kDebugMode) return;

    debugPrint('');
    debugPrint('═' * 60);
    debugPrint('=== STARTUP DIAGNOSTICS ===');
    debugPrint('═' * 60);
    debugPrint('');

    // Übersicht
    debugPrint('📊 OVERVIEW');
    debugPrint('   Markets found: $marketsFound');
    debugPrint('   Recipe JSON files found: $recipeFilesFound');
    debugPrint('');

    // Pro Market Details
    if (marketResults.isNotEmpty) {
      debugPrint('📁 MARKET DETAILS');
      for (final market in marketResults) {
        debugPrint('   ┌─ ${market.market.toUpperCase()}');
        debugPrint('   │  File: ${market.recipeFilePath}');
        debugPrint('   │  Recipes file used: ${market.recipesFileUsed}');
        debugPrint('   │  Recipes loaded: ${market.recipesLoaded}');
        debugPrint('   │  Image render mode: ${market.imageRenderMode} ${market.imageRenderMode != "asset" ? "⚠️  (SHOULD BE asset!)" : ""}');
        
        if (market.recipesSkipped > 0) {
          debugPrint('   │  Recipes skipped: ${market.recipesSkipped}');
          
          // Gruppiere Skip-Reasons
          final reasonCounts = <String, int>{};
          for (final reason in market.skipReasons) {
            reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
          }
          
          if (reasonCounts.isNotEmpty) {
            debugPrint('   │  Skip reasons:');
            reasonCounts.forEach((reason, count) {
              debugPrint('   │    - $reason ($count x)');
            });
          }
        }
        
        if (market.invalidIds.isNotEmpty) {
          debugPrint('   │  Invalid IDs (examples):');
          for (final id in market.invalidIds.take(5)) {
            debugPrint('   │    - "$id"');
          }
          if (market.invalidIds.length > 5) {
            debugPrint('   │    ... and ${market.invalidIds.length - 5} more');
          }
        }
        
        if (market.missingImages.isNotEmpty) {
          debugPrint('   │  Missing images (examples):');
          for (final img in market.missingImages.take(5)) {
            debugPrint('   │    - $img');
          }
          if (market.missingImages.length > 5) {
            debugPrint('   │    ... and ${market.missingImages.length - 5} more');
          }
        }
        
        if (market.imagePathStrategy != null) {
          debugPrint('   │  Image path strategy: ${market.imagePathStrategy}');
        }
        
        if (market.exampleImagePath != null) {
          debugPrint('   │  Example image path: ${market.exampleImagePath}');
        }
        
        if (market.jsonParseError != null) {
          debugPrint('   │  JSON Parse Error: ${market.jsonParseError}');
        }
        
        debugPrint('   └─');
        debugPrint('');
      }
    }

    // Globale Probleme
    bool hasGlobalIssues = false;
    
    if (duplicateMarketRecipeIds.isNotEmpty) {
      hasGlobalIssues = true;
      debugPrint('⚠️  DUPLICATE MARKET_RECIPE IDs');
      debugPrint('   (IDs dürfen sich zwischen Märkten wiederholen, aber nicht innerhalb eines Markets)');
      for (final id in duplicateMarketRecipeIds.take(10)) {
        debugPrint('   - $id');
      }
      if (duplicateMarketRecipeIds.length > 10) {
        debugPrint('   ... and ${duplicateMarketRecipeIds.length - 10} more');
      }
      debugPrint('');
    }

    if (skippedMarkets.isNotEmpty) {
      hasGlobalIssues = true;
      debugPrint('⚠️  SKIPPED MARKETS (no *_recipes.json found)');
      for (final market in skippedMarkets) {
        debugPrint('   - $market: no *_recipes.json found');
      }
      debugPrint('');
    }

    if (unknownMarkets.isNotEmpty) {
      hasGlobalIssues = true;
      debugPrint('⚠️  UNKNOWN MARKETS');
      for (final market in unknownMarkets) {
        debugPrint('   - $market');
      }
      debugPrint('');
    }

    if (wrongFilenames.isNotEmpty) {
      hasGlobalIssues = true;
      debugPrint('⚠️  WRONG FILENAMES (expected *_recipes.json)');
      for (final filename in wrongFilenames) {
        debugPrint('   - $filename');
      }
      debugPrint('');
    }

    if (!hasGlobalIssues && marketResults.every((m) => 
      m.recipesSkipped == 0 && 
      m.invalidIds.isEmpty && 
      m.missingImages.isEmpty && 
      m.jsonParseError == null
    ) && skippedMarkets.isEmpty) {
      debugPrint('✅ All checks passed - no issues found');
      debugPrint('');
    }

    debugPrint('═' * 60);
    debugPrint('');
  }
}

/// Startup Diagnostics Service (Singleton)
class StartupDiagnostics {
  StartupDiagnostics._();
  static StartupDiagnostics? _instance;
  static StartupDiagnostics get instance {
    _instance ??= StartupDiagnostics._();
    return _instance!;
  }

  bool _hasRun = false;
  StartupDiagnosticsReport? _lastReport;

  /// Führt Diagnostik aus (nur einmal pro App-Start)
  Future<StartupDiagnosticsReport> runDiagnostics({
    required List<Recipe> recipes,
    required Map<String, String> recipeFiles,
    required Map<String, MarketDiagnostics> marketDiagnostics,
  }) async {
    if (_hasRun) {
      return _lastReport!;
    }

    _hasRun = true;

    // Sammle doppelte IDs NUR als market_recipeId Kombination
    // IDs dürfen sich zwischen Märkten wiederholen (z.B. biomarkt_R001 und aldi_sued_R001 ist OK)
    final marketRecipeIdCounts = <String, int>{}; // Key: "market_R###"
    for (final recipe in recipes) {
      final market = recipe.market?.toLowerCase().trim() ?? 'unknown';
      final recipeId = recipe.id.trim();
      final key = '${market}_$recipeId';
      marketRecipeIdCounts[key] = (marketRecipeIdCounts[key] ?? 0) + 1;
    }
    final duplicateMarketRecipeIds = marketRecipeIdCounts.entries
        .where((e) => e.value > 1)
        .map((e) => e.key)
        .toList();

    // Sammle unbekannte Markets
    final knownMarkets = recipeFiles.keys.toSet();
    final recipeMarkets = recipes.map((r) => r.market?.toLowerCase().trim()).whereType<String>().toSet();
    final unknownMarkets = recipeMarkets
        .where((m) => !knownMarkets.contains(m))
        .toList();

    // Sammle falsche Dateinamen
    final wrongFilenames = <String>[];
    for (final entry in recipeFiles.entries) {
      final filename = entry.value.split('/').last;
      if (!filename.endsWith('_recipes.json')) {
        wrongFilenames.add(entry.value);
      }
    }

    // Sammle übersprungene Markets (z.B. aldi_nord ohne *_recipes.json)
    // Diese werden bereits in marketDiagnostics erfasst, aber hier für Report sammeln
    final skippedMarkets = <String>[];
    // (Wird vom Loader bereits geloggt, hier nur für Report)

    final report = StartupDiagnosticsReport(
      marketsFound: recipeFiles.length,
      recipeFilesFound: recipeFiles.length,
      marketResults: marketDiagnostics.values.toList(),
      duplicateMarketRecipeIds: duplicateMarketRecipeIds,
      unknownMarkets: unknownMarkets,
      wrongFilenames: wrongFilenames,
      skippedMarkets: skippedMarkets,
    );

    _lastReport = report;
    report.printReport();

    return report;
  }

  /// Reset (für Tests)
  void reset() {
    _hasRun = false;
    _lastReport = null;
  }
}

