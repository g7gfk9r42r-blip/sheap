import 'package:shared_preferences/shared_preferences.dart';

/// Light-weight persistence helper for saving recipe favorites locally.
class FavoriteRecipesStorage {
  FavoriteRecipesStorage._(this._prefs);

  static const _favoritesKey = 'discover_favorite_recipes';
  final SharedPreferences _prefs;

  static Future<FavoriteRecipesStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FavoriteRecipesStorage._(prefs);
  }

  Set<String> loadFavorites() {
    final stored = _prefs.getStringList(_favoritesKey);
    return stored != null ? stored.toSet() : <String>{};
  }

  Future<void> saveFavorites(Set<String> favorites) async {
    await _prefs.setStringList(_favoritesKey, favorites.toList(growable: false));
  }
}
