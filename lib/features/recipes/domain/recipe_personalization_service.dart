import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/customer_storage.dart';
import '../../../data/models/recipe.dart';
import '../../customer/data/customer_data_store.dart';
import '../../customer/domain/models/customer_preferences.dart';

class RecipePersonalizationPrefs {
  final bool vegetarian;
  final bool vegan;

  const RecipePersonalizationPrefs({
    required this.vegetarian,
    required this.vegan,
  });

  static const none = RecipePersonalizationPrefs(vegetarian: false, vegan: false);

  @override
  String toString() => 'RecipePersonalizationPrefs(vegetarian=$vegetarian, vegan=$vegan)';
}

typedef RecipePersonalizationResult = ({
  List<Recipe> recipes,
  int personalizedHits,
  RecipePersonalizationPrefs prefs,
  String source, // local_file | shared_prefs | default
});

class RecipePersonalizationService {
  RecipePersonalizationService._();
  static final RecipePersonalizationService instance = RecipePersonalizationService._();

  final _storage = CustomerStorage.instance;

  // In-memory cache so screens don't hit disk repeatedly.
  final Map<String, ({RecipePersonalizationPrefs prefs, String source})> _prefsCache = {};

  Future<({RecipePersonalizationPrefs prefs, String source})> loadPrefsForUid(String uid) async {
    final cached = _prefsCache[uid];
    if (cached != null) return cached;

    // If we have local saved preferences tied to the current uid, prefer those.
    try {
      final store = CustomerDataStore.instance;
      final profile = await store.loadProfile();
      if (profile != null && profile.userId == uid) {
        final p = await store.loadPreferences();
        final pref = RecipePersonalizationPrefs(
          vegetarian: p.diet == CustomerDiet.vegetarian,
          vegan: p.diet == CustomerDiet.vegan,
        );
        final out = (prefs: pref, source: 'customer_preferences');
        _prefsCache[uid] = out;
        return out;
      }
    } catch (_) {
      // ignore
    }

    // Primary: dates_from_costumors/<uid>.json (created by Firestore export).
    try {
      final json = await _storage.readJson('$uid.json');
      final pref = _parsePrefs(json);
      final out = (prefs: pref, source: 'local_file');
      _prefsCache[uid] = out;
      return out;
    } catch (_) {
      // ignore
    }

    // Fallback: SharedPreferences export string (export_user_<uid>).
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('export_user_$uid');
      if (raw != null && raw.isNotEmpty) {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic>) {
          final pref = _parsePrefs(decoded);
          final out = (prefs: pref, source: 'shared_prefs');
          _prefsCache[uid] = out;
          return out;
        }
      }
    } catch (_) {
      // ignore
    }

    final out = (prefs: RecipePersonalizationPrefs.none, source: 'default');
    _prefsCache[uid] = out;
    return out;
  }

  RecipePersonalizationPrefs _parsePrefs(Map<String, dynamic>? json) {
    final p = (json?['preferences'] is Map) ? (json!['preferences'] as Map).cast<String, dynamic>() : null;
    final vegetarian = p?['vegetarian'] == true;
    final vegan = p?['vegan'] == true;
    return RecipePersonalizationPrefs(vegetarian: vegetarian, vegan: vegan);
  }

  bool isVegan(Recipe r) {
    final labels = <String>[
      ...(r.categories ?? const <String>[]),
      ...(r.tags ?? const <String>[]),
    ].map((s) => s.toLowerCase().trim()).toList();
    return labels.any((s) => s.contains('vegan'));
  }

  bool isVegetarianOrVegan(Recipe r) {
    if (isVegan(r)) return true;
    final labels = <String>[
      ...(r.categories ?? const <String>[]),
      ...(r.tags ?? const <String>[]),
    ].map((s) => s.toLowerCase().trim()).toList();
    return labels.any((s) => s.contains('vegetar') || s.contains('vegetarian'));
  }

  /// Stable personalization: we only re-order by a single preference-priority key,
  /// keeping the previous order inside each bucket (stable).
  RecipePersonalizationResult personalize({
    required List<Recipe> recipes,
    required RecipePersonalizationPrefs prefs,
    required String source,
  }) {
    if (!prefs.vegan && !prefs.vegetarian) {
      return (recipes: recipes, personalizedHits: 0, prefs: prefs, source: source);
    }

    bool matches(Recipe r) {
      if (prefs.vegan) return isVegan(r);
      if (prefs.vegetarian) return isVegetarianOrVegan(r);
      return false;
    }

    final prioritized = <Recipe>[];
    final rest = <Recipe>[];
    for (final r in recipes) {
      (matches(r) ? prioritized : rest).add(r);
    }

    final out = <Recipe>[...prioritized, ...rest];
    final hits = prioritized.length;

    if (kDebugMode) {
      debugPrint(
        '🧠 RecipePersonalization: prefs(vegan=${prefs.vegan}, vegetarian=${prefs.vegetarian}) '
        'hits=$hits/${recipes.length} source=$source',
      );
    }

    return (recipes: out, personalizedHits: hits, prefs: prefs, source: source);
  }
}


