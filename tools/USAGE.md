# Recipe Generator CLI - Usage Guide

## Quick Start

```bash
# From project root
dart run tools/generate_recipes_for_all_supermarkets.dart
```

## What It Does

1. **Scans** `assets/data/` for offer JSON files matching pattern:
   - `angebote_<supermarket>_<date>.json`
   - Supports both date formats: `20250101` (YYYYMMDD) or `2025-W49` (YYYY-Www)

2. **Loads** offers from each file and groups by supermarket

3. **Generates** 20-50 unique recipes per supermarket using OpenAI GPT-4o-mini

4. **Saves** recipes to `assets/recipes/recipes_<supermarket>.json`

## Requirements

### 1. Environment Setup

Create a `.env` file in the project root:

```bash
echo "OPENAI_API_KEY=sk-your-key-here" > .env
```

### 2. Offer JSON Files

Place offer JSON files in `assets/data/` with the naming pattern:

```
assets/data/angebote_lidl_2025-W49.json
assets/data/angebote_rewe_2025-W49.json
assets/data/angebote_edeka_2025-W49.json
```

The script automatically detects the supermarket name from the filename.

## Output Format

Each supermarket gets a JSON file in `assets/recipes/`:

```json
[
  {
    "title": "Knusprige Hähnchen-Bowl mit Ofengemüse",
    "ingredients": [
      {"name": "Hähnchenbrust", "amount": "250 g"},
      {"name": "Kartoffeln", "amount": "300 g"},
      {"name": "Paprika", "amount": "1 Stück"}
    ],
    "priceEstimate": 4.79,
    "instructions": "Schritte 1–5, klar formuliert...",
    "tags": ["low_budget", "high_protein", "einfach"],
    "supermarket": "LIDL",
    "servings": 2
  }
]
```

## Features

- ✅ Automatic supermarket detection from filenames
- ✅ Batch generation (12 recipes per API call, 20-50 total)
- ✅ Redundancy prevention (title-based filtering)
- ✅ Robust JSON parsing (handles markdown code blocks)
- ✅ Automatic directory creation
- ✅ Detailed logging with `[Grocify]` prefix
- ✅ Error handling (continues on failures)

## Options

```bash
# Verbose output (includes stack traces)
dart run tools/generate_recipes_for_all_supermarkets.dart --verbose
```

## Error Handling

- Empty/unparsable offer files → Supermarket is skipped with warning
- GPT API failures → Error logged, next supermarket continues
- Invalid JSON from GPT → Error logged, batch is skipped
- Script exits with non-zero code only on fatal errors (no API key, no files found)

## Logging

All output is prefixed with `[Grocify]` for easy filtering:

```
[Grocify] Starting recipe generation for all supermarkets...
[Grocify] ✅ Environment loaded
[Grocify] 📥 Scanning for offer JSON files...
[Grocify] 🤖 Generating recipes for LIDL...
[Grocify] ✅ Generated 35 recipes for LIDL
[Grocify] 💾 Saved to assets/recipes/recipes_lidl.json
```

## Integration with Flutter App

The generated recipe files are automatically available in the Flutter app via:

```dart
import 'package:flutter/services.dart';
import 'dart:convert';

final recipesJson = await rootBundle.loadString('assets/recipes/recipes_lidl.json');
final recipes = jsonDecode(recipesJson) as List;
```

The `pubspec.yaml` already includes:
```yaml
flutter:
  assets:
    - assets/recipes/
```

