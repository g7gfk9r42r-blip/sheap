# Supermarket Recipe Import Guide

## Übersicht

Dieses Dokument beschreibt die Implementierung der robusten Import-Schicht für Rezepte aus allen 12 Supermärkten.

## Implementierte Dateien

### 1. `lib/data/services/supermarket_recipe_repository.dart`

**Zweck:** Lädt Rezepte aus allen Supermärkten im `/server/media/prospekte/` Verzeichnis.

**Hauptfunktionen:**
- `loadAllSupermarketRecipes()`: Lädt alle Rezepte von allen Supermärkten
- `loadSupermarketRecipes(String supermarket)`: Lädt Rezepte für einen spezifischen Supermarkt
- `_validateRecipe()`: Validiert Rezepte (insbesondere Angebots-Zutaten)

**Verwendung:**
```dart
// Alle Supermärkte laden
final allRecipes = await SupermarketRecipeRepository.loadAllSupermarketRecipes();
// Ergebnis: { "kaufland": [Recipe...], "lidl": [Recipe...], ... }

// Einen Supermarkt laden
final kauflandRecipes = await SupermarketRecipeRepository.loadSupermarketRecipes('kaufland');
```

### 2. `lib/data/models/recipe.dart` (Erweiterungen)

**Anpassungen:**
- `Recipe.fromJson()` unterstützt jetzt snake_case Keys:
  - `name` → `title`
  - `price_total_eur`, `price_total_before_eur`, `savings_percent`
  - `diet_categories` → `tags`
  - `steps` (als Array)
  - `ingredients[]` mit allen Feldern: `name`, `quantity`, `unit`, `from_offer`, `offer_id`, `price_eur`, `price_before_eur`, `brand`, `product`, `note`

**Wichtig:** Die Methode unterstützt auch camelCase-Varianten als Fallback.

### 3. `lib/data/models/recipe_offer.dart` (Erweiterungen)

**Anpassungen:**
- `quantity` Feld hinzugefügt
- `RecipeOfferUsed.fromJson()` unterstützt:
  - `offer_id` / `offerId`
  - `price_eur` / `priceEur`
  - `price_before_eur` / `priceBeforeEur`
  - `offer_product` / `product` / `exact_name`
  - `quantity` (num oder String)

## Validierung

Die Validierung prüft:
- Für `from_offer=true` Zutaten müssen vorhanden sein:
  - `offer_id` (nicht null/leer)
  - `price_eur` (nicht null)
  - `brand` oder `product` (mindestens eines nicht null/leer)

Bei Validierungsfehlern werden Warnungen zum Rezept hinzugefügt, aber das Rezept wird trotzdem erstellt.

## Integration in Flutter

### Option 1: FutureBuilder (einfach)

```dart
FutureBuilder<Map<String, List<Recipe>>>(
  future: SupermarketRecipeRepository.loadAllSupermarketRecipes(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) {
      return Text('Fehler: ${snapshot.error}');
    }
    final recipesBySupermarket = snapshot.data ?? {};
    
    // Verwendung: recipesBySupermarket['kaufland'] enthält alle Kaufland-Rezepte
    return ListView.builder(
      itemCount: recipesBySupermarket['kaufland']?.length ?? 0,
      itemBuilder: (context, index) {
        final recipe = recipesBySupermarket['kaufland']![index];
        return ListTile(title: Text(recipe.title));
      },
    );
  },
)
```

### Option 2: Provider/ChangeNotifier (empfohlen für komplexe Apps)

```dart
class RecipeProvider extends ChangeNotifier {
  Map<String, List<Recipe>> _recipesBySupermarket = {};
  bool _isLoading = false;
  String? _error;

  Map<String, List<Recipe>> get recipesBySupermarket => _recipesBySupermarket;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadAllRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipesBySupermarket = await SupermarketRecipeRepository.loadAllSupermarketRecipes();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

## Konfiguration

### API Base URL

Die Basis-URL kann über die Umgebungsvariable `API_BASE_URL` konfiguriert werden:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

Standardwert: `http://localhost:3000`

Der vollständige Pfad zu den Rezepten ist:
`{API_BASE_URL}/media/prospekte/{supermarket}/{filename}`

## Unterstützte Supermärkte

1. kaufland
2. lidl
3. rewe
4. aldi_nord
5. aldi_sued
6. netto
7. penny
8. norma
9. nahkauf
10. tegut
12. biomarkt

## Fehlerbehandlung

- Wenn eine Datei nicht gefunden wird, wird der nächste Dateiname probiert
- Wenn ein Supermarkt komplett fehlschlägt, wird er übersprungen (kein Crash)
- Wenn ein einzelnes Rezept ungültig ist, wird es übersprungen (kein Crash)
- Validierungswarnungen werden im Rezept-Objekt gespeichert (`warnings` Feld)

## JSON-Schema-Unterstützung

Der Parser unterstützt folgende Keys (snake_case primär, camelCase als Fallback):

**Top-Level:**
- `id`, `name` (→ `title`), `steps`, `diet_categories` (→ `tags`)
- `price_total_eur`, `price_total_before_eur`, `savings_percent`

**Ingredients:**
- `name`, `quantity`, `unit`, `from_offer`, `offer_id`
- `price_eur`, `price_before_eur`, `brand`, `product`, `note`

## Nächste Schritte

1. **Integration in main.dart:**
   - Provider einbinden (falls verwendet)
   - Initiales Laden beim App-Start

2. **Integration in Screens:**
   - Recipe-Discovery-Screen
   - Recipe-Detail-Screen
   - Shopping-List-Integration

3. **Caching:**
   - Optional: Lokales Caching der Rezepte
   - Optional: Refresh-Mechanismus

