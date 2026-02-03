import 'package:flutter/foundation.dart';

/// WeeklyBundle: Root-Modell für Supermarkt-Wochen-Angebote und Rezepte
@immutable
class WeeklyBundle {
  final String supermarket;
  final Validity validity;
  final String currency;
  final List<Offer> offersCatalog;
  final List<WeeklyRecipe> recipes;

  const WeeklyBundle({
    required this.supermarket,
    required this.validity,
    required this.currency,
    required this.offersCatalog,
    required this.recipes,
  });

  factory WeeklyBundle.fromJson(Map<String, dynamic> json) {
    return WeeklyBundle(
      supermarket: json['supermarket'] as String,
      validity: Validity.fromJson(json['validity'] as Map<String, dynamic>),
      currency: json['currency'] as String,
      offersCatalog: (json['offers_catalog'] as List)
          .map((e) => Offer.fromJson(e as Map<String, dynamic>))
          .toList(),
      recipes: (json['recipes'] as List)
          .map((e) => WeeklyRecipe.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supermarket': supermarket,
      'validity': validity.toJson(),
      'currency': currency,
      'offers_catalog': offersCatalog.map((e) => e.toJson()).toList(),
      'recipes': recipes.map((e) => e.toJson()).toList(),
    };
  }
}

/// Validity: Gültigkeitszeitraum
@immutable
class Validity {
  final DateTime from;
  final DateTime to;

  const Validity({
    required this.from,
    required this.to,
  });

  factory Validity.fromJson(Map<String, dynamic> json) {
    return Validity(
      from: DateTime.parse(json['from'] as String),
      to: DateTime.parse(json['to'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
      'to': '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}',
    };
  }
}

/// Offer: Angebot aus dem Katalog
@immutable
class Offer {
  final String offerId;
  final String exactName;
  final String? brand;
  final String unit;
  final double priceEur;
  final double? uvpEur;
  final double? priceBeforeEur;

  const Offer({
    required this.offerId,
    required this.exactName,
    this.brand,
    required this.unit,
    required this.priceEur,
    this.uvpEur,
    this.priceBeforeEur,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      offerId: json['offer_id'] as String,
      exactName: json['exact_name'] as String,
      brand: json['brand'] as String?,
      unit: json['unit'] as String,
      priceEur: (json['price_eur'] as num).toDouble(),
      uvpEur: json['uvp_eur'] != null ? (json['uvp_eur'] as num).toDouble() : null,
      priceBeforeEur: json['price_before_eur'] != null ? (json['price_before_eur'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offer_id': offerId,
      'exact_name': exactName,
      if (brand != null) 'brand': brand,
      'unit': unit,
      'price_eur': priceEur,
      if (uvpEur != null) 'uvp_eur': uvpEur,
      if (priceBeforeEur != null) 'price_before_eur': priceBeforeEur,
    };
  }
}

/// RecipeOfferUsed: Identisch zu Offer, wird in recipes.offers_used verwendet
typedef RecipeOfferUsed = Offer;

/// Ingredient: Zutat eines Rezepts
@immutable
class Ingredient {
  final String name;
  final double? quantity;
  final String? unit;
  final bool fromOffer;
  final String? offerId;
  final String? note;

  const Ingredient({
    required this.name,
    this.quantity,
    this.unit,
    required this.fromOffer,
    this.offerId,
    this.note,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String,
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit'] as String?,
      fromOffer: json['from_offer'] as bool,
      offerId: json['offer_id'] as String?,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      'from_offer': fromOffer,
      if (offerId != null) 'offer_id': offerId,
      if (note != null) 'note': note,
    };
  }
}

/// WeeklyRecipe: Rezept aus dem WeeklyBundle
@immutable
class WeeklyRecipe {
  final String id;
  final String title;
  final int servings;
  final int prepMinutes;
  final int cookMinutes;
  final List<String> tags;
  final List<RecipeOfferUsed> offersUsed;
  final List<Ingredient> ingredients;
  final List<String> steps;

  const WeeklyRecipe({
    required this.id,
    required this.title,
    required this.servings,
    required this.prepMinutes,
    required this.cookMinutes,
    required this.tags,
    required this.offersUsed,
    required this.ingredients,
    required this.steps,
  });

  factory WeeklyRecipe.fromJson(Map<String, dynamic> json) {
    return WeeklyRecipe(
      id: json['id'] as String,
      title: json['title'] as String,
      servings: (json['servings'] as num).toInt(),
      prepMinutes: (json['prep_minutes'] as num).toInt(),
      cookMinutes: (json['cook_minutes'] as num).toInt(),
      tags: (json['tags'] as List).map((e) => e.toString()).toList(),
      offersUsed: (json['offers_used'] as List)
          .map((e) => Offer.fromJson(e as Map<String, dynamic>))
          .toList(),
      ingredients: (json['ingredients'] as List)
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List).map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'servings': servings,
      'prep_minutes': prepMinutes,
      'cook_minutes': cookMinutes,
      'tags': tags,
      'offers_used': offersUsed.map((e) => e.toJson()).toList(),
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'steps': steps,
    };
  }

  int get totalMinutes => prepMinutes + cookMinutes;
}

