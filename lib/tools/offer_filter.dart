/// OfferFilter
/// Filtert Angebote nach Lebensmittel vs. Nicht-Lebensmittel.
/// 
/// Kategorien, die als Lebensmittel gelten:
/// - Obst & Gemüse
/// - Fleisch & Fisch
/// - Milchprodukte
/// - Gekühlte & tiefgekühlte Produkte
/// - Haltbare Produkte (Nudeln, Konserven, etc.)
/// - Snacks & Süßes
/// - Getränke
/// - Backwaren
/// 
/// Kategorien, die NICHT als Lebensmittel gelten:
/// - Kleidung / Mode
/// - Spielzeug
/// - Heimwerken / Werkzeuge
/// - Pflanzen
/// - Kosmetik / Drogerie
/// - Haushalt (außer Lebensmittel)
/// - Elektronik
/// - Möbel

import '../data/models/offer.dart';

class OfferFilter {
  /// Liste von Kategorien, die als Lebensmittel gelten
  static const Set<String> _foodCategories = {
    'Obst & Gemüse',
    'Fleisch & Fisch',
    'Milchprodukte',
    'Gekühlte & tiefgekühlte Produkte',
    'Haltbare Produkte',
    'Snacks & Süßes',
    'Getränke',
    'Backwaren',
    'Gourmet – Kühl & TK',
    'Gourmet – Haltbar',
    'Frische-Angebote',
    'Wochen-Angebote',
    'XXL-Aktion', // Kann Lebensmittel enthalten, wird weiter gefiltert
  };

  /// Liste von Kategorien, die NICHT als Lebensmittel gelten
  static const Set<String> _nonFoodCategories = {
    'Wintermode',
    'Damenmode',
    'Kindermode',
    'Spielzeug',
    'Heimwerken',
    'Pflanzen',
    'Kosmetik',
    'Haushalt',
    'Küche', // Küchengeräte, nicht Lebensmittel
    'Elektronik',
    'Möbel',
    'Gesundheit', // Medikamente, nicht Lebensmittel
    'Christbaumschmuck',
    'Weihnachtsdeko',
  };

  /// Keywords, die auf Nicht-Lebensmittel hinweisen (im Titel)
  static const Set<String> _nonFoodKeywords = {
    't-shirt',
    'shirt',
    'hose',
    'jacke',
    'pullover',
    'schuhe',
    'stiefel',
    'handschuhe',
    'mütze',
    'spielzeug',
    'puzzle',
    'bausatz',
    'werkzeug',
    'bohrer',
    'schraube',
    'nagel',
    'pflanze',
    'blume',
    'topf',
    'erde',
    'dünger',
    'shampoo',
    'duschgel',
    'creme',
    'make-up',
    'lippenstift',
    'waschmittel',
    'spülmittel',
    'tücher',
    'möbel',
    'stuhl',
    'tisch',
    'lampe',
    'elektronik',
    'tablet',
    'handy',
    'kamera',
    'weihnachtsdeko',
    'christbaumschmuck',
    'kerze',
    'geschenk',
    'verpackung',
    'tüte',
    'beutel',
    'korb',
    'box',
    'dose', // Nur wenn nicht Lebensmittel-Dose
  };

  /// Keywords, die auf Lebensmittel hinweisen (im Titel)
  static const Set<String> _foodKeywords = {
    'apfel',
    'banane',
    'tomate',
    'gurke',
    'kartoffel',
    'zwiebel',
    'karotte',
    'paprika',
    'hähnchen',
    'rind',
    'schwein',
    'fisch',
    'lachs',
    'thunfisch',
    'milch',
    'käse',
    'joghurt',
    'quark',
    'butter',
    'eier',
    'brot',
    'brötchen',
    'nudeln',
    'reis',
    'mehl',
    'zucker',
    'salz',
    'öl',
    'wasser',
    'saft',
    'cola',
    'bier',
    'wein',
    'schokolade',
    'kekse',
    'chips',
    'nüsse',
    'müsli',
    'cornflakes',
  };

  /// Filtert eine Liste von Offers und gibt nur Lebensmittel zurück
  static List<Offer> filterFoodOffers(List<Offer> offers) {
    return offers.where((offer) => _isFoodOffer(offer)).toList();
  }

