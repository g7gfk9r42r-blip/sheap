# Projekt-Struktur: Grocify / roman_app

## Directory Tree (Relevant)

```
roman_app/
├── lib/
│   ├── main.dart                          # Entry Point
│   ├── core/
│   │   ├── theme/                         # Theme-Definitionen
│   │   ├── widgets/                       # Wiederverwendbare Widgets
│   │   │   ├── molecules/
│   │   │   │   └── recipe_preview_card.dart  # ⚠️ Image Loading
│   │   │   └── premium/
│   │   └── assets/                        # (neu: AssetIndexService)
│   ├── data/
│   │   ├── models/
│   │   │   └── recipe.dart                # Recipe Model
│   │   ├── repositories/
│   │   │   └── recipe_repository.dart     # ⚠️ Recipe Loading (weekKey!)
│   │   └── services/
│   │       ├── supermarket_recipe_repository.dart  # ⚠️ buildImageSchema (weekKey!)
│   │       └── recipe_api.dart            # HTTP API (Fallback)
│   ├── features/
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── recipes/
│   │   │   └── presentation/
│   │   │       └── recipes_screen.dart
│   │   ├── plan/
│   │   │   └── plan_screen_new.dart
│   │   ├── shopping/
│   │   │   └── shopping_list_screen.dart
│   │   └── profile/
│   │       └── profile_screen_new.dart
│   ├── utils/
│   │   └── week.dart                      # ⚠️ isoWeekKey()
│   └── tools/
│       └── check_recipe_assets.dart       # Asset-Prüfung
│
├── assets/
│   ├── data/                              # Angebots-JSONs
│   ├── recipes/                           # ⚠️ Rezept-JSONs (OHNE weekKey im Filename!)
│   │   ├── recipes_aldi_nord.json
│   │   ├── recipes_aldi_sued.json
│   │   └── ...
│   ├── recipe_images/                     # ⚠️ NEU: OHNE weekKey!
│   │   ├── aldi_nord/
│   │   │   ├── R001.webp
│   │   │   └── R002.webp
│   │   ├── aldi_sued/
│   │   └── _fallback/
│   │       └── placeholder.webp
│   └── index/                             # NEU: Asset-Index
│       └── asset_index.json
│
├── tools/
│   └── build_offline_assets.py            # NEU: Build-Script
│
├── pubspec.yaml                           # ⚠️ Assets-Config
└── .env                                   # Environment-Variablen
```

## Relevante Dateien

### Flutter
- `lib/main.dart` - App Entry Point
- `lib/data/models/recipe.dart` - Recipe Model
- `lib/data/repositories/recipe_repository.dart` - Recipe Loading
- `lib/data/services/supermarket_recipe_repository.dart` - Image Schema Builder
- `lib/core/widgets/molecules/recipe_preview_card.dart` - Image Display
- `lib/utils/week.dart` - Week-Key Utils

### Assets
- `assets/recipes/*.json` - Rezept-Daten (OHNE weekKey im Filename)
- `assets/recipe_images/<market>/<recipe_id>.webp` - Bilder (OHNE weekKey)
- `assets/index/asset_index.json` - Asset-Index

### Build
- `tools/build_offline_assets.py` - Asset-Build-Script
- `pubspec.yaml` - Asset-Registrierung

## Kritische Stellen (WeekKey)

1. `lib/data/services/supermarket_recipe_repository.dart:268` - `weekKey` im Asset-Pfad
2. `lib/data/repositories/recipe_repository.dart:179` - WeekKey wird gesetzt
3. `lib/core/widgets/molecules/recipe_preview_card.dart` - Image Loading mit weekKey-Pfad

