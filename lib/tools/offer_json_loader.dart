/// OfferJsonLoader
/// Lädt Angebots-JSON-Dateien und konvertiert sie in Offer-Objekte.
/// 
/// Unterstützt verschiedene JSON-Formate:
/// - Format 1: { "market": "REWE", "sections": [{ "offers": [...] }] }
/// - Format 2: Direktes Array von Offers im Standard-Format
/// 
/// Die JSON-Dateien liegen im Server-Verzeichnis: server/media/prospekte/<retailer>/<retailer>.json
/// ODER im Assets-Verzeichnis: assets/data/angebote_<retailer>_YYYYMMDD.json

import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import '../data/models/offer.dart';
import 'offer_filter.dart';

class OfferJsonLoader {
  /// Lädt alle Angebots-JSON-Dateien aus assets/data/
  /// mit Dateinamen-Format: angebote_<retailer>_YYYYMMDD.json
  /// 
  /// Gibt eine Map zurück: { "REWE": [Offer, ...], "LIDL": [Offer, ...], ... }
  static Future<Map<String, List<Offer>>> loadOffersFromAssetsData(
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    final Map<String, List<Offer>> offersByRetailer = {};
    // Unterstützt beide Formate: angebote_<retailer>_YYYYMMDD.json oder angebote_<retailer>_YYYY-Www.json
    final pattern = RegExp(r'angebote_(\w+)_(\d{8}|\d{4}-W\d{2})\.json$', caseSensitive: false);

    // Liste alle Dateien im Verzeichnis für bessere Fehlermeldungen
    final allFiles = <String>[];
    final matchedFiles = <String>[];
    final skippedFiles = <String>[];

    // Durchsuche alle JSON-Dateien im Verzeichnis
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        final filename = entity.path.split(Platform.pathSeparator).last;
        allFiles.add(filename);
        final match = pattern.firstMatch(filename);
        
        if (match != null) {
          matchedFiles.add(filename);
          final retailerName = match.group(1)!.toUpperCase();
          try {
            final offers = await _loadOffersFromFile(entity.path, retailerName);
            offersByRetailer.putIfAbsent(retailerName, () => []).addAll(offers);
            print('✅ Loaded ${offers.length} offers from $filename (${retailerName})');
          } catch (e) {
            print('⚠️  Failed to load $filename: $e');
            skippedFiles.add(filename);
          }
        } else {
          skippedFiles.add(filename);
        }
      }
    }

    // Wenn keine Dateien gefunden wurden, gib hilfreiche Informationen
    if (allFiles.isEmpty) {
      print('⚠️  No JSON files found in $directoryPath');
      print('   Expected files: angebote_<supermarket>_<date>.json');
      print('   Examples: angebote_lidl_2025-W49.json, angebote_rewe_20250101.json');
    } else if (matchedFiles.isEmpty) {
      print('⚠️  Found ${allFiles.length} JSON file(s), but none matched the expected pattern:');
      for (final file in allFiles) {
        print('   - $file');
      }
      print('');
      print('   Expected pattern: angebote_<supermarket>_<date>.json');
      print('   Examples: angebote_lidl_2025-W49.json, angebote_rewe_20250101.json');
    }

    return offersByRetailer;
  }

  /// Lädt alle Angebots-JSON-Dateien aus einem Verzeichnis
  /// und gruppiert sie nach Supermarkt.
  /// 
  /// Gibt eine Map zurück: { "REWE": [Offer, ...], "LIDL": [Offer, ...], ... }
  static Future<Map<String, List<Offer>>> loadOffersFromDirectory(
    String directoryPath,
  ) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $directoryPath');
    }

    final Map<String, List<Offer>> offersByRetailer = {};

    // Durchsuche alle Unterverzeichnisse (z.B. rewe/, lidl/, edeka/)
    await for (final entity in directory.list()) {
      if (entity is Directory) {
        final retailerName = entity.path.split(Platform.pathSeparator).last;
        final retailerUpper = retailerName.toUpperCase();
        
        // Suche nach JSON-Dateien im Unterverzeichnis
        final jsonFiles = entity
            .listSync()
            .where((f) => f is File && f.path.endsWith('.json'))
            .cast<File>();

        for (final jsonFile in jsonFiles) {
          try {
            final offers = await _loadOffersFromFile(jsonFile.path, retailerUpper);
            offersByRetailer.putIfAbsent(retailerUpper, () => []).addAll(offers);
            print('✅ Loaded ${offers.length} offers from ${jsonFile.path}');
          } catch (e) {
            print('⚠️  Failed to load ${jsonFile.path}: $e');
          }
        }
      }
    }

    return offersByRetailer;
  }

  /// Lädt Offers aus einer einzelnen JSON-Datei
  static Future<List<Offer>> _loadOffersFromFile(
    String filePath,
    String retailer,
  ) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);

    // Prüfe Format
    if (decoded is Map<String, dynamic>) {
      final json = decoded;
      // Hat die Datei "sections"?
      if (json.containsKey('sections')) {
        return _parseSectionsFormat(json, retailer);
      } else if (json.containsKey('items') && json['items'] is List) {
        // Globus Format: "items" Array
        return _parseItemsFormat(json, retailer);
      } else if (json.containsKey('products') && json['products'] is List) {
        // ALDI Nord Format: "products" Array
        // Filtere Nicht-Lebensmittel direkt beim Parsen
        final allProducts = json['products'] as List;
        final foodProducts = OfferFilter.filterFoodOffersFromJson(
          allProducts.cast<Map<String, dynamic>>(),
        );
        // Erstelle temporäres JSON mit gefilterten Produkten
        final filteredJson = Map<String, dynamic>.from(json);
        filteredJson['products'] = foodProducts;
        return _parseProductsFormat(filteredJson, retailer);
      } else if (json.containsKey('offers') && json['offers'] is List) {
        // Standard-Format: direktes Array von Offers
        return _parseStandardFormat(json['offers'] as List, retailer);
      } else {
        throw Exception('Unknown JSON format in $filePath');
      }
    } else if (decoded is List) {
      // Direktes Array
      return _parseStandardFormat(decoded, retailer);
    } else {
      throw Exception('Unknown JSON format in $filePath');
    }
  }

  /// Parst das "sections"-Format (z.B. REWE, EDEKA)
  static List<Offer> _parseSectionsFormat(
    Map<String, dynamic> json,
    String retailer,
  ) {
    final List<Offer> offers = [];
    final sections = json['sections'] as List? ?? [];
    final now = DateTime.now();
    
    // Validity: Diese Woche (Montag bis Sonntag)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final validFrom = DateTime(monday.year, monday.month, monday.day);
    final validTo = validFrom.add(const Duration(days: 6, hours: 23, minutes: 59));

    for (final section in sections) {
      final sectionData = section as Map<String, dynamic>;
      final sectionOffers = sectionData['offers'] as List? ?? [];

      for (final offerData in sectionOffers) {
        if (offerData is! Map<String, dynamic>) continue;
        final offerMap = offerData;
        try {
          final offer = _convertToOffer(offerMap, retailer, validFrom, validTo, now);
          offers.add(offer);
        } catch (e) {
          // Stille Fehler - zu viele Warnungen machen die Ausgabe unlesbar
          // Nur bei sehr wenigen Fehlern anzeigen
        }
      }
    }

    return offers;
  }

  /// Parst das "items"-Format (z.B. Globus)
  static List<Offer> _parseItemsFormat(
    Map<String, dynamic> json,
    String retailer,
  ) {
    final List<Offer> offers = [];
    final items = json['items'] as List? ?? [];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final validFrom = DateTime(monday.year, monday.month, monday.day);
    final validTo = validFrom.add(const Duration(days: 6, hours: 23, minutes: 59));

    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      try {
        // Globus Format: "name", "raw_text" (kein direkter Preis)
        final title = item['name'] as String? ?? '';
        if (title.isEmpty) continue;
        
        // Versuche Preis aus raw_text zu extrahieren, sonst 0.0
        final rawText = item['raw_text'] as String? ?? '';
        final price = _extractPriceFromText(rawText);
        
        // Versuche Einheit aus raw_text zu extrahieren
        final unit = _extractUnitFromRawText(rawText);
        
        // Generiere ID
        final idString = '$retailer-$title-$price';
        final bytes = utf8.encode(idString);
        final hash = crypto.sha256.convert(bytes);
        final id = hash.toString().substring(0, 16);

        offers.add(Offer(
          id: id,
          retailer: retailer,
          title: title,
          price: price,
          unit: unit,
          validFrom: validFrom,
          validTo: validTo,
          imageUrl: null,
          updatedAt: now,
        ));
      } catch (e) {
        // Stille Fehler
      }
    }

    return offers;
  }

  /// Extrahiert Preis aus Text (z.B. "1 kg = 11.46" -> 11.46)
  static double _extractPriceFromText(String text) {
    // Suche nach Mustern wie "1 kg = 11.46" oder "€ 2.99"
    final pricePatterns = [
      RegExp(r'1\s*kg\s*=\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'€\s*(\d+[.,]\d+)', caseSensitive: false),
      RegExp(r'(\d+[.,]\d+)\s*€', caseSensitive: false),
    ];
    
    for (final pattern in pricePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final priceStr = match.group(1)!.replaceAll(',', '.');
        try {
          return double.parse(priceStr);
        } catch (e) {
          continue;
        }
      }
    }
    
    return 0.0; // Kein Preis gefunden
  }

  /// Extrahiert Einheit aus raw_text (z.B. "250 g-Schale" -> "250g")
  static String? _extractUnitFromRawText(String text) {
    // Suche nach Mustern wie "250 g", "1 kg", "500 ml"
    final unitPattern = RegExp(r'(\d+)\s*(g|kg|l|ml|stück|stk|g-Beutel|g-Schale|g-Packung)', caseSensitive: false);
    final match = unitPattern.firstMatch(text);
    if (match != null) {
      final amount = match.group(1) ?? '';
      final unit = match.group(2)?.toLowerCase().replaceAll(RegExp(r'[-beutel|schale|packung]'), '') ?? '';
      return '$amount$unit';
    }
    return null;
  }

  /// Parst das "products"-Format (z.B. ALDI Nord)
  static List<Offer> _parseProductsFormat(
    Map<String, dynamic> json,
    String retailer,
  ) {
    final List<Offer> offers = [];
    final products = json['products'] as List? ?? [];
    final now = DateTime.now();
    
    // Versuche valid_from/valid_to aus JSON zu extrahieren
    DateTime validFrom;
    DateTime validTo;
    if (json.containsKey('valid_from') && json['valid_from'] != null) {
      try {
        validFrom = DateTime.parse(json['valid_from'] as String);
      } catch (e) {
        final monday = now.subtract(Duration(days: now.weekday - 1));
        validFrom = DateTime(monday.year, monday.month, monday.day);
      }
    } else {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      validFrom = DateTime(monday.year, monday.month, monday.day);
    }
    
    if (json.containsKey('valid_to') && json['valid_to'] != null) {
      try {
        validTo = DateTime.parse(json['valid_to'] as String);
      } catch (e) {
        validTo = validFrom.add(const Duration(days: 6, hours: 23, minutes: 59));
      }
    } else {
      validTo = validFrom.add(const Duration(days: 6, hours: 23, minutes: 59));
    }

    for (final product in products) {
      if (product is! Map<String, dynamic>) continue;
      try {
        // ALDI Nord Format: "name", "price", "unit", "category"
        final title = product['name'] as String? ?? '';
        if (title.isEmpty) continue;
        
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;
        final unit = product['unit'] as String?;
        
        // Generiere ID
        final idString = '$retailer-$title-$price';
        final bytes = utf8.encode(idString);
        final hash = crypto.sha256.convert(bytes);
        final id = hash.toString().substring(0, 16);

        offers.add(Offer(
          id: id,
          retailer: retailer,
          title: title,
          price: price,
          unit: unit,
          validFrom: validFrom,
          validTo: validTo,
          imageUrl: null,
          updatedAt: now,
        ));
      } catch (e) {
        // Stille Fehler
      }
    }

    return offers;
  }

  /// Parst das Standard-Format (direktes Array von Offers)
  static List<Offer> _parseStandardFormat(
    List jsonList,
    String retailer,
  ) {
    final List<Offer> offers = [];
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final validFrom = DateTime(monday.year, monday.month, monday.day);
    final validTo = validFrom.add(const Duration(days: 6, hours: 23, minutes: 59));

    for (final item in jsonList) {
      if (item is Map<String, dynamic>) {
        try {
          // Prüfe ob bereits im Standard-Format
          if (item.containsKey('id') && item.containsKey('retailer')) {
            offers.add(Offer.fromJson(item));
          } else {
            // Konvertiere zu Offer
            final offer = _convertToOffer(item, retailer, validFrom, validTo, now);
            offers.add(offer);
          }
        } catch (e) {
          // Stille Fehler - zu viele Warnungen machen die Ausgabe unlesbar
        }
      }
    }

    return offers;
  }

  /// Konvertiert ein Angebots-Objekt aus dem JSON in ein Offer-Model
  static Offer _convertToOffer(
    Map<String, dynamic> data,
    String retailer,
    DateTime validFrom,
    DateTime validTo,
    DateTime updatedAt,
  ) {
    // Unterstütze verschiedene Feldnamen für Titel
    // Prüfe in dieser Reihenfolge: title, product, name, label, item, artikel
    String? title;
    for (final key in ['title', 'product', 'name', 'label', 'item', 'artikel', 'bezeichnung']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        title = value.toString().trim();
        break;
      }
    }
    
    // Falls immer noch kein Titel gefunden, versuche alle String-Felder
    if (title == null || title.isEmpty) {
      for (final entry in data.entries) {
        if (entry.value is String && entry.value.toString().trim().isNotEmpty) {
          // Überspringe bekannte Nicht-Titel-Felder
          if (!['price', 'description', 'unit', 'weight', 'id', 'retailer', 'validFrom', 'validTo', 'imageUrl', 'updatedAt'].contains(entry.key)) {
            title = entry.value.toString().trim();
            break;
          }
        }
      }
    }
    
    if (title == null || title.isEmpty) {
      // Zeige verfügbare Keys für besseres Debugging
      final availableKeys = data.keys.toList();
      throw Exception('Offer title/product/name is required. Available keys: ${availableKeys.join(", ")}');
    }

    // Parse Preis: Unterstütze String ("1,11 €") oder Zahl (1.11)
    double price;
    if (data['price'] is num) {
      price = (data['price'] as num).toDouble();
    } else {
      final priceStr = (data['price'] as String?) ?? '0';
      price = _parsePrice(priceStr);
    }

    // Extrahiere Einheit: Unterstütze "unit", "weight", oder aus "description"
    String? unit;
    if (data.containsKey('unit') && data['unit'] != null) {
      unit = data['unit'].toString();
    } else if (data.containsKey('weight') && data['weight'] != null) {
      unit = data['weight'].toString();
    } else {
      final description = (data['description'] as String?) ?? '';
      unit = _extractUnit(description);
    }

    // Generiere ID aus Titel + Retailer + Preis
    final idString = '$retailer-$title-$price';
    final bytes = utf8.encode(idString);
    final hash = crypto.sha256.convert(bytes);
    final id = hash.toString().substring(0, 16);

    return Offer(
      id: id,
      retailer: retailer,
      title: title,
      price: price,
      unit: unit,
      validFrom: validFrom,
      validTo: validTo,
      imageUrl: null,
      updatedAt: updatedAt,
    );
  }

  /// Parst einen Preis-String: "1,11 €" -> 1.11
  static double _parsePrice(String priceStr) {
    // Entferne Währungssymbol und Leerzeichen
    final cleaned = priceStr.replaceAll(RegExp(r'[€\s]'), '');
    // Ersetze Komma durch Punkt
    final normalized = cleaned.replaceAll(',', '.');
    try {
      return double.parse(normalized);
    } catch (e) {
      print('⚠️  Failed to parse price "$priceStr", using 0.0');
      return 0.0;
    }
  }

  /// Extrahiert Einheit aus Description: "je 150-g-Becher" -> "150g"
  static String? _extractUnit(String description) {
    // Suche nach Mustern wie "je 150-g", "je 1-l", "je 500-g"
    final regex = RegExp(r'je\s+(\d+)[-\s]*(g|kg|l|ml|stück|stk)', caseSensitive: false);
    final match = regex.firstMatch(description);
    if (match != null) {
      final amount = match.group(1) ?? '';
      final unit = match.group(2)?.toLowerCase() ?? '';
      return '$amount$unit';
    }
    return null;
  }
}

