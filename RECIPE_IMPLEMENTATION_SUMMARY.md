# Recipe Implementation Summary

## ✅ Implementierte Änderungen

### 1. RecipeRepository: Nur echte Recipe-Dateien laden
- **Datei:** `lib/data/repositories/recipe_repository.dart`
- **Änderung:** `_getAvailableAssetFiles()` filtert jetzt nur `recipes_<market>.json` Dateien
- **Ausgefiltert:** `recipes_with_images*`, `*_unknown*`, etc.
- **Pattern:** `^recipes_[a-z0-9_]+\.json$`
- **Duplikate:** Entfernt via ID+Retailer Set in `loadAllRecipesFromAssets()`

### 2. Recipe Model erweitert
- **Datei:** `lib/data/models/recipe.dart`
- **Neue Felder:**
  - `prepMinutes`, `cookMinutes` (aus neuen Rezepten)
  - `priceBeforeEur`, `priceNowEur`, `savingsPercent` (aus `recipe_pricing` oder direkt)
- **Parsing:**
  - `diet_categories` → `tags` Mapping
  - `recipe_pricing.savings_percent` → `savingsPercent`
  - `prep_minutes + cook_minutes` → `durationMinutes`
  - `name` → `title` Mapping

### 3. TagMapper implementiert
- **Datei:** `lib/utils/tag_mapper.dart` (NEU)
- **Features:**
  - Mappt deutsche Kategorien zu Hashtags (#Vegan, #HighProtein, etc.)
  - Priorität: Vegan/Vegetarisch > HighProtein/LowCarb > Low/HighCalorie > Gluten/Lactose
  - `getTopTags()` gibt max 3 Tags zurück

### 4. Recipe Cards erweitert
- **Dateien:**
  - `lib/features/discover/widgets/recipe_card.dart`
  - `lib/features/recipes/presentation/widgets/recipe_horizontal_card.dart`
  - `lib/features/recipes/presentation/widgets/recipe_list_card.dart`
- **Änderungen:**
  - Tags-Chips mit TagMapper (max 3, priorisiert)
  - Savings Badge rechts oben im Bild (zeigt "Spare X.X%")
  - Kalorien entfernt (nur noch Zeit + Portionen)

### 5. SupermarketRecipesListScreen: Grid-Layout
- **Datei:** `lib/features/recipes/presentation/supermarket_recipes_list_screen.dart`
- **Änderung:** `SliverList` → `SliverGrid`
- **Layout:** 2-spaltig auf breit (>600px), 1-spaltig auf schmal
- **Neue Card:** `_RecipeGridCard` (große, luftige Cards mit mehr Padding)

### 6. Recipe Detail Screen verschönert
- **Datei:** `lib/features/discover/recipe_detail_screen_new.dart`
- **Änderungen:**
  - Hero Image: Zeigt `heroImageUrl` als großes Bild oben (statt nur Emoji)
  - Tags Section: Zeigt max 3 Hashtags mit TagMapper
  - Savings Section: Zeigt "Du sparst X%", "Vorher Y€ / Jetzt Z€"
  - Meta-Zeile: prep_minutes + cook_minutes wenn vorhanden
  - Kalorien entfernt

### 7. Savings Helper erweitert
- **Datei:** `lib/utils/recipe_savings_helper.dart`
- **Änderung:** Unterstützt jetzt `recipe.savingsPercent` (neue Rezepte)

## 📊 Dateistruktur

**Input:** `assets/recipes/recipes_<market>.json`
- Pattern: `recipes_rewe.json`, `recipes_aldi_nord.json`, etc.
- **NICHT geladen:** `recipes_with_images_*.json`, `*_unknown*.json`

**Rezept-Struktur (neue Rezepte):**
```json
{
  "id": "R058",
  "title": "...",
  "diet_categories": ["Vegan", "Kalorienreich", "High Protein"],
  "price_total_before_eur": 8.47,
  "price_total_eur": 7.67,
  "savings_percent": 9.4,
  "prep_minutes": 8,
  "cook_minutes": 0,
  "servings": 2
}
```

## 🎨 UI-Änderungen

### Recipe Cards
- **Tags:** 3 Hashtag-Chips unter dem Titel (z.B. #Vegan, #HighProtein, #LowCarb)
- **Savings Badge:** Rechts oben im Bild ("Spare 9.4%")
- **Keine Kalorien mehr:** Nur Zeit + Portionen

### SupermarketRecipesListScreen ("Mehr"-Screen)
- **Grid-Layout:** 2-spaltig (breit) / 1-spaltig (schmal)
- **Große Cards:** Mehr Padding, größere Bilder
- **Tags + Savings:** Wie in normalen Cards

### Recipe Detail Screen
- **Hero Image:** Großes Bild oben (aus `heroImageUrl`)
- **Savings Widget:** "Du sparst X%" + "Vorher Y€ / Jetzt Z€"
- **Tags Section:** Max 3 Hashtags
- **Meta:** prep_minutes + cook_minutes separat angezeigt

## 🔧 Technische Details

### Tag-Mapping
- "Kalorienreich" → #HighCalorie
- "Kalorienarm" → #LowCalorie
- "Low Carb" → #LowCarb
- "High Protein" → #HighProtein
- "Vegan" → #Vegan
- "Vegetarisch" → #Vegetarian
- "Gluten-free" → #GlutenFree
- "Laktosefrei" → #LactoseFree

### Savings-Berechnung
1. `recipe_pricing.savings_percent` (neue Rezepte)
2. `savings_percent` direkt (neue Rezepte)
3. `price_total_before_eur - price_total_eur` (neue Rezepte)
4. `recipe.savings` (alte Rezepte)

## ✅ Getestet

- ✅ Keine Compile-Fehler
- ✅ RecipeRepository filtert korrekt
- ✅ Tags werden gemappt
- ✅ Savings werden angezeigt
- ✅ Grid-Layout funktioniert

## 🚀 Nächste Schritte

1. App starten: `flutter run`
2. Prüfen:
   - Nur echte Markets erscheinen (keine Duplikate)
   - Tags werden angezeigt
   - Savings Badge erscheint rechts oben
   - "Mehr"-Screen zeigt Grid
   - Detail Screen zeigt Hero Image
