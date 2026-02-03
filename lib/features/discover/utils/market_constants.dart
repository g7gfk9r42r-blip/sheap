/// Central market mapping for robust filtering
/// Maps display names to internal keys used in data
class MarketConstants {
  // All supported markets with display names and internal keys
  static const markets = [
    MarketInfo(displayName: 'Alle', key: ''),
    MarketInfo(displayName: 'EDEKA', key: 'edeka'),
    MarketInfo(displayName: 'REWE', key: 'rewe'),
    MarketInfo(displayName: 'LIDL', key: 'lidl'),
    MarketInfo(displayName: 'ALDI Süd', key: 'aldi_sued'),
    MarketInfo(displayName: 'ALDI Nord', key: 'aldi_nord'),
    MarketInfo(displayName: 'PENNY', key: 'penny'),
    MarketInfo(displayName: 'NETTO', key: 'netto'),
    MarketInfo(displayName: 'NORMA', key: 'norma'),
    MarketInfo(displayName: 'KAUFLAND', key: 'kaufland'),
    MarketInfo(displayName: 'BIOMARKT', key: 'biomarkt'),
  ];

  /// Normalize market input to match internal key
  /// Handles: case insensitivity, special chars, variations
  static String normalizeMarket(String input) {
    if (input.isEmpty) return '';
    
    final normalized = input
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss')
        .trim();
    
    // Handle variations
    if (normalized.contains('aldi')) {
      if (normalized.contains('sued') || normalized.contains('süd') || normalized.contains('sud')) {
        return 'aldi_sued';
      }
      if (normalized.contains('nord')) {
        return 'aldi_nord';
      }
      return 'aldi_sued'; // Default to Süd
    }
    
    // Direct matches
    for (final market in markets) {
      if (market.key.isNotEmpty && normalized.contains(market.key)) {
        return market.key;
      }
    }
    
    return normalized;
  }

  /// Get display name for a key
  static String getDisplayName(String key) {
    if (key.isEmpty) return 'Alle';
    final market = markets.firstWhere(
      (m) => m.key == key,
      orElse: () => MarketInfo(displayName: key.toUpperCase(), key: key),
    );
    return market.displayName;
  }
}

/// Market info model
class MarketInfo {
  final String displayName;
  final String key;

  const MarketInfo({
    required this.displayName,
    required this.key,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketInfo && key == other.key;

  @override
  int get hashCode => key.hashCode;
}
