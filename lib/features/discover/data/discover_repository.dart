import '../../../data/models/recipe.dart';
import '../../../data/repositories/cached_recipe_repository.dart';

/// Repository wrapper for Discover screen that currently loads all recipes
/// from the local asset-backed [CachedRecipeRepository]. Split out for easier testing
/// and to keep the UI free from knowledge about the data source.
class DiscoverRepository {
  const DiscoverRepository();

  Future<List<Recipe>> fetchAllRecipes() {
    return CachedRecipeRepository.instance.loadAllCached();
  }
}
