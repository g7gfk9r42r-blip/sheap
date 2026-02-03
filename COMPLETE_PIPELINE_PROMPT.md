# 🚀 KOMPLETTE PIPELINE: Rezepte + Bilder + App-Integration

## 📋 Übersicht

Diese Pipeline führt ALLE Schritte aus:
1. ✅ Erkennt ALLE Rezepte aus `assets/prospekte/<market>/<market>_recipes.json`
2. ✅ Erkennt ALLE drei Zutatentypen (Angebotszutaten, Extra-Zutaten, Basiszutaten)
3. ✅ Generiert Bilder für JEDES Rezept (via Replicate API)
4. ✅ Speichert Rezepte + Bilder offline in `assets/recipes/` und `assets/images/recipes/`
5. ✅ Integriert alles in die Flutter-App (offline-first)

---

## 🎯 PIPELINE-PROMPT FÜR AI ASSISTANT

```
Du bist ein Senior Software Engineer, spezialisiert auf:
- Offline-First Mobile Apps (Flutter)
- Python Asset-Pipelines
- AI-Image-Generation (Replicate API)
- Daten-Migration und Schema-Adapter

## AUFGABE: Komplette Rezept-Pipeline

### PHASE 1: DATEN-ERKENNUNG UND VALIDIERUNG

1. **Markt-Erkennung:**
   - Scanne `assets/prospekte/` nach allen Unterverzeichnissen
   - Erkenne automatisch alle Märkte (aldi_nord, aldi_sued, lidl, rewe, etc.)
   - Für jeden Markt: Lade `<market>/<market>_recipes.json`

2. **Rezept-Erkennung:**
   - Lade JSON-Array oder JSON-Object mit `{"recipes": [...]}`
   - Validiere: Jedes Rezept MUSS haben:
     - `id` (String, Format: R001-R999)
     - `title` oder `name` (String)
     - `categories` (Array of Strings) oder `tags`
     - `servings` (Integer, default: 1)
     - `instructions` oder `steps` (String oder Array of Strings)
   - WICHTIG: KEINE Rezepte erfinden, ergänzen oder entfernen!
   - Output-Anzahl MUSS exakt Input-Anzahl entsprechen

3. **Zutaten-Erkennung (ALLE drei Typen):**
   
   **Typ A: Angebotszutaten (Offer Ingredients)**
   - Feld-Namen: `offer_ingredients`, `ingredients_offers`, oder `ingredients` mit `from_offer: true`
   - Felder pro Zutat:
     - `offer_id` (String)
     - `name` oder `exact_name` (String)
     - `brand` (String, optional)
     - `unit` (String)
     - `pack_size` (Number/String)
     - `packs_used` (Number)
     - `used_amount` (Number/String)
     - `price_eur` (Number)
     - `price_before_eur` (Number, optional)
     - `from_offer: true` (Boolean)
   
   **Typ B: Extra-Zutaten (Extra Ingredients)**
   - Feld-Namen: `extra_ingredients`, `extraIngredients`
   - Felder pro Zutat:
     - `name` (String)
     - `amount` (String/Number)
     - `unit` (String)
   - KEIN `from_offer`, KEIN `offer_id`, KEIN Preis
   
   **Typ C: Basiszutaten (Basic Ingredients)**
   - Feld-Namen: `basic_ingredients`, `basis_ingredients`
   - Felder pro Zutat:
     - `name` (String)
     - `amount` (String/Number, optional)
     - `unit` (String, optional)
   - Optionale Zutaten, die meist im Haushalt vorhanden sind

4. **Schema-Adapter:**
   - Wenn Feld-Namen abweichen, normalisiere zu Standard-Schema
   - KEIN neuer Inhalt, nur Umbenennung/Normalisierung
   - Unterstützte Varianten dokumentieren

### PHASE 2: BILDGENERIERUNG (Replicate API)

5. **Prompt-Erstellung (für JEDES Rezept):**
   
   **Positive Prompt-Struktur:**
   ```
   ultra realistic professional food photography,
   high quality, sharp focus, 8k resolution,
   appetizing, mouth-watering presentation,
   natural lighting, soft shadows, studio quality,
   modern food styling, restaurant-quality plating,
   dish: <recipe_title>,
   ingredients visible: <top_5-7_ingredients_comma_separated>,
   style: <category_hints_aus_categories>,
   overhead or 45-degree angle view,
   centered composition, rule of thirds,
   neutral background, clean presentation,
   shallow depth of field, bokeh background,
   Instagram-worthy, social media ready,
   magazine cover quality,
   professional commercial photography
   ```
   
   **Negative Prompt (immer gleich):**
   ```
   text, logo, watermark, packaging, brand names,
   hands, people, kitchen utensils, pots, pans,
   blurry, low quality, distorted, deformed,
   multiple dishes, cluttered, messy,
   cartoon, illustration, drawing, sketch,
   unnatural colors, oversaturated, underexposed
   ```
   
   **Zutaten-Priorisierung:**
   - Primär: Angebotszutaten (offer_ingredients)
   - Sekundär: Extra-Zutaten (extra_ingredients)
   - Tertiär: Basiszutaten (basic_ingredients)
   - Top 5-7 wichtigste Zutaten für Prompt
   - Entferne Duplikate, behalte Reihenfolge
   
   **Category-Styles:**
   - "high protein" → "muscular, protein-rich, fitness, gym-ready"
   - "vegetarian" → "fresh vegetables, plant-based, colorful, vibrant"
   - "vegan" → "plant-based, colorful, vibrant, ethical"
   - "quick" → "fast, simple, minimal preparation"
   - "healthy" → "nutritious, wholesome, fresh, vibrant"
   - "dessert" → "sweet, indulgent, decadent, rich"
   - etc.

6. **Replicate API Integration:**
   - Model: `black-forest-labs/flux-schnell` (Standard)
   - API-Key: `REPLICATE_API_TOKEN` (Environment Variable)
   - Rate Limiting: Exponential Backoff (bei 429 Errors)
   - Throttling: 200ms zwischen Requests (konfigurierbar)
   - Retry-Logik: Max 3 Versuche mit steigenden Delays
   - Output: PNG-Format, 1024x1024 (1:1 Aspect Ratio)

7. **Bild-Speicherung:**
   - Pfad: `assets/images/recipes/<market>/<recipe_id>.png`
   - Beispiel: `assets/images/recipes/lidl/R001.png`
   - Überspringe, wenn Bild bereits existiert (außer `--force-images`)

### PHASE 3: DATEN-SPEICHERUNG (Offline-First)

8. **Rezept-Normalisierung:**
   - Normalisiere alle Feld-Namen zu Standard-Schema
   - Stelle sicher, dass alle drei Zutatentypen korrekt erkannt wurden
   - Füge `image_path` hinzu: `images/recipes/<market>/<recipe_id>.png`
   - Validiere Konsistenz: Input-Anzahl = Output-Anzahl

9. **Output-Dateien:**
   - Pfad: `assets/recipes/<market>/<market>_recipes.json`
   - Format: Pretty-printed JSON, UTF-8
   - Backup: Optional in `assets/recipes/_backup/<timestamp>/`
   - Struktur: Array of Recipe Objects

10. **Rezept-Schema (Final):**
```json
{
  "id": "R001",
  "title": "Rezept-Titel",
  "categories": ["vegetarian", "quick"],
  "servings": 4,
  "offerIngredients": [
    {
      "offer_id": "O123",
      "name": "Tomaten",
      "brand": "Bio",
      "unit": "kg",
      "pack_size": 1.0,
      "packs_used": 1,
      "used_amount": 0.5,
      "price_eur": 2.99,
      "price_before_eur": 3.99
    }
  ],
  "extraIngredients": [
    {
      "name": "Salz",
      "amount": "1",
      "unit": "TL"
    }
  ],
  "basicIngredients": [
    {
      "name": "Olivenöl",
      "amount": "2",
      "unit": "EL"
    }
  ],
  "instructions": ["Schritt 1", "Schritt 2"],
  "image_path": "images/recipes/lidl/R001.png"
}
```

### PHASE 4: FLUTTER APP-INTEGRATION

11. **Asset-Konfiguration (`pubspec.yaml`):**
```yaml
flutter:
  assets:
    - assets/recipes/
    - assets/images/recipes/
