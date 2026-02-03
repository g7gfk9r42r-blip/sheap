/// Shopping List Service - Globaler Store für die Einkaufsliste
import 'package:flutter/foundation.dart';
import '../models/offer.dart';
import '../models/recipe_offer.dart';

class ShoppingListItem {
  final String name;
  final String? amount;
  final bool checked;
  final Offer? offer; // Enthält Marke, Preis, etc.
  final String? category;
  final String? market; // Canonical market key (z.B. "lidl", "nahkauf")
  
  // Detaillierte Informationen aus JSON
  final String? brand;
  final double? quantity;
  final String? unit;
  final double? price;
  final double? priceBefore;
  final String? currency;
  final String? note;
  final String? offerId; // ID des Angebots
  final bool? fromOffer; // Ob die Zutat von einem Angebot stammt
  final bool? isBaseIngredient; // Basiszutat (z.B. Salz, Pfeffer, Öl)
  final bool? isWithoutOffer; // Explicitly from recipe.without_offers
  final String? sourceRecipeId;
  final String? sourceRecipeTitle;
  final String? rawIngredient; // Original Ingredient-String aus Rezept
  
  ShoppingListItem({
    required this.name,
    this.amount,
    this.checked = false,
    this.offer,
    this.category,
    this.market,
    this.brand,
    this.quantity,
    this.unit,
    this.price,
    this.priceBefore,
    this.currency,
    this.note,
    this.offerId,
    this.fromOffer,
    this.isBaseIngredient,
    this.isWithoutOffer,
    this.sourceRecipeId,
    this.sourceRecipeTitle,
    this.rawIngredient,
  });
  
  ShoppingListItem copyWith({
    String? name,
    String? amount,
    bool? checked,
    Offer? offer,
    String? category,
    String? market,
    String? brand,
    double? quantity,
    String? unit,
    double? price,
    double? priceBefore,
    String? currency,
    String? note,
    String? offerId,
    bool? fromOffer,
    bool? isBaseIngredient,
    bool? isWithoutOffer,
    String? sourceRecipeId,
    String? sourceRecipeTitle,
    String? rawIngredient,
  }) {
    return ShoppingListItem(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      checked: checked ?? this.checked,
      offer: offer ?? this.offer,
      category: category ?? this.category,
      market: market ?? this.market,
      brand: brand ?? this.brand,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      priceBefore: priceBefore ?? this.priceBefore,
      currency: currency ?? this.currency,
      note: note ?? this.note,
      offerId: offerId ?? this.offerId,
      fromOffer: fromOffer ?? this.fromOffer,
      isBaseIngredient: isBaseIngredient ?? this.isBaseIngredient,
      isWithoutOffer: isWithoutOffer ?? this.isWithoutOffer,
      sourceRecipeId: sourceRecipeId ?? this.sourceRecipeId,
      sourceRecipeTitle: sourceRecipeTitle ?? this.sourceRecipeTitle,
      rawIngredient: rawIngredient ?? this.rawIngredient,
    );
  }

  /// Erstellt ein ShoppingListItem aus einem Ingredient (RecipeOfferUsed)
  factory ShoppingListItem.fromIngredient(
    String name,
    RecipeOfferUsed? offerUsed, {
    String? amount,
    Offer? offer,
    String? market,
    bool? isBaseIngredient,
    String? sourceRecipeId,
    String? sourceRecipeTitle,
    String? rawIngredient,
    String? note,
    bool? isWithoutOffer,
  }) {
    return ShoppingListItem(
      name: name,
      amount: amount,
      offer: offer,
      market: market,
      brand: offerUsed?.brand,
      unit: offerUsed?.unit,
      price: offerUsed?.priceEur,
      priceBefore: offerUsed?.priceBeforeEur ?? offerUsed?.uvpEur,
      currency: 'EUR',
      note: note,
      offerId: offerUsed?.offerId.isNotEmpty == true ? offerUsed!.offerId : null,
      fromOffer: offerUsed != null,
      isBaseIngredient: isBaseIngredient,
      isWithoutOffer: isWithoutOffer,
      sourceRecipeId: sourceRecipeId,
      sourceRecipeTitle: sourceRecipeTitle,
      rawIngredient: rawIngredient,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (amount != null) 'amount': amount,
      'checked': checked,
      if (category != null) 'category': category,
      if (market != null) 'market': market,
      if (brand != null) 'brand': brand,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (price != null) 'price': price,
      if (priceBefore != null) 'priceBefore': priceBefore,
      if (currency != null) 'currency': currency,
      if (note != null) 'note': note,
      if (offerId != null) 'offerId': offerId,
      if (fromOffer != null) 'fromOffer': fromOffer,
      if (isBaseIngredient != null) 'isBaseIngredient': isBaseIngredient,
      if (isWithoutOffer != null) 'isWithoutOffer': isWithoutOffer,
      if (sourceRecipeId != null) 'sourceRecipeId': sourceRecipeId,
      if (sourceRecipeTitle != null) 'sourceRecipeTitle': sourceRecipeTitle,
      if (rawIngredient != null) 'rawIngredient': rawIngredient,
      // Note: offer is not serialized as it's a complex object
    };
  }

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      name: json['name']?.toString() ?? '',
      amount: json['amount']?.toString(),
      checked: json['checked'] as bool? ?? false,
      category: json['category']?.toString(),
      market: json['market']?.toString(),
      brand: json['brand']?.toString(),
      quantity: json['quantity'] != null ? (json['quantity'] as num).toDouble() : null,
      unit: json['unit']?.toString(),
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      priceBefore: json['priceBefore'] != null ? (json['priceBefore'] as num).toDouble() : null,
      currency: json['currency']?.toString(),
      note: json['note']?.toString(),
      offerId: json['offerId']?.toString(),
      fromOffer: json['fromOffer'] as bool?,
      isBaseIngredient: json['isBaseIngredient'] as bool?,
      isWithoutOffer: json['isWithoutOffer'] as bool?,
      sourceRecipeId: json['sourceRecipeId']?.toString(),
      sourceRecipeTitle: json['sourceRecipeTitle']?.toString(),
      rawIngredient: json['rawIngredient']?.toString(),
      // Note: offer needs to be reconstructed separately if needed
    );
  }
}