  /// Prüft, ob ein Offer ein Lebensmittel ist
  static bool _isFoodOffer(Offer offer) {
    // Extrahiere Kategorie aus dem Titel (falls vorhanden)
    // ALDI Nord Format: "Ab Mo. 8.12. – Wochen-Angebote: Milchprodukte."
    // Oder: "Spitzpaprika rot" mit category "Obst & Gemüse"
    
    final title = offer.title.toLowerCase();
    
    // 1. Prüfe explizite Nicht-Lebensmittel-Keywords im Titel
    for (final keyword in _nonFoodKeywords) {
      if (title.contains(keyword)) {
        return false;
      }
    }
    
    // 2. Prüfe explizite Lebensmittel-Keywords im Titel
    for (final keyword in _foodKeywords) {
      if (title.contains(keyword)) {
        return true;
      }
    }
    
    // 3. Prüfe Kategorie (falls im JSON vorhanden, aber Offer-Modell hat kein category-Feld)
    // Da das Offer-Modell kein category-Feld hat, müssen wir aus dem Titel ableiten
    // Oder wir erweitern das Modell
    
    // 4. Heuristik: Wenn der Titel sehr kurz ist und keine Lebensmittel-Keywords enthält,
    // aber auch keine Nicht-Lebensmittel-Keywords, dann als Lebensmittel annehmen
    // (konservativer Ansatz: lieber zu viel als zu wenig)
    
    // 5. Prüfe auf typische Nicht-Lebensmittel-Muster
    if (_containsNonFoodPattern(title)) {
      return false;
    }
    
    // Standard: Als Lebensmittel annehmen (konservativer Ansatz)
    return true;
  }

  /// Prüft auf Muster, die auf Nicht-Lebensmittel hinweisen
  static bool _containsNonFoodPattern(String title) {
    final patterns = [
      RegExp(r'\d+\s*(stück|stk|teil|teile)\s*(t-shirt|shirt|hose|jacke)', caseSensitive: false),
      RegExp(r'(spielzeug|puzzle|bausatz)', caseSensitive: false),
      RegExp(r'(werkzeug|bohrer|schraube|nagel)', caseSensitive: false),
      RegExp(r'(pflanze|blume|topf|erde|dünger)', caseSensitive: false),
      RegExp(r'(shampoo|duschgel|creme|make-up)', caseSensitive: false),
      RegExp(r'(waschmittel|spülmittel|tücher)', caseSensitive: false),
      RegExp(r'(möbel|stuhl|tisch|lampe)', caseSensitive: false),
      RegExp(r'(elektronik|tablet|handy|kamera)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      if (pattern.hasMatch(title)) {
        return true;
      }
    }
    
    return false;
  }

  /// Filtert Offers basierend auf Kategorie-Informationen aus JSON
  /// (für JSON-Dateien, die category-Felder enthalten)
  static List<Map<String, dynamic>> filterFoodOffersFromJson(
    List<Map<String, dynamic>> products,
  ) {
    return products.where((product) {
      final category = (product['category'] as String?)?.toLowerCase() ?? '';
      final name = (product['name'] as String?)?.toLowerCase() ?? '';
      
      // Prüfe explizite Nicht-Lebensmittel-Kategorien
      for (final nonFoodCat in _nonFoodCategories) {
        if (category.contains(nonFoodCat.toLowerCase()) ||
            name.contains(nonFoodCat.toLowerCase())) {
          return false;
        }
      }
      
      // Prüfe Nicht-Lebensmittel-Keywords
      for (final keyword in _nonFoodKeywords) {
        if (name.contains(keyword)) {
          return false;
        }
      }
      
      // Wenn Kategorie explizit als Lebensmittel erkannt wird
      for (final foodCat in _foodCategories) {
        if (category.contains(foodCat.toLowerCase())) {
          return true;
        }
      }
      
      // Prüfe Lebensmittel-Keywords
      for (final keyword in _foodKeywords) {
        if (name.contains(keyword)) {
          return true;
        }
      }
      
      // Konservativer Ansatz: Wenn keine eindeutige Zuordnung, als Lebensmittel annehmen
      // (besser zu viel als zu wenig)
      return true;
    }).toList();
  }
}

