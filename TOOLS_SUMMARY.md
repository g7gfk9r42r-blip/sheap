# Tools Summary

## A) validate_recipes.py

**Funktionalität:**
- Scannt `assets/recipes/*.json` (12 Märkte)
- Validierung:
  - recipes_count: 50-100 pro Markt
  - unique_id_count
  - duplicate_ids
  - missing_required_fields (id, title, retailer, valid_from, servings, categories, ingredients, steps)
  - categories_count >= 3
  - ingredients_count >= 3
- `--fix-ids`: Renumeriert IDs fortlaufend ab R001
- Exit-Code: 0 wenn OK, 2 bei Fehlern

**Usage:**
```bash
python3 tools/validate_recipes.py
python3 tools/validate_recipes.py --fix-ids
python3 tools/validate_recipes.py --market aldi_nord
```

## B) build_offline_assets.py

**Funktionalität:**
- Quelle: NUR `assets/recipes/` und `assets/recipe_images/` (OFFLINE MODE)
- Generiert `assets/index/asset_index.json`:
  ```json
  {
    "recipes": {
      "aldi_nord": {
        "count": 60,
        "recipe_ids": ["R001", "R002", ...]
      }
    },
    "recipe_images": {
      "aldi_nord": ["R001", "R002", ...]
    }
  }
  ```
- Schreibt `tools/build_report.md` (Summary + pro Market)
- `--fill-missing-with-placeholder`: Kopiert Placeholder für fehlende Bilder

**Usage:**
```bash
python3 tools/build_offline_assets.py
python3 tools/build_offline_assets.py --fill-missing-with-placeholder
```

## C) switch_week.sh

**Funktionalität:**
- Erwartet Week-Ordner: `weekly/<YYYY-W##>/` mit 12 JSON-Files
- Kopiert JSONs nach `assets/recipes/recipes_<market_slug>.json`
- Führt `validate_recipes.py` aus (bricht bei Fehler ab)
- Führt `build_offline_assets.py` aus (mit Placeholder-Fill)
- Ausgabe: Tabelle mit market_slug | recipes_count | missing_images_count

**Usage:**
```bash
./tools/switch_week.sh 2026-W01
./tools/switch_week.sh  # Nur Validate + Build (gegen aktuelle assets)
```

## D) Flutter Code

**Rezeptanzahl:**
- `RecipeRepository.getRecipeCountForMarket(retailer)` - Gecacht
- `RecipeRepository.preloadRecipeCounts()` - Preload im Hintergrund
- `AssetIndexService.getRecipeCount(market)` - Aus Index

**Image Fallback:**
- `AssetIndexService.recipeImagePathOrFallback(market, recipeId)`
- Fallback-Kette: Asset → Placeholder → Emoji (NIEMALS Exception!)

**Files:**
- `lib/data/repositories/recipe_repository.dart` - Recipe Count Caching
- `lib/core/assets/asset_index_service.dart` - Asset-Index Service
- `lib/core/widgets/molecules/recipe_preview_card.dart` - Image Loading
- `lib/core/widgets/premium/supermarket_card.dart` - Rezeptanzahl Anzeige
