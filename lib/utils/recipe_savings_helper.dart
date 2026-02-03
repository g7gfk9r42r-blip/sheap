/// Helper für Recipe-Savings-Berechnung
/// Berechnet Savings basierend auf offers_used (falls vorhanden)
import '../models/weekly_bundle.dart';
import '../data/models/recipe.dart';

/// Savings-Ergebnis für ein Recipe
class RecipeSavings {
  final double? savingsEur;
  final double? savingsPercent;

  const RecipeSavings({
    this.savingsEur,
    this.savingsPercent,
  });

  bool get hasSavings => savingsEur != null && savingsEur! > 0;
  
  String get displayText {
    if (!hasSavings) return 'Ersparnis nicht verfügbar';
    final percent = savingsPercent != null 
        ? ' (${savingsPercent!.toStringAsFixed(0)}%)' 
        : '';
    return 'Du sparst ${savingsEur!.toStringAsFixed(2)} €$percent';
  }
}

/// Berechnet Savings für ein Recipe basierend auf offers_used
/// 
/// Wenn Recipe ein WeeklyRecipe ist (mit offersUsed), wird basierend auf
/// priceEur vs priceBeforeEur/uvpEur berechnet.
/// 
/// Wenn Recipe nur ein normales Recipe ist (mit .savings Feld), wird das verwendet.
/// 
/// Algorithmus:
/// - currentTotal = Summe offer.priceEur aus offers_used
/// - referenceTotal = Summe je offer: (offer.priceBeforeEur ?? offer.uvpEur), 
///   aber nur wenn einer davon vorhanden ist
/// - coverage = (#offers mit Referenz) / (Gesamt #offers_used)
/// - Wenn coverage >= 0.7 und referenceTotal != null:
///      savingsEur = referenceTotal - currentTotal
///      savingsPercent = (savingsEur / referenceTotal) * 100
///   sonst savingsEur = null
RecipeSavings computeRecipeSavings(dynamic recipe) {
  // Fall 1: WeeklyRecipe mit offersUsed
  if (recipe is WeeklyRecipe && recipe.offersUsed.isNotEmpty) {
    final offers = recipe.offersUsed;
    
    // currentTotal = Summe aller priceEur
    double currentTotal = 0.0;
    for (final offer in offers) {
      currentTotal += offer.priceEur;
    }
    
    // referenceTotal = Summe von priceBeforeEur oder uvpEur (wenn vorhanden)
    double? referenceTotal;
    int offersWithReference = 0;
    
    for (final offer in offers) {
      final referencePrice = offer.priceBeforeEur ?? offer.uvpEur;
      if (referencePrice != null) {
        if (referenceTotal == null) referenceTotal = 0.0;
        referenceTotal += referencePrice;
        offersWithReference++;
      }
    }
    
    // coverage = Anteil der Offers mit Referenzpreis
    final coverage = offers.length > 0 ? offersWithReference / offers.length : 0.0;
    
    // Nur berechnen wenn coverage >= 0.7 und referenceTotal vorhanden
    if (coverage >= 0.7 && referenceTotal != null && referenceTotal > currentTotal) {
      final savingsEur = referenceTotal - currentTotal;
      final savingsPercent = (savingsEur / referenceTotal) * 100;
      return RecipeSavings(
        savingsEur: savingsEur,
        savingsPercent: savingsPercent,
      );
    }
    
    return const RecipeSavings();
  }
  
  // Fall 2: Normales Recipe mit .savingsPercent (neue Rezepte aus recipe_pricing)
  if (recipe is Recipe && recipe.savingsPercent != null && recipe.savingsPercent! > 0) {
    // Neue Rezepte haben savingsPercent direkt
    final savingsEur = recipe.savings ?? (recipe.priceBeforeEur != null && recipe.priceNowEur != null
        ? recipe.priceBeforeEur! - recipe.priceNowEur!
        : null);
    return RecipeSavings(
      savingsEur: savingsEur,
      savingsPercent: recipe.savingsPercent,
    );
  }
  
  // Fall 3: Normales Recipe mit .savings Feld (alte Rezepte)
  if (recipe is Recipe && recipe.savings != null && recipe.savings! > 0) {
    // Für normales Recipe haben wir keine offers_used, verwenden .savings Feld
    // Prozent können wir nicht berechnen ohne referenceTotal
    return RecipeSavings(
      savingsEur: recipe.savings,
      savingsPercent: null,
    );
  }
  
  // Fall 3: Keine Savings-Daten verfügbar
  return const RecipeSavings();
}
