/// Price Tier: Standardpreis oder Loyalty-Preis
class PriceTier {
  final double price;
  final String? condition; // z.B. "Mit K-Card", "Mit REWE Bonus", "Mit App"
  final String? conditionType; // "card", "bonus", "app", null für Standard

  const PriceTier({
    required this.price,
    this.condition,
    this.conditionType,
  });

  bool get isLoyalty => condition != null && conditionType != null;
  bool get isStandard => !isLoyalty;

  Map<String, dynamic> toJson() {
    return {
      'price': price,
      if (condition != null) 'condition': condition,
      if (conditionType != null) 'conditionType': conditionType,
    };
  }

  factory PriceTier.fromJson(Map<String, dynamic> json) {
    return PriceTier(
      price: (json['price'] as num).toDouble(),
      condition: json['condition'] as String?,
      conditionType: json['conditionType'] as String?,
    );
  }
}

/// Condition: Welche Karte/Bonus/App wird benötigt
class Condition {
  final String type; // "card", "bonus", "app"
  final String label; // "K-Card", "REWE Bonus", "App"
  final String? retailer; // Optional: spezifischer Retailer

  const Condition({
    required this.type,
    required this.label,
    this.retailer,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'label': label,
      if (retailer != null) 'retailer': retailer,
    };
  }

  factory Condition.fromJson(Map<String, dynamic> json) {
    return Condition(
      type: json['type'] as String,
      label: json['label'] as String,
      retailer: json['retailer'] as String?,
    );
  }
}

class Offer {
  final String id;
  final String retailer; // REWE | EDEKA | LIDL | ALDI | NETTO
  final String title;
  final double price; // Standardpreis (für Rückwärtskompatibilität)
  final String? unit;
  final DateTime validFrom;
  final DateTime validTo;
  final String? imageUrl;
  final DateTime updatedAt;
  
  // Extended fields
  final String? brand;
  final double? originalPrice; // UVP/Referenzpreis
  final PriceTier? standardPrice; // Standardpreis (explizit)
  final PriceTier? loyaltyPrice; // Loyalty-Preis (mit Karte/Bonus/App)
  final Condition? condition; // Welche Bedingung für Loyalty-Preis
  final double? confidence; // 0.0 - 1.0, für low-confidence Flag
  final List<String>? warnings; // Validierungswarnungen

  const Offer({
    required this.id,
    required this.retailer,
    required this.title,
    required this.price,
    this.unit,
    required this.validFrom,
    required this.validTo,
    this.imageUrl,
    required this.updatedAt,
    this.brand,
    this.originalPrice,
    this.standardPrice,
    this.loyaltyPrice,
    this.condition,
    this.confidence,
    this.warnings,
  });

  /// Gibt den Standardpreis zurück (priorisiert standardPrice, dann price)
  double get standardPriceValue => standardPrice?.price ?? price;
  
  /// Gibt den Loyalty-Preis zurück, falls vorhanden
  double? get loyaltyPriceValue => loyaltyPrice?.price;
  
  /// Prüft ob ein Loyalty-Preis vorhanden ist
  bool get hasLoyaltyPrice => loyaltyPrice != null;
  
  /// Prüft ob nur ein Loyalty-Preis vorhanden ist (kein Standardpreis)
  bool get hasOnlyLoyaltyPrice => loyaltyPrice != null && standardPrice == null && price == 0.0;
  
  /// Prüft ob low confidence (unter 0.7)
  bool get isLowConfidence => (confidence ?? 1.0) < 0.7;

  factory Offer.fromJson(Map<String, dynamic> json) {
    // Parse PriceTier falls vorhanden
    PriceTier? standardPrice;
    PriceTier? loyaltyPrice;
    if (json['standardPrice'] != null) {
      standardPrice = PriceTier.fromJson(json['standardPrice'] as Map<String, dynamic>);
    }
    if (json['loyaltyPrice'] != null) {
      loyaltyPrice = PriceTier.fromJson(json['loyaltyPrice'] as Map<String, dynamic>);
    }
    
    // Parse Condition falls vorhanden
    Condition? condition;
    if (json['condition'] != null) {
      condition = Condition.fromJson(json['condition'] as Map<String, dynamic>);
    }
    
    // Parse warnings
    List<String>? warnings;
    if (json['warnings'] != null) {
      warnings = (json['warnings'] as List).map((e) => e.toString()).toList();
    }

    return Offer(
      id: json['id'] as String,
      retailer: json['retailer'] as String,
      title: json['title'] as String,
      price: (json['price'] as num).toDouble(),
      unit: json['unit'] as String?,
      validFrom: DateTime.parse(json['validFrom'] as String),
      validTo: DateTime.parse(json['validTo'] as String),
      imageUrl: json['imageUrl'] as String?,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      brand: json['brand'] as String?,
      originalPrice: json['originalPrice'] != null ? (json['originalPrice'] as num).toDouble() : null,
      standardPrice: standardPrice,
      loyaltyPrice: loyaltyPrice,
      condition: condition,
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : null,
      warnings: warnings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'retailer': retailer,
      'title': title,
      'price': price,
      if (unit != null) 'unit': unit,
      'validFrom': validFrom.toIso8601String(),
      'validTo': validTo.toIso8601String(),
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': updatedAt.toIso8601String(),
      if (brand != null) 'brand': brand,
      if (originalPrice != null) 'originalPrice': originalPrice,
      if (standardPrice != null) 'standardPrice': standardPrice!.toJson(),
      if (loyaltyPrice != null) 'loyaltyPrice': loyaltyPrice!.toJson(),
      if (condition != null) 'condition': condition!.toJson(),
      if (confidence != null) 'confidence': confidence,
      if (warnings != null) 'warnings': warnings,
    };
  }
}