class ShoppingListService extends ChangeNotifier {
  ShoppingListService._();
  static final ShoppingListService instance = ShoppingListService._();
  
  final List<ShoppingListItem> _items = [];
  
  List<ShoppingListItem> get items => List.unmodifiable(_items);
  
  int get uncheckedCount => _items.where((item) => !item.checked).length;
  int get totalCount => _items.length;
  
  void addItem(ShoppingListItem item) {
    // Auto-categorize if not set
    if (item.category == null) {
      final categorizedItem = item.copyWith(
        category: _categorizeItem(item.name),
      );
      _items.add(categorizedItem);
    } else {
      _items.add(item);
    }
    notifyListeners();
  }
  
  void addItems(List<ShoppingListItem> items) {
    // Auto-categorize all items
    for (final item in items) {
      if (item.category == null) {
        _items.add(item.copyWith(category: _categorizeItem(item.name)));
      } else {
        _items.add(item);
      }
    }
    notifyListeners();
  }
  
  /// Categorize item by name
  String _categorizeItem(String name) {
    // Import categorizer dynamically to avoid circular dependency
    try {
      // Simple categorization inline (can be moved to utility class)
      final lower = name.toLowerCase();
      
      if (_matches(lower, ['apfel', 'banane', 'orange', 'erdbeere', 'traube', 'beere', 'birne', 'pfirsich', 'kiwi', 'mango', 'ananas', 'zitrone', 'limette', 'avocado', 'weintraube', 'kirsche', 'pflaume', 'nektarine', 'melone', 'wassermelone'])) {
        return 'Obst';
      }
      if (_matches(lower, ['tomate', 'gurke', 'paprika', 'karotte', 'möhre', 'zwiebel', 'knoblauch', 'salat', 'spinat', 'brokkoli', 'blumenkohl', 'kohl', 'kartoffel', 'zucchini', 'aubergine', 'pilz', 'champignon', 'lauch', 'sellerie'])) {
        return 'Gemüse';
      }
      if (_matches(lower, ['brot', 'brötchen', 'semmel', 'croissant', 'toast', 'baguette', 'vollkornbrot', 'weizen', 'dinkel'])) {
        return 'Brot & Backwaren';
      }
      if (_matches(lower, ['milch', 'joghurt', 'quark', 'sahne', 'butter', 'margarine', 'käse', 'mozzarella', 'gouda', 'cheddar', 'feta', 'ricotta', 'schmand'])) {
        return 'Milchprodukte';
      }
      if (_matches(lower, ['fleisch', 'hähnchen', 'huhn', 'hackfleisch', 'rind', 'schwein', 'steak', 'schnitzel', 'wurst', 'salami', 'schinken', 'speck', 'lachs', 'fisch', 'thunfisch', 'garnelen'])) {
        return 'Fleisch & Fisch';
      }
      if (_matches(lower, ['tiefkühl', 'tiefkühlgemüse', 'eis', 'frozen', 'fischstäbchen', 'pommes', 'pizza'])) {
        return 'Tiefkühl';
      }
      if (_matches(lower, ['wasser', 'saft', 'cola', 'limo', 'bier', 'wein', 'sprudel', 'getränk', 'smoothie', 'tee', 'kaffee'])) {
        return 'Getränke';
      }
      if (_matches(lower, ['nudel', 'pasta', 'reis', 'mehl', 'zucker', 'salz', 'pfeffer', 'öl', 'essig', 'brühe', 'tomatenmark', 'dose', 'konserve', 'haferflocken', 'müsli'])) {
        return 'Grundnahrungsmittel';
      }
      if (_matches(lower, ['schokolade', 'kekse', 'chips', 'nüsse', 'mandeln', 'walnüsse', 'popcorn', 'cracker', 'keks'])) {
        return 'Snacks & Süßigkeiten';
      }
      if (_matches(lower, ['basilikum', 'petersilie', 'schnittlauch', 'oregano', 'thymian', 'rosmarin', 'curry', 'paprika', 'chili', 'zimt', 'vanille', 'gewürz', 'kräuter'])) {
        return 'Gewürze & Kräuter';
      }
    } catch (e) {
      // Fallback
    }
    return 'Sonstiges';
  }
  
  bool _matches(String name, List<String> keywords) {
    return keywords.any((keyword) => name.contains(keyword));
  }
  
  void toggleItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index] = _items[index].copyWith(checked: !_items[index].checked);
      notifyListeners();
    }
  }
  
  void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }
  
  void clear() {
    _items.clear();
    notifyListeners();
  }
}

