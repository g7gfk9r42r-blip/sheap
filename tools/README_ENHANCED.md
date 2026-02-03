# Enhanced Recipe Generator - Dokumentation

## Übersicht

Das **Enhanced Recipe Generator** Tool (`generate_recipes_for_all_supermarkets_enhanced.dart`) ist eine verbesserte Version des bestehenden Rezept-Generators mit folgenden Features:

- ✅ **Automatische Filterung von Nicht-Lebensmitteln** (Kleidung, Spielzeug, etc.)
- ✅ **Erweiterte Recipe-Modelle** (steps, servings, difficulty, categories, tags)
- ✅ **Automatische Index-Generierung** (`file_index.json`)
- ✅ **Kompatibilität mit bestehenden Datenstrukturen**

## Voraussetzungen

### 1. OpenAI API Key

Erstelle eine `.env` Datei im Projekt-Root:

```bash
echo "OPENAI_API_KEY=sk-your-key-here" > .env
```

Oder setze die Umgebungsvariable:

```bash
export OPENAI_API_KEY='sk-your-key-here'
```

### 2. Angebots-JSON-Dateien

Platziere JSON-Dateien in `assets/data/` mit dem Format:

- `angebote_aldi_nord_2025-W49.json`
- `angebote_lidl_2025-W49.json`
- `angebote_rewe_2025-W49.json`
- etc.

**Unterstützte Formate:**
- ALDI Nord: `{ "products": [{ "name": "...", "price": ..., "category": "..." }] }`
- REWE/EDEKA: `{ "sections": [{ "offers": [...] }] }`
- Standard: `[{ "title": "...", "price": ... }]`

## Verwendung

### Basis-Verwendung

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
dart run tools/generate_recipes_for_all_supermarkets_enhanced.dart
```

### Mit verbose Output

```bash
dart run tools/generate_recipes_for_all_supermarkets_enhanced.dart --verbose
```

## Was passiert?

### 1. Laden der Angebotsdaten

Das Tool:
- Durchsucht `assets/data/` nach JSON-Dateien
- Erkennt Supermarkt aus Dateinamen (z.B. `angebote_aldi_nord_*.json` → "ALDI NORD")
- Lädt alle Angebote in `Offer`-Objekte

### 2. Filterung von Nicht-Lebensmitteln

**Gefiltert werden:**
- ❌ Kleidung / Mode (Wintermode, Damenmode, Kindermode)
- ❌ Spielzeug
- ❌ Heimwerken / Werkzeuge
- ❌ Pflanzen
- ❌ Kosmetik / Drogerie
- ❌ Haushalt (außer Lebensmittel)
- ❌ Elektronik
- ❌ Möbel
- ❌ Weihnachtsdeko

**Behalten werden:**
- ✅ Obst & Gemüse
- ✅ Fleisch & Fisch
- ✅ Milchprodukte
- ✅ Gekühlte & tiefgekühlte Produkte
- ✅ Haltbare Produkte
- ✅ Snacks & Süßes
- ✅ Getränke
- ✅ Backwaren

### 3. Rezept-Generierung

Für jeden Supermarkt:
- Generiert 30-50 einzigartige Rezepte
- Nutzt OpenAI GPT-4o-mini
- Kombiniert möglichst viele Angebotsprodukte
- Erstellt detaillierte Rezepte mit:
  - Titel, Beschreibung
  - Zutaten (mit Mengenangaben)
  - Zubereitungsschritte
  - Nährwerte (Kalorien, Protein, Kohlenhydrate, Fett)
  - Kategorien (Low Carb, High Protein, etc.)
  - Tags (schnell, familie, budget, etc.)

### 4. Speicherung

**Output-Dateien:**
- `assets/recipes/recipes_aldi_nord.json`
- `assets/recipes/recipes_lidl.json`
- `assets/recipes/recipes_rewe.json`
- etc.
- `assets/recipes/file_index.json` (Index aller Dateien)

## Output-Format

### Rezept-JSON (pro Supermarkt)

```json
[
  {
    "id": "aldi_nord-1",
    "title": "Buntes Gemüse-Risotto mit Maronen",
    "description": "Ein herzhaftes Risotto...",
    "category": "balanced",
    "supermarket": "ALDI_NORD",
    "estimated_total_time_minutes": 45,
    "portions": 4,
    "ingredients": [
      {
        "name": "Suppengemüse",
        "amount": "200 g",
        "is_offer_product": true,
        "offer_title_match": "Suppengemüse"
      }
    ],
    "instructions": [
      "Schritt 1...",
      "Schritt 2..."
    ],
    "nutrition_estimate": {
      "kcal_per_portion": 360,
      "protein_g": 12,
      "carbs_g": 45,
      "fat_g": 8
    },
    "image_prompt": "Realistische Food-Fotografie...",
    "tags": ["schnell", "familie", "low_budget"]
  }
]
```

### file_index.json

```json
{
  "generatedAt": "2025-12-08T12:00:00Z",
  "weekKey": "2025-W49",
  "markets": [
    {
      "name": "ALDI NORD",
      "file": "assets/recipes/recipes_aldi_nord.json",
      "recipeCount": 42
    },
    {
      "name": "LIDL",
      "file": "assets/recipes/recipes_lidl.json",
      "recipeCount": 38
    }
  ]
}
```

## Integration in Flutter-App

### RecipeRepository

Der bestehende `RecipeRepository` wurde erweitert, um:
- Erweiterte Recipe-Felder zu unterstützen (steps, servings, etc.)
- Sowohl alte als auch neue JSON-Formate zu parsen
- Automatisch aus `assets/recipes/` zu laden

**Verwendung in der App:**

```dart
// Lade Rezepte für einen Supermarkt
final recipes = await RecipeRepository.loadRecipesFromAssets('ALDI NORD');

