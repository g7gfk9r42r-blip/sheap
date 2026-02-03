# 🚀 SDXL Pipeline - Quick Start

## ⚡ Schnellstart (5 Minuten)

### 1. Dependencies installieren

```bash
# Option A: Lokal mit GPU (empfohlen)
pip install -r server/tools/requirements_sdxl.txt

# Option B: Nur Replicate API (kein Setup)
pip install replicate requests pillow python-dotenv
```

### 2. Environment Variable setzen (nur bei Replicate)

```bash
export REPLICATE_API_TOKEN="r8_..."
```

### 3. Test mit 5 Rezepten

```bash
# Lokal (GPU)
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --limit 5

# Replicate API (Cloud)
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --limit 5
```

### 4. Qualität prüfen

Öffne generierte Bilder in `server/media/recipe_images/aldi_nord/` und prüfe:
- ✅ Konsistenter Look?
- ✅ Keine AI-Artefakte?
- ✅ Appetitlich?

### 5. Produktion starten

```bash
# Alle Rezepte für einen Supermarkt
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --skip-existing

# Batch für alle Supermärkte (siehe SDXL_SETUP_GUIDE.md)
```

---

## 📊 Modell-Optionen

### Option 1: SDXL Base + Refiner (Beste Qualität)
- **Qualität:** ~95% Midjourney
- **Geschwindigkeit:** ~45 Sek/Bild (RTX 4090)
- **VRAM:** 24GB+
- **Kosten:** Lokal (GPU) oder Cloud ($0.50/Stunde)

### Option 2: SSD-1B (Schneller)
- **Qualität:** ~90% SDXL
- **Geschwindigkeit:** ~20 Sek/Bild (RTX 4090)
- **VRAM:** 8GB+
- **Kosten:** Lokal (GPU) oder Cloud ($0.30/Stunde)

### Option 3: Replicate API (Kein Setup)
- **Qualität:** ~95% Midjourney
- **Geschwindigkeit:** ~30-60 Sek/Bild
- **VRAM:** Nicht nötig
- **Kosten:** ~$0.004/Bild (~$2.40 für 600 Bilder)

---

## 🎯 Empfohlene Parameter

```python
# SDXL Base + Refiner
SAMPLER = "DPM++ 2M Karras"
STEPS = 30
CFG_SCALE = 7.0
REFINER_STRENGTH = 0.3
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048  # oder 4096x4096 für Apple Review

# SSD-1B (ohne Refiner)
SAMPLER = "DPM++ 2M Karras"
STEPS = 25
CFG_SCALE = 7.0
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048
```

---

## 🔧 Troubleshooting

### Out of Memory
```bash
# Verwendung kleinerer Modelle
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --no-refiner  # Reduziert VRAM um ~40%
```

### Langsam
```bash
# Upscaling deaktivieren
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --no-upscale
```

### API-Rate-Limits (Replicate)
- Automatische Retries im Code
- Nutze Batch-Processing mit Delays
- Oder: Lokale GPU verwenden

---

## 📁 Output

```
server/media/recipe_images/
├── aldi_nord/
│   ├── R001.webp
│   ├── R002.webp
│   └── _stats_20250105_120000.json
├── kaufland/
│   └── ...
└── ...
```

---

## ✅ Nächste Schritte

1. **Setup testen** mit `--limit 5`
2. **Qualität prüfen** (manuelle Review)
3. **Produktion starten** für alle Supermärkte
4. **JSONs aktualisieren** mit `heroImageUrl` Pfaden

---

**Erstellt:** 2025-01-05  
**Version:** 1.0.0
