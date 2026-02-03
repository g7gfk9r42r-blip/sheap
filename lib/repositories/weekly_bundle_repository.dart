import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/weekly_bundle.dart';

/// Repository zum Laden von WeeklyBundle aus Assets
class WeeklyBundleRepository {
  /// Lädt WeeklyBundle aus Asset-Datei
  /// 
  /// [assetPath] Beispiel: "recipes/recipes_aldi_sued_2026-W01.json"
  static Future<WeeklyBundle> loadWeeklyBundle({
    required String assetPath,
  }) async {
    try {
      final String jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      return WeeklyBundle.fromJson(jsonData);
    } catch (e) {
      throw Exception('Failed to load weekly bundle from $assetPath: $e');
    }
  }

  /// Generiert Asset-Pfad aus Supermarkt und Week-Key
  /// 
  /// Beispiel: supermarket="aldi_sued", weekKey="2026-W01"
  /// -> "recipes/recipes_aldi_sued_2026-W01.json"
  static String getAssetPath({
    required String supermarket,
    required String weekKey,
  }) {
    return 'recipes/recipes_${supermarket}_$weekKey.json';
  }
}

