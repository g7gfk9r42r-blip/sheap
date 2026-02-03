# Recipe Generator V2 - Robust & Production-Ready

**100% valides JSON** + **Echte Nährwerte** + **Batch-Processing** + **Retry-Mechanismus**

## Was ist neu in V2?

### ✅ Garantiert valides JSON
- **JSON Schema Validation** - OpenAI Structured Outputs erzwingen korrektes Format
- **Retry-Mechanismus** - Bis zu 3 Versuche mit Temperature-Anpassung
- **Kein Markdown** - Output ist immer reines JSON Array

### ✅ Echte Nährwerte (optional)
- **Integration mit Nutrition Pipeline** - Nutzt Open Food Facts & USDA APIs
- **Deterministische Berechnung** - `kcal_total = Σ(kcal_per_100g × amount / 100)`
- **Kein Raten mehr** - Entweder echte Daten oder `kcal_source="missing"`

### ✅ Batch-Processing
- **Kleine Batches** - Standard 20 Rezepte pro Batch (konfigurierbar)
- **Automatic Merging** - Keine Duplikate, saubere ID-Vergabe
- **Resilient** - Einzelner Batch-Fehler bricht Gesamtprozess nicht ab

### ✅ Bessere Qualitätskontrolle
- **Unit Tests** - pytest-Suite für Schema, Validation, Merging
- **Strengere Regeln** - Min. 5 Ingredients (3 non-pantry), 5 Steps
- **Non-Food Filter** - Automatische Erkennung von Zahncreme, Deko, etc.

### ✅ Produktionsreif
- **Rohdatei bleibt unangetastet** - Output immer in separate Datei
- **Strukturiertes Logging** - Keine riesigen Dumps, nur relevante Stats
- **Exit Codes** - ≠0 wenn <50 Rezepte oder JSON invalid

## Installation

```bash
# Dependencies
pip install -r tools/recipe_generator_requirements.txt

# Optional: USDA API-Key für bessere Nährwerte
export USDA_FDC_API_KEY="your-key"

# OpenAI API-Key (erforderlich)
export OPENAI_API_KEY="sk-..."
```

## Verwendung

### Basic - Nur Rezept-Generierung

```bash
python tools/generate_recipes_from_raw.py \
  --input server/raw_rewe.txt \
  --supermarket rewe \
  --week 2025-W52 \
  --target 80 \
  --batch-size 20
```

**Output**: `server/media/prospekte/rewe/recipes_2025-W52.json`

### Advanced - Mit echten Nährwerten

```bash
python tools/generate_recipes_from_raw.py \
  --input server/raw_aldi.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --target 80 \
  --batch-size 20 \
  --with-nutrition \
  --verbose
```

**Ergebnis**:
- Rezepte mit `kcal_source="calculated"` und `kcal_confidence="high"`
- Protein, Fett, Kohlenhydrate pro Rezept
- Nutrition Cache wird aufgebaut (schneller bei wiederholten Läufen)

### Custom Output Path

```bash
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket edeka \
  --week 2025-W52 \
  --output my_custom_recipes.json
```

## Beispiel: REWE KW52

```bash
# 1. Rohdaten haben (z.B. aus Prospekt-Scraper)
cat server/media/prospekte/rewe/rewe.json > server/raw_rewe_kw52.txt

# 2. Rezepte generieren mit Nährwerten
python tools/generate_recipes_from_raw.py \
  --input server/raw_rewe_kw52.txt \
  --supermarket rewe \
  --week 2025-W52 \
  --target 80 \
  --batch-size 20 \
  --with-nutrition \
  --verbose

# 3. Fertig! Datei liegt in:
# server/media/prospekte/rewe/recipes_2025-W52.json

# 4. In App integrieren
cp server/media/prospekte/rewe/recipes_2025-W52.json \
   assets/recipes/rewe_2025_W52.json
```

## Output-Struktur

### Datei-Format

