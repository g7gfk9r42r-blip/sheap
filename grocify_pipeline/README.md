# Grocify Pipeline - Weekly Supermarket Recipe Generation

End-to-end automated pipeline that transforms raw supermarket prospekt data into iPhone-ready recipes with nutrition data and images.

## Overview

This pipeline processes weekly supermarket flyers ("Prospekte") and generates:
- ✅ Structured offer extractions (JSON)
- ✅ Nutrition-enriched offers (USDA + OpenFoodFacts)
- ✅ AI-generated recipes (OpenAI GPT)
- ✅ Recipe images (OpenAI DALL-E)
- ✅ Complete audit trail and error reports

## Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Set up environment variables
cat > .env << EOF
OPENAI_API_KEY=sk-...
USDA_API_KEY=your-key-here  # Optional but recommended
OPENAI_MODEL_RECIPES=gpt-4o-mini
OPENAI_MODEL_IMAGES=dall-e-3
EOF

# 3. Ensure input data exists
# Place raw prospekt JSONs in: Prospekte/<market>/<market>.json
# Example: Prospekte/aldi_sued/aldi_sued.json

# 4. Run pipeline for current week, all markets
python run_weekly.py

# 5. Run pipeline for specific market and week
python run_weekly.py --weekKey 2025-W52 --markets aldi_sued --recipes 75

