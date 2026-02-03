# Weekly Refresh Pipeline - Usage Guide

## Setup

### 1. Stable Diffusion starten

Starte Automatic1111 WebUI lokal:

```bash
# Beispiel: Automatic1111 WebUI sollte auf http://127.0.0.1:7860 laufen
# (Standard-Port)
```

### 2. Dependencies

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
pip3 install requests
```

## Basis-Kommando

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes
```

## Wichtige Flags

### `--force-images`
Regeneriert alle Bilder neu (auch wenn bereits vorhanden):

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --force-images
```

### `--only <markets>`
Nur bestimmte Markets verarbeiten:

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --only aldi_nord,aldi_sued
```

### `--sd-url <url>`
Alternative SD URL (falls nicht localhost:7860):

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --sd-url http://192.168.1.100:7860
```

### `--dry-run`
Test ohne Dateien zu schreiben:

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --dry-run
```

### `--strict`
Exit 1 bei Fehlern:

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --strict
```

## Output-Struktur

Nach dem Run:

```
assets/
├── recipes/
│   ├── recipes_index.json          # Index für Flutter App
│   ├── aldi_nord_recipes.json
│   ├── aldi_sued_recipes.json
│   └── ...
└── images/
    └── recipes/
        ├── aldi_nord/
        │   ├── R001.png
        │   └── R002.png
        └── aldi_sued/
            ├── R001.png
            └── R002.png
```

## Flutter App Integration

### 1. Recipe Loader verwenden

```dart
import 'package:roman_app/features/recipes/data/recipe_loader.dart';

// Alle Rezepte laden
final allRecipes = await RecipeLoader.loadAllRecipes();

// Nur bestimmte Markets
final recipes = await RecipeLoader.loadRecipesForMarkets(['aldi_nord', 'lidl']);

// Index laden
final index = await RecipeLoader.loadIndex();
print('Markets: ${index.markets.length}');
```

### 2. Bild anzeigen

```dart
// Im Recipe Model sollte image_asset enthalten sein:
if (recipe.imageAsset != null) {
  Image.asset(recipe.imageAsset!)
} else {
  // Fallback
  Icon(Icons.fastfood)
}
```

## Beispielausgabe

```
🔄 Weekly Recipe Refresh Pipeline (Offline-First)
============================================================

🔍 Entdecke Markets in assets/prospekte...
   ✅ aldi_nord      : assets/prospekte/aldi_nord/aldi_nord_recipes.json
   ✅ aldi_sued      : assets/prospekte/aldi_sued/aldi_sued_recipes.json
   ✅ lidl           : assets/prospekte/lidl/lidl_recipes.json

📁 3 Market(s) gefunden

📋 Verarbeite aldi_nord...
   Input: assets/prospekte/aldi_nord/aldi_nord_recipes.json
   📚 50 Rezepte geladen
   ✅ 50 valide Rezepte
   ⏭️  Bild übersprungen: R001 (bereits vorhanden)
   ✅ Bild generiert: R002
   ...
   ✅ Gespeichert: aldi_nord_recipes.json

✅ Index erstellt: recipes_index.json

============================================================
📊 REPORT
============================================================

✅ Markets verarbeitet: 3

📚 Rezepte pro Market:
   aldi_nord: geladen=50, valide=50, übersprungen=0, verarbeitet=50
   aldi_sued: geladen=75, valide=75, übersprungen=0, verarbeitet=75
   lidl: geladen=60, valide=60, übersprungen=0, verarbeitet=60

🖼️  Bilder:
   Generiert: 150
   Übersprungen: 35
   Fehlgeschlagen: 0

💾 Dateien geschrieben: 3

============================================================
```