```

12. **Data Models (Dart):**
   - `Recipe`: id, title, categories[], servings, offerIngredients[], extraIngredients[], instructions, imagePath
   - `OfferIngredient`: offerId, name, brand, unit, packSize, packsUsed, usedAmount, priceEur, priceBeforeEur
   - `ExtraIngredient`: name, amount, unit
   - `BasicIngredient`: name, amount, unit

13. **Data Source:**
   - Lade Rezepte aus `assets/recipes/<market>/<market>_recipes.json`
   - JSON-Parsing: Async (compute/isolate) oder FutureBuilder
   - Caching: Pro Markt einmal laden
   - Fallback: Empty State UI wenn Datei fehlt

14. **Recipe Detail UI:**
   - AppBar: Zurück-Button + Rezept-Titel
   - Hero Image: Aus `assets/images/recipes/<market>/<recipe_id>.png`
   - Category Chips: Anzeige aller Categories
   - Servings Stepper: +/- Buttons
   - Section 1: "Angebotszutaten" (offerIngredients)
     - Zeige: Name, Menge, Preis, Angebotspreis
     - Portion-Skalierung: `used_amount * (current_servings / original_servings)`
     - `packs_used` bleibt original, Hinweis: "Packungen gemäß Angebot"
   - Section 2: "Extra-Zutaten" (extraIngredients)
     - Zeige: Name, Menge, Einheit
     - Portion-Skalierung: `amount * (current_servings / original_servings)`
   - Section 3: "Basiszutaten" (basicIngredients, optional)
     - Zeige: Name, Menge, Einheit (falls vorhanden)
   - Section 4: "Zubereitung" (instructions)
     - Nummerierte Liste
     - Unterstützt String (durch \n getrennt) oder Array

15. **Portion-Logik:**
   - UI zeigt Servings-Stepper (Standard: original servings)
   - Bei Änderung: Skaliere ALLE Mengen proportional
   - Formel: `scaled_amount = original_amount * (new_servings / original_servings)`
   - `packs_used` bleibt unverändert (Hinweis anzeigen)

### PHASE 5: VALIDIERUNG UND TESTING

16. **Strict-Mode:**
   - Abort bei: Duplikate IDs, ungültige IDs, fehlende Pflichtfelder
   - Abort bei: Output-Anzahl != Input-Anzahl
   - Klare Fehlermeldungen mit Datei + JSON-Pfad

17. **Non-Strict-Mode:**
   - Überspringe ungültige Rezepte
   - Logge Fehler
   - Zeige Summary: Valid/Invalid Counts

18. **Dry-Run-Modus:**
   - Keine Dateien schreiben
   - Keine Bilder generieren
   - Nur Discovery + Validierung
   - Zeige Report

### BEFEHLE

**Dry-Run (Validierung):**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend none \
  --dry-run \
  --strict
```

