/// Zentrale Funktion für Recipe Image Asset-Pfade
/// 
/// Generiert den Asset-Pfad für Recipe-Bilder basierend auf Markt und Recipe-ID.
/// Format: assets/images/recipes/<market>_<recipeId>.png
/// 
/// Beispiel:
///   recipeImageAssetPath(market: 'rewe', recipeId: 'R001')
///   → 'assets/images/recipes/rewe_R001.png'

String recipeImageAssetPath({
  required String market,
  required String recipeId, // z.B. "R001"
}) {
  final m = market.toLowerCase().trim();
  final id = recipeId.toUpperCase().trim();
  
  // Aktuelles Naming: assets/images/recipes/<market>_<id>.png
  return 'assets/images/recipes/${m}_${id}.png';
}