# 6. Run with image generation
python run_weekly.py --markets rewe --recipes 80 --images --verbose
```

## Project Structure

```
grocify_pipeline/
├── Prospekte/              # INPUT: Raw prospekt JSONs (user-provided)
│   ├── aldi_sued/
│   │   └── aldi_sued.json
│   ├── rewe/
│   │   └── rewe.json
│   └── ...
├── output/                 # OUTPUT: All generated files
│   ├── offers/
│   │   └── <market>/
│   │       ├── offers_<weekKey>.json
│   │       └── offers_<weekKey>_enriched.json
│   ├── recipes/
│   │   └── <market>/
│   │       ├── recipes_<market>_<weekKey>_part1.json
│   │       └── recipes_<market>_<weekKey>.json
│   ├── images/
│   │   └── <market>/
│   │       ├── <recipeId>.webp
│   │       └── images_manifest_<weekKey>.json
│   └── reports/
│       └── run_report_<weekKey>.json
├── cache/
│   ├── nutrition_cache.json
│   └── nutrition_missing.json
├── config/
│   └── markets.json        # Market configuration
├── src/                    # Source code
│   ├── utils/              # Utilities
│   ├── offers/             # Offer extraction
│   ├── nutrition/          # Nutrition enrichment
│   ├── recipes/            # Recipe generation
│   └── images/             # Image generation
├── run_weekly.py           # Main orchestrator
├── requirements.txt
└── README.md
```

## Pipeline Stages

### Stage 1: Extract Offers

Extracts structured offers from raw JSON using regex + LLM classification.

**Input:** `Prospekte/<market>/<market>.json`  
**Output:** `output/offers/<market>/offers_<weekKey>.json`

Features:
- Price extraction with discount detection
- Brand and packaging info extraction
- Food/non-food classification
- Deduplication
- Confidence scoring

### Stage 2: Enrich Nutrition

Adds nutrition data (calories, macros) from USDA and OpenFoodFacts APIs.

**Input:** `output/offers/<market>/offers_<weekKey>.json`  
**Output:** `output/offers/<market>/offers_<weekKey>_enriched.json`

Features:
- Multi-source nutrition lookup (USDA + OFF)
- Persistent caching to minimize API calls
- Missing ingredient tracking
- Coverage statistics

### Stage 3: Generate Recipes

Generates iPhone-ready recipes using OpenAI with batch processing.

**Input:** `output/offers/<market>/offers_<weekKey>_enriched.json`  
**Output:** `output/recipes/<market>/recipes_<market>_<weekKey>.json`

Features:
- Batch generation (20-25 recipes per API call)
- JSON schema validation
- Automatic retry on failure
- Offer reference linking
- Nutrition calculation from ingredients

### Stage 4: Generate Images (Optional)

Creates appetizing recipe images using DALL-E.

**Input:** `output/recipes/<market>/recipes_<market>_<weekKey>.json`  
**Output:** `output/images/<market>/<recipeId>.webp`

Features:
- Professional food photography prompts
- WebP conversion for optimal size
- Image manifest for batch management
- Graceful failure handling

## Usage Examples

### Process Single Market

```bash
python run_weekly.py --markets aldi_sued --recipes 75
```

### Process Multiple Markets

```bash
python run_weekly.py --markets "aldi_sued,rewe,edeka" --recipes 80
```

### Specific Week

```bash
python run_weekly.py --weekKey 2025-W52 --markets all
```

### With Images

```bash
python run_weekly.py --markets rewe --images --verbose
```

### Custom Recipe Count

```bash
python run_weekly.py --markets lidl --recipes 100
```

## Error Handling

The pipeline implements robust error handling:

### Retry Mechanism
- Each stage retries up to 2 times on failure
- Exponential backoff for API rate limits
- Individual stage failures don't halt entire pipeline

### Run Reports
Every run generates a detailed report at `output/reports/run_report_<weekKey>.json`:

```json
{
  "weekkey": "2025-W52",
  "started_at": "2025-12-22T10:00:00",
  "finished_at": "2025-12-22T10:45:00",
  "markets": {
    "aldi_sued": {
      "status": "success",
      "stages": {
        "extract_offers": {
          "status": "success",
          "offers_count": 247
        },
        "enrich_nutrition": {
          "status": "success",
          "total": 247,
          "enriched": 198,
          "missing": 49,
          "coverage": 0.80
        },
        "generate_recipes": {
          "status": "success",
          "total_generated": 75,
          "batches": 4
        }
      }
    }
  },
  "summary": {
    "total_markets": 1,
    "successful": 1,
    "failed": 0
  }
}
```

### Exit Codes
- `0`: Success
- `1`: One or more markets failed

## Configuration

### Markets

Edit `config/markets.json` to enable/disable markets:

```json
{
  "markets": [
    {"id": "rewe", "name": "REWE", "enabled": true},
    {"id": "aldi_sued", "name": "ALDI Süd", "enabled": false}
  ]
}
```

### Environment Variables

Required:
- `OPENAI_API_KEY`: OpenAI API key for recipe generation and images

Optional:
- `USDA_API_KEY`: USDA FoodData Central API key (improves nutrition coverage)
- `OPENAI_MODEL_RECIPES`: Model for recipes (default: `gpt-4o-mini`)
- `OPENAI_MODEL_IMAGES`: Model for images (default: `dall-e-3`)

## Output Examples

### Offer

```json
{
  "offerId": "aldi_sued-2025-W52-001",
  "supermarket": "aldi_sued",
  "title": "EHRMANN Grand Dessert",
  "brand": "EHRMANN",
  "price_now": 0.44,
  "price_before": 1.19,
  "discount_percent": 63,
  "is_food": true,
  "confidence": 0.9,
  "nutrition": {
    "name": "Yogurt dessert",
    "kcal_per_100g": 125.0,
    "protein_g": 3.2,
    "fat_g": 4.1,
    "carbs_g": 18.5,
    "source": "openfoodfacts"
  }
}
```

### Recipe

```json
{
  "id": "aldi_sued-01",
  "title": "Mediterrane Pasta Bowl",
  "description": "Frische Pasta mit Tomaten, Mozzarella und Basilikum - schnell und lecker",
  "supermarket": "aldi_sued",
  "servings": 2,
  "time_total_min": 25,
  "difficulty": "easy",
  "tags": ["quick", "vegetarian", "budget"],
  "ingredients": [
    {
      "name": "Pasta",
      "amount": 250,
      "unit": "g",
      "offerRefs": [
        {
          "offerId": "aldi_sued-2025-W52-042",
          "brand": "Combino",
          "price_now": 0.79
        }
      ]
    }
  ],
  "steps": [
    "Pasta nach Packungsanweisung kochen",
    "Tomaten waschen und halbieren",
    "..."
  ],
  "nutrition": {
    "kcal_total": 850,
    "kcal_per_serving": 425,
    "protein_g": 28,
    "fat_g": 12,
    "carbs_g": 65,
    "kcal_source": "calculated",
    "kcal_confidence": "high",
    "coverage": {
      "ingredients_total": 5,
      "ingredients_enriched": 5,
      "ingredients_missing": 0
    }
  },
  "image": {
    "localPath": "output/images/aldi_sued/aldi_sued-01.webp"
  }
}
```

## Performance

Typical run times (single market):
- Offer extraction: ~30 seconds
- Nutrition enrichment: ~2 minutes (first run), ~30 seconds (cached)
- Recipe generation (75 recipes): ~3-5 minutes
- Image generation (75 images): ~15-20 minutes

## Costs (Approximate)

Per market per week:
- Recipe generation (GPT-4o-mini, 75 recipes): ~$0.50
- Image generation (DALL-E 3, 75 images): ~$3.75
- Nutrition APIs (USDA + OFF): Free

**Total: ~$4.25 per market per week**

## Troubleshooting

### "Input file not found"
Ensure raw prospekt JSON exists at `Prospekte/<market>/<market>.json`

### "OPENAI_API_KEY not set"
Create `.env` file or set environment variable

### Low nutrition coverage
- Set `USDA_API_KEY` for better coverage
- Check `cache/nutrition_missing.json` for missing items

### Image generation fails
- Verify DALL-E 3 access on your OpenAI account
- Check API quota/billing
- Images are optional - pipeline continues without them

### Invalid JSON from GPT
- Pipeline auto-retries with repair attempts
- Check `output/reports/run_report_*.json` for details
- Consider using `gpt-4o` for more reliable JSON output

## Development

Run tests:
```bash
python -m pytest tests/
```

Validate pipeline without API calls:
```bash
# Dry run mode (TODO)
python run_weekly.py --dry-run --markets aldi_sued
```

## License

Proprietary - Part of Grocify project

## Support

For issues or questions, check the run reports in `output/reports/` for detailed error information.