**Full-Run (Rezepte + Bilder):**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export REPLICATE_API_TOKEN="r8_..."
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --strict
```

**Nur bestimmte Märkte:**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export REPLICATE_API_TOKEN="r8_..."
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --only "lidl,aldi_nord" \
  --strict
```

**Hinweis:** Auf macOS verwende `python3` (nicht `python`)!

### ERGEBNIS

Nach erfolgreichem Run:
- ✅ `assets/recipes/<market>/<market>_recipes.json` existiert für alle Märkte
- ✅ `assets/images/recipes/<market>/R001.png` etc. existiert für alle Rezepte
- ✅ Flutter-App lädt Rezepte offline
- ✅ Recipe Detail UI zeigt alle Zutaten-Typen korrekt an
- ✅ Portion-Skalierung funktioniert
- ✅ Keine Asset-Fehler
- ✅ Alle Assets in `pubspec.yaml` konfiguriert

### WICHTIGE REGELN

1. ❌ KEINE Rezepte erfinden, ergänzen oder entfernen
2. ✅ Input-Anzahl = Output-Anzahl (STRICT)
3. ✅ ALLE drei Zutatentypen müssen erkannt werden
4. ✅ Bilder MÜSSEN für jedes Rezept generiert werden (außer bei Fehler)
5. ✅ Schema-Normalisierung: Nur Umbenennung, kein neuer Inhalt
6. ✅ Offline-First: Alle Daten lokal gespeichert
7. ✅ Fehlerbehandlung: Klare Meldungen, Retry-Logik
8. ✅ Performance: Async JSON-Parsing, Caching
```

---

## 🎯 QUICK START

### 1. Validierung (Dry-Run)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend none \
  --dry-run \
  --strict
```

### 2. Vollständige Pipeline (Mit Bildern)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export REPLICATE_API_TOKEN="r8_dein_token_hier"
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --strict
```

### 3. Flutter-App testen
```bash
flutter run
# Navigiere zu Recipe Detail Screen
# Prüfe: Alle Zutaten-Typen sichtbar, Portion-Skalierung funktioniert
```

---

## ✅ CHECKLIST

- [ ] Pipeline erkennt alle Märkte in `assets/prospekte/`
- [ ] Pipeline erkennt alle Rezepte (keine erfunden)
- [ ] Pipeline erkennt alle drei Zutatentypen
- [ ] Bilder werden für alle Rezepte generiert
- [ ] Rezepte werden in `assets/recipes/` gespeichert
- [ ] Bilder werden in `assets/images/recipes/` gespeichert
- [ ] `pubspec.yaml` enthält alle Asset-Pfade
- [ ] Flutter-App lädt Rezepte korrekt
- [ ] Recipe Detail UI zeigt alle Zutaten-Typen
- [ ] Portion-Skalierung funktioniert
- [ ] Keine Asset-Fehler in Flutter-App

---

## 📝 NOTES

- **Strict-Mode**: Verhindert falsche Daten, abortet bei Fehlern
- **Dry-Run**: Testet ohne Änderungen
- **Rate Limiting**: Replicate API hat Limits, Throttling empfohlen
- **Offline-First**: Alle Daten lokal, App funktioniert ohne Internet
- **Schema-Adapter**: Normalisiert verschiedene Input-Formate