// Lade alle Rezepte
final allRecipes = await RecipeRepository.loadAllRecipesFromAssets();
```

### Recipe-Modell

Das `Recipe`-Modell wurde erweitert um:
- `servings` (int?)
- `durationMinutes` (int?)
- `difficulty` (String? - "easy" | "medium" | "hard")
- `categories` (List<String>?)
- `tags` (List<String>?)
- `steps` (List<String>?)

Alle Felder sind optional für Rückwärtskompatibilität.

## Fehlerbehandlung

- **Keine Angebote gefunden**: Tool bricht ab mit hilfreicher Fehlermeldung
- **OpenAI API Fehler**: Fehler wird geloggt, nächster Supermarkt wird verarbeitet
- **JSON-Parsing Fehler**: Fehler wird geloggt, Datei wird übersprungen
- **Fehlende Felder**: Tool verwendet sinnvolle Defaults

## Erweiterte Features

### Nicht-Lebensmittel-Filter

Der `OfferFilter` verwendet:
- **Kategorie-basierte Filterung** (für JSON mit `category`-Feld)
- **Keyword-basierte Filterung** (für Titel-Analyse)
- **Pattern-Matching** (für komplexe Muster)

### AI-Prompt-Optimierung

Der AI-Prompt wurde optimiert für:
- Maximale Nutzung von Angebotsprodukten (75-100%)
- Kreative, aber alltagstaugliche Rezepte
- Detaillierte Nährwertangaben
- Realistische Bild-Prompts für spätere Bildgenerierung

## Troubleshooting

### "OPENAI_API_KEY not found"
- Prüfe, ob `.env` Datei existiert
- Prüfe, ob `OPENAI_API_KEY=...` in `.env` steht
- Oder setze Umgebungsvariable: `export OPENAI_API_KEY=...`

### "No offers found"
- Prüfe, ob JSON-Dateien in `assets/data/` existieren
- Prüfe Dateinamen-Format: `angebote_<supermarket>_<date>.json`
- Prüfe, ob JSON-Dateien gültig sind

### "Failed to generate recipes"
- Prüfe OpenAI API Key (gültig, nicht abgelaufen)
- Prüfe Internet-Verbindung
- Prüfe OpenAI API Quota/Limits
- Verwende `--verbose` für detaillierte Fehlermeldungen

## Nächste Schritte

1. **Teste das Tool** mit deinen Angebots-JSONs
2. **Prüfe die generierten Rezepte** in `assets/recipes/`
3. **Lade Rezepte in der App** über `RecipeRepository`
4. **Passe Prompts an** in `AIRecipeService`, falls nötig

