enum CustomerDiet {
  none,
  vegetarian,
  vegan,
  lowCarb,
  highProtein,
  glutenFree,
  lactoseFree,
  calorieLow,
  calorieHigh,
}

extension CustomerDietX on CustomerDiet {
  String get key {
    switch (this) {
      case CustomerDiet.none:
        return 'none';
      case CustomerDiet.vegetarian:
        return 'vegetarian';
      case CustomerDiet.vegan:
        return 'vegan';
      case CustomerDiet.lowCarb:
        return 'low_carb';
      case CustomerDiet.highProtein:
        return 'high_protein';
      case CustomerDiet.glutenFree:
        return 'gluten_free';
      case CustomerDiet.lactoseFree:
        return 'lactose_free';
      case CustomerDiet.calorieLow:
        return 'calorie_low';
      case CustomerDiet.calorieHigh:
        return 'calorie_high';
    }
  }

  static CustomerDiet fromString(String raw) {
    final s = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    switch (s) {
      case 'vegetarian':
      case 'vegetarisch':
        return CustomerDiet.vegetarian;
      case 'vegan':
        return CustomerDiet.vegan;
      case 'lowcarb':
      case 'low_carb':
        return CustomerDiet.lowCarb;
      case 'highprotein':
      case 'high_protein':
        return CustomerDiet.highProtein;
      case 'glutenfree':
      case 'gluten_free':
      case 'glutenfrei':
        return CustomerDiet.glutenFree;
      case 'lactosefree':
      case 'lactose_free':
      case 'laktosefrei':
        return CustomerDiet.lactoseFree;
      case 'calorie_low':
      case 'kalorienarm':
        return CustomerDiet.calorieLow;
      case 'calorie_high':
      case 'high_calorie':
      case 'highcalorie':
        return CustomerDiet.calorieHigh;
      case 'none':
      default:
        return CustomerDiet.none;
    }
  }
}

class CustomerPreferences {
  final CustomerDiet diet;
  /// High-level user goal (e.g. "lose_weight", "maintain_weight", "gain_weight").
  /// Optional + backward compatible.
  final String? primaryGoal;
  final List<String> dislikedIngredients;
  final List<String> allergens;
  final int? calorieGoal;
  final String language; // e.g. de/en
  final bool personalizationEnabled;

  const CustomerPreferences({
    required this.diet,
    required this.primaryGoal,
    required this.dislikedIngredients,
    required this.allergens,
    required this.calorieGoal,
    required this.language,
    required this.personalizationEnabled,
  });

  factory CustomerPreferences.defaults() => const CustomerPreferences(
        diet: CustomerDiet.none,
        primaryGoal: null,
        dislikedIngredients: [],
        allergens: [],
        calorieGoal: null,
        language: 'de',
        personalizationEnabled: true,
      );

  Map<String, dynamic> toJson() => {
        'diet': diet.key,
        'primaryGoal': primaryGoal,
        'dislikedIngredients': dislikedIngredients,
        'allergens': allergens,
        'calorieGoal': calorieGoal,
        'language': language,
        'personalizationEnabled': personalizationEnabled,
      };

  factory CustomerPreferences.fromJson(Map<String, dynamic> json) {
    return CustomerPreferences(
      diet: CustomerDietX.fromString(json['diet']?.toString() ?? 'none'),
      primaryGoal: json['primaryGoal']?.toString(),
      dislikedIngredients: (json['dislikedIngredients'] is List)
          ? (json['dislikedIngredients'] as List).map((e) => e.toString()).toList()
          : const [],
      allergens: (json['allergens'] is List)
          ? (json['allergens'] as List).map((e) => e.toString()).toList()
          : const [],
      calorieGoal: (json['calorieGoal'] as num?)?.toInt(),
      language: json['language']?.toString() ?? 'de',
      personalizationEnabled: json['personalizationEnabled'] as bool? ?? true,
    );
  }
}


