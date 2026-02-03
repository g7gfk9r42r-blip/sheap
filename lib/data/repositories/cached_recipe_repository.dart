/// Cached Recipe Repository
/// Lädt Rezepte nur EINMAL beim ersten Aufruf und cached das Future
/// Verhindert mehrfaches Laden durch Rebuilds
import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../../features/recipes/data/recipe_loader_from_prospekte.dart';
import '../services/supermarket_recipe_repository.dart';

class CachedRecipeRepository {
  CachedRecipeRepository._();
  static CachedRecipeRepository? _instance;
  static CachedRecipeRepository get instance {
    _instance ??= CachedRecipeRepository._();
    return _instance!;
  }

  Future<List<Recipe>>? _loadFuture;
  bool _loading = false;

  Future<List<Recipe>> _loadAllRecipesOnce({
    required bool forceRefreshRemote,
    String? weekKeyOverride,
  }) async {
    try {
      // 1) Remote-first (weekly cached) if server is configured/reachable.
      try {
        final byMarket = await SupermarketRecipeRepository.loadAllSupermarketRecipes(
          forceRefresh: forceRefreshRemote,
          weekKeyOverride: weekKeyOverride,
        );
        final remote = byMarket.values.expand((x) => x).toList();
        if (remote.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('🌐 Recipes(remote): loaded ${remote.length} (weekly cached)');
          }
          return remote;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Recipes(remote) failed, falling back to assets: $e');
        }
      }

      // 2) Fallback: Assets (bundled)
      final recipes = await RecipeLoaderFromProspekte.loadAllRecipes();
      return recipes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error loading recipes in CachedRecipeRepository: $e');
      }
      return [];
    }
  }

  /// Returns cached recipes. By default it loads once per app launch.
  /// If `forceRefresh=true`, it refreshes remote cache first (if available).
  Future<List<Recipe>> loadAllCached({bool forceRefresh = false}) {
    if (forceRefresh) {
      _loadFuture = _loadAllRecipesOnce(forceRefreshRemote: true);
      return _loadFuture!;
    }
    _loadFuture ??= _loadAllRecipesOnce(forceRefreshRemote: false);
    return _loadFuture!;
  }

  /// Lädt Rezepte für einen bestimmten Market (filtert aus gecachten Daten)
  Future<List<Recipe>> loadForMarket(String market) async {
    final allRecipes = await loadAllCached();
    final marketLower = market.toLowerCase();
    return allRecipes.where((recipe) {
      final recipeMarket = recipe.market?.toLowerCase() ?? recipe.retailer.toLowerCase();
      return recipeMarket == marketLower;
    }).toList();
  }

  /// Refresh remote cache (if server is reachable) and update the cached future.
  Future<List<Recipe>> refreshRemote({String? weekKeyOverride}) async {
    if (_loading) return loadAllCached();
    _loading = true;
    try {
      _loadFuture = _loadAllRecipesOnce(forceRefreshRemote: true, weekKeyOverride: weekKeyOverride);
      final f = _loadFuture!;
      final r = await f;
      return r;
    } finally {
      _loading = false;
    }
  }
}

