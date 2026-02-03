# Caching und Parsing-Verbesserungen

## Übersicht

Die Implementierung wurde verbessert, um:
1. **Alle Angebote zu erkennen** - Robustes Parsing, das jedes `from_offer=true` erfasst
2. **Wöchentliches Caching** - Rezepte werden einmal pro Woche gespeichert und nicht bei jedem App-Reload neu geladen

## Änderungen

### 1. Robustes Parsing für Angebote (`lib/data/models/recipe.dart`)

**Vorher:** Nur Zutaten mit bestimmten Feldern wurden als Angebote erkannt.

**Jetzt:** 
- **JEDES** `from_offer=true` wird erfasst, auch wenn Felder fehlen
- Robustes Parsing für alle Preis-Felder (verschiedene Key-Varianten)
- Unterstützung für Komma als Dezimaltrennzeichen bei `quantity`
- Fallback-Mechanismen für fehlende Felder

**Logik:**
```dart
// Wenn from_offer=true ist, wird IMMER ein RecipeOfferUsed erstellt
if (fromOffer) {
  // Erstelle RecipeOfferUsed mit verfügbaren Daten
  // Fehlende Felder werden mit Defaults gefüllt (z.B. priceEur = 0.0)
}
```

**Unterstützte Keys (in dieser Reihenfolge):**
- `price_eur`, `priceEur`, `price`
- `price_before_eur`, `priceBeforeEur`, `price_before`, `uvp_eur`, `uvpEur`
- `offer_id`, `offerId`
- `offer_product`, `offerProduct`, `product`, `exact_name`

### 2. Wöchentliches Caching (`lib/data/services/supermarket_recipe_repository.dart`)

**Funktionalität:**
- Rezepte werden einmal pro Woche geladen und in `SharedPreferences` gespeichert
- Cache-Key basiert auf `weekKey` (z.B. "2025-W42")
- Bei App-Reload wird zuerst der Cache geprüft
- Automatisches Neuladen wenn neue Woche beginnt

**Verwendung:**
```dart
// Normale Verwendung (verwendet Cache wenn verfügbar)
final recipes = await SupermarketRecipeRepository.loadAllSupermarketRecipes();

// Force Refresh (lädt neu, ignoriert Cache)
final recipes = await SupermarketRecipeRepository.loadAllSupermarketRecipes(forceRefresh: true);

// Cache manuell löschen
await SupermarketRecipeRepository.clearCache();
```

**Cache-Struktur:**
- Key: `supermarket_recipes_cache_{supermarket}` (z.B. `supermarket_recipes_cache_kaufland`)
- Week-Key: `supermarket_recipes_cache_week`
- Format: JSON-String (Liste von Recipe-Objekten)

### 3. Validierung (angepasst)

Die Validierung wurde angepasst:
- **Vorher:** Strict - Rezept wurde verworfen wenn Felder fehlen
- **Jetzt:** Permissive - Warnungen werden gespeichert, Rezept wird trotzdem erstellt

**Validierungsregeln:**
- Für `from_offer=true` Zutaten: Warnung wenn wichtige Felder fehlen, aber Rezept wird erstellt
- Validierungswarnungen werden im `warnings` Feld gespeichert

## Beispiel

### Caching-Verhalten

```dart
// Montag, Woche 42
final recipes1 = await SupermarketRecipeRepository.loadAllSupermarketRecipes();
// → Lädt von Server, speichert im Cache

// Dienstag, immer noch Woche 42
final recipes2 = await SupermarketRecipeRepository.loadAllSupermarketRecipes();
// → Lädt aus Cache (schnell, keine Server-Anfrage)

// Montag nächster Woche, Woche 43
final recipes3 = await SupermarketRecipeRepository.loadAllSupermarketRecipes();
// → Lädt von Server (neue Woche), speichert im Cache
```

### Parsing-Verhalten

```json
{
  "from_offer": true,
  "offer_id": "O016",
  "price_eur": 1.49,
  "brand": "BARILLA"
}
```
→ Wird **immer** erkannt, auch wenn `price_before_eur` oder andere Felder fehlen

```json
{
  "from_offer": true,
  "name": "Pasta"
}
```
→ Wird **immer** erkannt, `offer_id` wird leer sein, `priceEur` wird 0.0 sein

## Performance

- **Erstes Laden:** HTTP-Request zu allen Supermärkten
- **Weitere Loads (gleiche Woche):** Instant aus Cache
- **Neue Woche:** Automatisches Neuladen

## Fehlerbehandlung

- Fehlende Felder werden mit Defaults gefüllt
- Ungültige Rezepte werden übersprungen (kein Crash)
- Cache-Fehler werden ignoriert (Neuladen vom Server)

## Migration

Keine Migration nötig - Cache wird automatisch erstellt beim ersten Aufruf.

Für Entwickler: Cache kann manuell gelöscht werden:
```dart
await SupermarketRecipeRepository.clearCache();
```

