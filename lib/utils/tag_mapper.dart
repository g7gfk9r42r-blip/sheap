/// Tag/Hashtag Mapper für diet_categories
/// Mappt deutsche Kategorien zu konsistenten Hashtags
class TagMapper {
  static const Map<String, String> _tagMapping = {
    // Vegan/Vegetarisch (höchste Priorität)
    'vegan': '#Vegan',
    'vegetarisch': '#Vegetarian',
    
    // Protein/Carb (hohe Priorität)
    'high protein': '#HighProtein',
    'highprotein': '#HighProtein',
    'low carb': '#LowCarb',
    'lowcarb': '#LowCarb',
    
    // Kalorien (mittlere Priorität)
    'kalorienreich': '#HighCalorie',
    'kalorienarm': '#LowCalorie',
    'high calorie': '#HighCalorie',
    'low calorie': '#LowCalorie',
    
    // Allergene (niedrige Priorität)
    'gluten-free': '#GlutenFree',
    'glutenfrei': '#GlutenFree',
    'laktosefrei': '#LactoseFree',
    'lactose free': '#LactoseFree',
  };

  /// Mappt eine Kategorie zu einem Hashtag
  static String? mapToHashtag(String category) {
    final normalized = category.toLowerCase().trim();
    return _tagMapping[normalized] ?? (category.startsWith('#') ? category : '#$category');
  }

  /// Sortiert Tags nach Priorität und gibt max 3 zurück
  /// Priorität: Vegan/Vegetarisch > HighProtein/LowCarb > Low/HighCalorie > Gluten/Lactose
  static List<String> getTopTags(List<String> categories) {
    if (categories.isEmpty) return [];
    
    // Mappe alle Tags
    final mappedTags = categories.map((c) => mapToHashtag(c)).whereType<String>().toSet().toList();
    
    // Sortiere nach Priorität
    final priority = <String, int>{
      '#Vegan': 1,
      '#Vegetarian': 2,
      '#HighProtein': 3,
      '#LowCarb': 4,
      '#LowCalorie': 5,
      '#HighCalorie': 6,
      '#GlutenFree': 7,
      '#LactoseFree': 8,
    };
    
    mappedTags.sort((a, b) {
      final prioA = priority[a] ?? 99;
      final prioB = priority[b] ?? 99;
      return prioA.compareTo(prioB);
    });
    
    // Gib max 3 zurück
    return mappedTags.take(3).toList();
  }
}
