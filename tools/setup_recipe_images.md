# 🖼️ Recipe Images Setup

## ✅ Implementierung abgeschlossen

Die App nutzt jetzt **Offline-Bilder per Flutter Assets**:

### Struktur
```
assets/recipe_images/
├── aldi_nord/
│   └── <week_key>/
│       └── <id>.webp
├── aldi_sued/
│   └── <week_key>/
│       └── <id>.webp
└── biomarkt/
    └── <week_key>/
        └── <id>.webp
```

### Schema
Jedes Rezept hat jetzt `image` und `image_spec`:
```json
{
  "image": {
    "source": "asset",
    "asset_path": "assets/recipe_images/aldi_nord/2026-W03/R001.webp",
    "status": "ready"
  },
  "image_spec": {
    "source": "stock_candidate",
    "query": "Rezept-Titel"
  }
}
```

### Status
- ✅ 19 Bilder bereits in Assets
- ❌ 371 Bilder fehlen noch

## 🚀 Fehlende Bilder generieren

### Einzelne Retailer
```bash
./server/tools/run_sdxl.sh aldi_nord 0
./server/tools/run_sdxl.sh aldi_sued 0
./server/tools/run_sdxl.sh biomarkt 0
```

### Nach Generierung kopieren
```bash
python3 tools/copy_recipe_images_to_assets.py
```

Das Script kopiert automatisch alle generierten Bilder nach `assets/recipe_images/`.

## 📋 Aktuelle Bilder

Siehe Statistik: `python3 tools/copy_recipe_images_to_assets.py`
