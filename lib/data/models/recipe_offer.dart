import 'package:flutter/foundation.dart';

/// RecipeOfferUsed: Offer-Objekt in recipes.offers_used
/// Struktur entspricht dem JSON-Format: offer_id, exact_name, brand, unit, price_eur, uvp_eur, price_before_eur
@immutable
class RecipeOfferUsed {
  final String offerId;
  final String exactName;
  final String? brand;
  final String unit;
  final double priceEur;
  final double? uvpEur;
  final double? priceBeforeEur;
  final double? quantity; // Menge der Zutat

  const RecipeOfferUsed({
    required this.offerId,
    required this.exactName,
    this.brand,
    required this.unit,
    required this.priceEur,
    this.uvpEur,
    this.priceBeforeEur,
    this.quantity,
  });

  factory RecipeOfferUsed.fromJson(Map<String, dynamic> json) {
    // Robust parsing: accept int/double/string for prices
    // Support both 'price_eur' and 'price' as snake_case keys
    final priceEurValue = json['price_eur'] ?? json['price'];
    double priceEurParsed;
    if (priceEurValue is num) {
      priceEurParsed = priceEurValue.toDouble();
    } else if (priceEurValue is String) {
      priceEurParsed = double.tryParse(priceEurValue) ?? 0.0;
    } else {
      priceEurParsed = 0.0;
    }

    final uvpEurValue = json['uvp_eur'];
    double? uvpEurParsed;
    if (uvpEurValue != null) {
      if (uvpEurValue is num) {
        uvpEurParsed = uvpEurValue.toDouble();
      } else if (uvpEurValue is String) {
        uvpEurParsed = double.tryParse(uvpEurValue);
      }
    }

    // Support both 'price_before_eur' and 'price_before'
    final priceBeforeEurValue = json['price_before_eur'] ?? json['price_before'];
    double? priceBeforeEurParsed;
    if (priceBeforeEurValue != null) {
      if (priceBeforeEurValue is num) {
        priceBeforeEurParsed = priceBeforeEurValue.toDouble();
      } else if (priceBeforeEurValue is String) {
        priceBeforeEurParsed = double.tryParse(priceBeforeEurValue);
      }
    }

    // Support 'exact_name', 'exactName', 'offer_product', 'product', 'name'
    final exactName = json['exact_name']?.toString() ?? 
                      json['exactName']?.toString() ?? 
                      json['offer_product']?.toString() ??
                      json['product']?.toString() ??
                      json['name']?.toString() ?? 
                      '';

    // Support 'offer_id' and 'offerId'
    final offerId = json['offer_id']?.toString() ?? 
                    json['offerId']?.toString() ?? 
                    '';

    // Parse quantity (kann num oder String sein)
    double? quantityParsed;
    final quantityValue = json['quantity'];
    if (quantityValue != null) {
      if (quantityValue is num) {
        quantityParsed = quantityValue.toDouble();
      } else if (quantityValue is String) {
        quantityParsed = double.tryParse(quantityValue);
      }
    }

    return RecipeOfferUsed(
      offerId: offerId,
      exactName: exactName,
      brand: json['brand']?.toString(),
      unit: json['unit']?.toString() ?? '',
      priceEur: priceEurParsed,
      uvpEur: uvpEurParsed,
      priceBeforeEur: priceBeforeEurParsed,
      quantity: quantityParsed,
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
      if (quantity != null) 'quantity': quantity,
    };
  }

  /// Berechnet Ersparnis-Prozent, falls möglich
  double? get savingsPercent {
    final referencePrice = priceBeforeEur ?? uvpEur;
    if (referencePrice != null && referencePrice > priceEur && referencePrice > 0) {
      return ((referencePrice - priceEur) / referencePrice) * 100;
    }
    return null;
  }

  /// Prüft ob Ersparnis vorhanden ist
  bool get hasSavings {
    final referencePrice = priceBeforeEur ?? uvpEur;
    return referencePrice != null && referencePrice > priceEur;
  }
}