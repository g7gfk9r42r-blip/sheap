import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_privacy_config.dart';

/// Light-weight persistence helper for saving recipe favorites locally.
class FavoriteRecipesStorage {
  FavoriteRecipesStorage._(this._prefs);

  static const _favoritesKey = 'recipes_favorite_recipes';
  final SharedPreferences _prefs;
  static Set<String> _memoryFavorites = <String>{};

  static Future<FavoriteRecipesStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return FavoriteRecipesStorage._(prefs);
  }

  Set<String> loadFavorites() {
    if (!AppPrivacyConfig.persistFavoritesLocal) {
      return _memoryFavorites;
    }
    final stored = _prefs.getStringList(_favoritesKey);
    return stored != null ? stored.toSet() : <String>{};
  }

  Future<void> saveFavorites(Set<String> favorites) async {
    if (!AppPrivacyConfig.persistFavoritesLocal) {
      _memoryFavorites = Set<String>.from(favorites);
      return;
    }
    await _prefs.setStringList(_favoritesKey, favorites.toList(growable: false));
  }
}