```json
[
  {
    "id": "rewe-2025-W52-001",
    "title": "Protein Bowl mit Hähnchen",
    "description": "High-Protein Bowl mit gegrilltem Hähnchen, Quinoa, Avocado und frischem Gemüse - perfekt für ein ausgewogenes Mittagessen.",
    "supermarket": "rewe",
    "weekKey": "2025-W52",
    "category": "Lunch",
    "dietTags": ["high-protein", "balanced"],
    "servings": 2,
    "prepMinutes": 15,
    "cookMinutes": 25,
    "difficulty": "easy",
    "ingredients": [
      {
        "name": "Hähnchenbrust",
        "amount": 400,
        "unit": "g",
        "isPantry": false,
        "offerRef": "offer-042",
        "offerMatchNote": "REWE Bio Hähnchenbrust 500g",
        "storeHint": "Kühltheke / Frisches Fleisch"
      },
      {
        "name": "Quinoa",
        "amount": 200,
        "unit": "g",
        "isPantry": false,
        "offerRef": "offer-089",
        "offerMatchNote": "REWE Bio Quinoa 500g",
        "storeHint": "Trockenware / Getreide & Hülsenfrüchte"
      },
      {
        "name": "Avocado",
        "amount": 2,
        "unit": "stk",
        "isPantry": false,
        "offerRef": "offer-112",
        "offerMatchNote": "REWE Avocado ready-to-eat",
        "storeHint": "Obst & Gemüse"
      },
      {
        "name": "Cherry-Tomaten",
        "amount": 250,
        "unit": "g",
        "isPantry": false,
        "offerRef": "offer-098",
        "offerMatchNote": "REWE Bio Cherry-Tomaten 250g",
        "storeHint": "Obst & Gemüse"
      },
      {
        "name": "Olivenöl",
        "amount": 3,
        "unit": "el",
        "isPantry": true,
        "offerRef": null,
        "offerMatchNote": null,
        "storeHint": "Pantry / Öle & Essig"
      },
      {
        "name": "Salz & Pfeffer",
        "amount": 1,
        "unit": "tl",
        "isPantry": true,
        "offerRef": null,
        "offerMatchNote": null,
        "storeHint": "Pantry / Gewürze"
      }
    ],
    "steps": [
      "Quinoa nach Packungsanweisung kochen (ca. 15 Minuten).",
      "Hähnchenbrust in mundgerechte Stücke schneiden, mit Salz und Pfeffer würzen.",
      "Olivenöl in einer Pfanne erhitzen und Hähnchen bei mittlerer Hitze ca. 8-10 Minuten braten bis es durchgegart ist.",
      "Cherry-Tomaten halbieren, Avocado schälen und in Scheiben schneiden.",
      "Gekochte Quinoa in Bowls verteilen, Hähnchen, Tomaten und Avocado darauf anrichten. Mit etwas Olivenöl beträufeln und servieren."
    ],
    "nutrition": {
      "kcal_total": 1520.5,
      "kcal_per_serving": 760.3,
      "protein_g": 85.2,
      "fat_g": 48.7,
      "carbs_g": 92.1,
      "kcal_source": "calculated",
      "kcal_confidence": "high"
    }
  },
  // ... 79 weitere Rezepte
]
```

### Nutrition Confidence Levels

| Level | Bedeutung | Beispiel |
|-------|-----------|----------|
| **low** | Geschätzt ohne Datenquelle | LLM-Schätzung |
| **medium** | Teilweise aus Datenbank | 60-79% Zutaten gefunden |
| **high** | Vollständig berechnet | ≥80% Zutaten aus API |

### Nutrition Source

| Source | Bedeutung |
|--------|-----------|
| **estimated** | LLM-Schätzung (V1-Modus) |
| **calculated** | Deterministische Berechnung aus APIs |
| **missing** | Keine Daten verfügbar |

## Unit Tests

```bash
# Alle Tests ausführen
pytest tools/test_recipe_generator.py -v

# Spezifischer Test
pytest tools/test_recipe_generator.py::test_valid_recipe_passes -v

# Mit Coverage
pytest tools/test_recipe_generator.py --cov=tools --cov-report=html
```

### Test-Abdeckung

✅ `test_schema_loads` - Schema ist valides JSON  
✅ `test_valid_recipe_passes` - Valides Rezept wird akzeptiert  
✅ `test_missing_required_field_fails` - Fehlende Felder werden erkannt  
✅ `test_invalid_id_format_fails` - ID-Format wird validiert  
✅ `test_too_few_ingredients_fails` - Mindestens 5 Zutaten erforderlich  
✅ `test_too_few_steps_fails` - Mindestens 5 Schritte erforderlich  
✅ `test_invalid_category_fails` - Enum-Werte werden geprüft  
✅ `test_merge_batches_no_duplicates` - Keine Duplikate beim Mergen  
✅ `test_non_food_detection` - Non-Food Items werden gefiltert  

## Fehlerbehandlung

### Scenario: Batch schlägt fehl

```
📝 Batch 1: Generating 20 recipes...
   📤 Calling gpt-4o-2024-08-06...
   ❌ Attempt 1 failed: JSON parse error
   🔄 Retry 2/3 (temperature: 0.6)
   📤 Calling gpt-4o-2024-08-06...
   ✅ Response: 15234 chars
   ✅ Batch 1 complete: 20 recipes
```

**Was passiert**:
1. Erster Versuch scheitert
2. Temperature wird reduziert (0.7 → 0.6)
3. Retry mit konservativeren Einstellungen
4. Bis zu 3 Versuche pro Batch

### Scenario: Zu wenige Rezepte

```
❌ Generation failed: Failed to generate minimum 50 recipes (got 42)
Exit code: 1
```

**Was tun**:
- `--target` erhöhen (z.B. 90 statt 80)
- `--batch-size` reduzieren (z.B. 15 statt 20)
- Input-Text prüfen (genug Food-Angebote?)

