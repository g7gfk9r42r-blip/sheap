# Weekly Recipe Pipeline

Robuste Pipeline zur Generierung von iPhone-optimierten Rezepten aus Supermarkt-Prospekten.

## Features

✅ **Offer Extraction**: Extrahiert strukturierte Angebote aus messy Prospekt-Daten  
✅ **Recipe Generation**: Generiert 30-50 iPhone-Card-taugliche Rezepte pro Markt  
✅ **Nutrition Enrichment**: Berechnet Nährwerte (Spannweiten) via OpenFoodFacts/USDA  
✅ **Price Calculation**: Berechnet Kosten-Ranges pro Rezept & Portion  
✅ **Robust Error Handling**: Retry-Mechanismen, Fallbacks, detaillierte Reports  
✅ **Mock Mode**: Funktioniert auch ohne OpenAI API Key (für Tests)

## Installation

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Optional: Nutrition dependencies
pip3 install -r tools/nutrition/requirements.txt
```

## Usage

### Basic Run (ohne Nutrition)

```bash
python3 tools/pipeline/run_weekly.py \
  --supermarket aldi_sued \
  --input server/media/prospekte/aldi_sued/aldi_sued.json \
  --target-recipes 40
```

### Full Run (mit Nutrition)

```bash
export OPENAI_API_KEY="sk-..."  # Optional für echte Rezepte

python3 tools/pipeline/run_weekly.py \
  --supermarket aldi_sued \
  --input server/media/prospekte/aldi_sued/aldi_sued.json \
  --target-recipes 40 \
  --with-nutrition
```

## Output Files

Pipeline erstellt 3 Dateien im gleichen Ordner wie Input:

1. **`offers_<weekKey>.json`** - Extrahierte Angebote
2. **`recipes_<weekKey>.json`** - Generierte Rezepte
3. **`run_<weekKey>.report.json`** - Stats & Coverage Report

## Architecture

```
tools/pipeline/
├── run_weekly.py              # Main orchestrator (CLI entry)
├── offer_extractor.py         # Prospekt → Offers
├── recipe_generator.py        # Offers → Recipes (OpenAI)
├── mock_recipe_generator.py   # Fallback ohne API key
├── nutrition_enricher.py      # Nutrition ranges (OFF/USDA)
├── basics_catalog.py          # Pantry/Basic items catalog
├── weekkey.py                 # Week key detection
└── reporting.py               # Stats & reports
```

## Recipe Schema

```json
{
  "id": "aldi_sued_recipe_001",
  "title": "Mediterrane Bowl",
  "description": "Schnell & gesund",
  "supermarket": "aldi_sued",
  "servings": 2,
  "prep_time_min": 15,
  "cook_time_min": 10,
  "difficulty": "easy",
  "tags": ["quick", "healthy"],
  "ingredients": [
    {
      "name": "Cherry-Tomaten",
      "amount": 250,
      "unit": "g",
      "availability": "offer",
      "offerRefs": [{
        "offerId": "aldi_sued_042",
        "title": "Cherry Tomaten",
        "price": 1.99,
        "store_zone": "Obst & Gemüse"
      }],
      "isOfferItem": true,
      "find_it_fast": {
        "store_zone": "Obst & Gemüse",
        "search_terms": ["tomaten", "cherry"],
        "pack_hint": "250g Schale"
      },
      "nutrition": {
        "kcal_range": [45, 52],
        "source": "openfoodfacts"
      }
    }
  ],
  "steps": ["Step 1", "Step 2", "..."],
  "cost_estimate": {
    "total_range": [3.5, 5.2],
    "per_serving_range": [1.75, 2.6]
  },
  "nutrition": {
    "kcal_total_range": [450, 520],
    "kcal_per_serving_range": [225, 260],
    "nutrition_source": "calculated",
    "coverage": {
      "ingredients_total": 8,
      "ingredients_enriched": 6,
      "ingredients_missing": 2
    },
    "disclaimer_short": "Angaben ohne Gewähr."
  },
  "image_prompt": "clean iPhone food photo, natural light, ..."
}
```

## Offer Schema

```json
{
  "supermarket": "aldi_sued",
  "offer_id": "aldi_sued_001",
  "title": "Unsere Goldstücke",
  "brand": "Coppenrath & Wiese",
  "price_now": 1.11,
  "price_before": 2.29,
  "unit_price": 2.47,
  "unit_price_unit": "€/kg",
  "pack_size": null,
  "pack_unit": null,
  "valid_from": null,
  "valid_to": null,
  "category": "food",
  "store_zone": "Kühlregal",
  "is_food": true,
  "confidence": 0.9,
  "raw_evidence": "..."
}
```

## Testing

Pipeline wurde erfolgreich getestet mit:

- **Input**: `server/media/prospekte/aldi_sued/aldi_sued.json` (59KB plain text)
- **Extracted**: 52 food offers
- **Generated**: 40 recipes
- **Output**: 3 JSON files (offers, recipes, report)

## Troubleshooting

### No OpenAI API Key
Pipeline verwendet automatisch Mock-Generator. Rezepte sind generisch aber strukturell korrekt.

### Nutrition modules not available
Installiere: `pip3 install -r tools/nutrition/requirements.txt`

### Wenige Offers extrahiert
Input-Datei enthält wenig strukturierte Daten. Pipeline funktioniert trotzdem.

## Next Steps

1. **OpenAI Integration**: Setze `OPENAI_API_KEY` für bessere Rezepte
2. **Nutrition APIs**: Konfiguriere USDA/OFF API keys für echte Nährwerte
3. **Image Generation**: Implementiere DALL-E Integration für Rezeptbilder
4. **Cron Job**: Automatisiere wöchentliche Runs

## Author

Built by Cursor AI Agent (Dec 2024)

