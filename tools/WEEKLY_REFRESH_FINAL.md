# Weekly Recipe Refresh Pipeline - Finale Implementierung

## ✅ Implementiert

### Python Pipeline (`tools/weekly_refresh.py`)
- ✅ Market Discovery (dynamisch aus `assets/prospekte/`)
- ✅ JSON Load (Array oder `{"recipes": [...]}`)
- ✅ Schema Adapter (`tools/schema_adapter.py`) - normalisiert Feldnamen
- ✅ Validation (strict/non-strict)
- ✅ Output nach `assets/recipes/<market>/<market>_recipes.json`
- ✅ Bildgenerierung (Replicate API oder SD)
- ✅ CLI mit allen Flags
- ✅ Dry-run Support
- ✅ Korrektes Logging (keine erfundenen Rezepte)

### Flutter Integration
- ✅ Recipe Loader (`lib/features/recipes/data/recipe_loader.dart`) - lädt aus `assets/recipes/<market>/`
- ✅ Recipe Model bereits vorhanden mit `offersUsed`, `steps`, `categories`
- ✅ pubspec.yaml enthält `assets/recipes/` und `assets/images/recipes/`

## 📋 Terminal-Kommandos

### 1. Dry Run (Validation only)
```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend none \
  --dry-run \
  --strict
```

### 2. Full Run (Replicate)
```bash
export REPLICATE_API_TOKEN="r8_..."
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend replicate \
  --strict
```

### 3. Nur einen Market testen
```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend none \
  --dry-run \
  --strict \
  --only aldi_nord
```

### 4. Full Run (Stable Diffusion)
```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend sd \
  --sd-url http://127.0.0.1:7860 \
  --strict
```

## 📁 Output-Struktur

Nach dem Run:
```
assets/
├── recipes/
│   ├── aldi_nord/
│   │   └── aldi_nord_recipes.json
│   ├── aldi_sued/
│   │   └── aldi_sued_recipes.json
│   └── ...
└── images/
    └── recipes/
        ├── aldi_nord/
        │   ├── R001.png
        │   ├── R002.png
        │   └── ...
        └── ...
```

## 🔧 Wichtige Hinweise

1. **Output = Input**: Keine Rezepte werden erfunden/entfernt
2. **ID-Format**: Nur R001-R999 erlaubt
3. **Strict Mode**: Abbruch bei Validierungsfehlern
4. **Bilder**: PNG Format (nicht WEBP)
5. **Schema**: Bestehende Struktur wird beibehalten, nur Feldnamen normalisiert

## 🚀 Setup

1. Dependencies installieren:
```bash
pip3 install -r tools/requirements.txt
```

2. API Key setzen (für Replicate):
```bash
export REPLICATE_API_TOKEN="r8_..."
```

3. Pipeline ausführen (siehe Kommandos oben)

4. Flutter Assets aktualisieren:
```bash
flutter clean && flutter pub get
```

## 📝 Schema-Adapter

Der Schema-Adapter normalisiert Feldnamen, erfindet aber keine Inhalte:
- `offerId` → `offer_id`
- `fromOffer` → `from_offer`
- `priceEur` → `price_eur`
- etc.

Bestehende Struktur wird beibehalten, nur Feldnamen werden konsistent gemacht.