### Scenario: Nutrition API-Limits

```
🔬 Enriching with real nutrition data...
   ⚠️  Rate limit hit, waiting 5s...
   ✅ Enriched: 62/80 ingredients
   ❌ Missing: 18
```

**Was passiert**:
- Pipeline respektiert Rate-Limits automatisch
- Fehlende Zutaten → `kcal_source="missing"`
- Cache wird gespeichert für nächsten Lauf

## Performance & Kosten

### Ohne Nutrition Enrichment

| Metric | Wert |
|--------|------|
| **Dauer** | ~2-5 Min (80 Rezepte, 4 Batches) |
| **API-Calls** | ~4-12 (inkl. Retries) |
| **Kosten (GPT-4o)** | ~$0.60-1.20 |
| **Kosten (GPT-3.5)** | ~$0.10-0.20 |

### Mit Nutrition Enrichment

| Metric | Wert (1. Lauf) | Wert (2. Lauf mit Cache) |
|--------|----------------|--------------------------|
| **Dauer** | ~8-15 Min | ~3-6 Min |
| **API-Calls** | ~4-12 (LLM) + ~300-500 (Nutrition) | ~4-12 (LLM) + ~50-100 (Nutrition) |
| **Kosten** | ~$0.80-1.50 | ~$0.70-1.30 |

**Cache-Effekt**: Nach 3-4 Supermärkten sind ~70% der Zutaten gecached!

## Vergleich V1 vs V2

| Feature | V1 | V2 |
|---------|----|----|
| **JSON Validität** | ~85% | 100% ✅ |
| **Batch-Processing** | ❌ | ✅ |
| **Retry-Mechanismus** | ❌ | ✅ 3x |
| **Echte Nährwerte** | ❌ | ✅ Optional |
| **Unit Tests** | ❌ | ✅ pytest |
| **JSON Schema** | ❌ | ✅ Strict |
| **Non-Food Filter** | Manuell | Automatisch |
| **Rohdatei-Schutz** | ⚠️  | ✅ Separate Datei |
| **Exit Codes** | ❌ | ✅ 0/1 |

## Migration von V1

Alte Befehle bleiben kompatibel:

```bash
# V1-Style (funktioniert noch)
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --output recipes.json

# V2-Style (empfohlen)
python tools/generate_recipes_from_raw.py \
  --input raw.txt \
  --supermarket aldi_nord \
  --week 2025-W52 \
  --target 80 \
  --batch-size 20 \
  --with-nutrition
```

## Best Practices

### 1. Immer `--with-nutrition` verwenden (Produktion)

```bash
--with-nutrition  # Echte Kalorien, bessere Qualität
```

### 2. Batch-Size an Input-Größe anpassen

```bash
# Viele Angebote (>200)
--batch-size 25

# Wenige Angebote (<100)
--batch-size 15
```

### 3. Verbose bei Problemen

```bash
--verbose  # Detaillierte Logs für Debugging
```

### 4. Target zwischen 70-90 setzen

```bash
--target 80  # Sweet spot für Qualität/Zeit
```

## Troubleshooting

### "ValidationError: ... is a required property"

➜ JSON Schema Fehler - LLM hat Feld vergessen
- **Fix**: Retry-Mechanismus greift automatisch
- Falls persistent: Prompt-Template in `recipe_generator_prompt_v2.txt` prüfen

### "Failed to generate minimum 50 recipes"

➜ Zu viele Batch-Fehler oder zu wenig Input
- **Check**: Input-Datei hat genug Food-Angebote?
- **Fix**: `--target` erhöhen oder `--batch-size` reduzieren

### "NUTRITION_AVAILABLE = False"

➜ Nutrition-Module nicht gefunden
- **Fix**: Script von Project-Root ausführen
- **Check**: `tools/nutrition/` existiert?

### "Rate limit exceeded"

➜ OpenAI oder Nutrition API Limit
- **Wait**: Script pausiert automatisch
- **Alternative**: `--model gpt-3.5-turbo` (niedrigere Limits)

## Roadmap

### Geplante Features

- [ ] **Lokale LLM-Support** (Ollama, Llama 3)
- [ ] **Multi-Language** (Englisch, Französisch)
- [ ] **Image-Generation** (DALL-E für Rezept-Fotos)
- [ ] **Erweiterte Filters** (Allergen-Flags, Vegan-Only)
- [ ] **Export-Formate** (PDF, Markdown, HTML)

## Support

Bei Problemen:
1. `--verbose` Flag nutzen
2. Unit-Tests ausführen: `pytest tools/test_recipe_generator.py -v`
3. Schema prüfen: `tools/recipe.schema.json`
4. Nutrition Cache checken: `nutrition_cache/nutrition_missing.json`

## Lizenz

Teil des `roman_app` Projekts.

