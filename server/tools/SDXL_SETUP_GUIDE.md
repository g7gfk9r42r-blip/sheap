# 🎨 SDXL Food Photography Pipeline - Setup Guide

## 📋 Übersicht

Diese Pipeline generiert hochwertige Food-Photography Bilder für Rezepte mit Stable Diffusion XL.

---

## 🔧 Installation

### Option 1: Lokal (GPU erforderlich)

```bash
# Python 3.10+ erforderlich
pip install torch torchvision --index-url https://download.pytorch.org/whl/cu118
pip install diffusers transformers accelerate safetensors
pip install pillow pillow-simd  # Für Bildverarbeitung
pip install realesrgan  # Für Upscaling (optional)
```

**GPU-Anforderungen:**
- NVIDIA RTX 4070 oder besser (12GB+ VRAM empfohlen)
- CUDA 11.8+ oder CUDA 12.1+
- ~24GB VRAM für SDXL Base + Refiner

### Option 2: Cloud (RunPod / Vast.ai)

**RunPod Setup:**
1. Erstelle Pod mit `stable-diffusion-xl` Template
2. SSH ins Pod
3. Installiere Dependencies wie oben

**Vast.ai Setup:**
1. Suche nach GPU mit 24GB+ VRAM
2. Starte Container mit PyTorch Image
3. Installiere Dependencies

### Option 3: Replicate API (kostengünstig, kein Setup)

```bash
pip install replicate requests pillow python-dotenv
```

Setze Environment Variable:
```bash
export REPLICATE_API_TOKEN="r8_..."
```

---

## 🚀 Verwendung

### Einzelner Supermarkt

```bash
# Generiere alle Bilder für Aldi Nord
python server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord

# Mit Limit (für Tests)
python server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord --limit 5

# Ohne Refiner (schneller)
python server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord --no-refiner

# Ohne Upscaling (schneller)
python server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord --no-upscale

# Custom Dimensionen
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --width 1024 \
    --height 1024 \
    --final-width 4096 \
    --final-height 4096
```

### Batch-Verarbeitung (alle Supermärkte)

```bash
# Erstelle Batch-Script
cat > batch_generate.sh << 'EOF'
#!/bin/bash

RETAILERS=(
    "aldi_nord"
    "aldi_sued"
    "kaufland"
    "lidl"
    "rewe"
    "penny"
    "netto"
    "norma"
    "nahkauf"
    "tegut"
    "denns"
    "biomarkt"
)

for retailer in "${RETAILERS[@]}"; do
    echo "🛒 Processing $retailer..."
    python server/tools/generate_recipe_images_sdxl.py \
        --retailer "$retailer" \
        --skip-existing
    echo ""
done
EOF

chmod +x batch_generate.sh
./batch_generate.sh
```

---

## 🎨 Modell-Empfehlungen

### Option 1: SDXL Base + Refiner (Beste Qualität)

```python
SDXL_MODEL_ID = "stabilityai/stable-diffusion-xl-base-1.0"
SDXL_REFINER_ID = "stabilityai/stable-diffusion-xl-refiner-1.0"
```

**Vorteile:**
- ✅ Höchste Qualität (~95% Midjourney-Niveau)
- ✅ Beste Farben und Details
- ✅ Apple Store-tauglich

**Nachteile:**
- ⚠️ Langsam (~30-60 Sek/Bild mit GPU)
- ⚠️ Benötigt 24GB+ VRAM
- ⚠️ Höhere Kosten in Cloud

### Option 2: SSD-1B (Schneller, Geringere VRAM)

```python
SDXL_MODEL_ID = "segmind/SSD-1B"
SDXL_REFINER_ID = None
```

**Vorteile:**
- ✅ 50% schneller
- ✅ Nur 8GB VRAM nötig
- ✅ ~90% SDXL-Qualität

**Nachteile:**
- ⚠️ Etwas niedrigere Qualität
- ⚠️ Weniger Details

### Option 3: Replicate API (Kein Setup, Kostengünstig)

```python
# Nutzt Cloud-Infrastruktur
# ~$0.004 pro Bild
# Kein Setup nötig
```

**Vorteile:**
- ✅ Kein Setup
- ✅ Skalierbar
- ✅ Keine GPU nötig

**Nachteile:**
- ⚠️ Kosten pro Bild (~$0.004)
- ⚠️ API-Rate-Limits
- ⚠️ Abhängig von Internet

---

## ⚙️ Empfohlene Parameter

### SDXL Base + Refiner

```python
SAMPLER = "DPM++ 2M Karras"
STEPS = 30
CFG_SCALE = 7.0
REFINER_STRENGTH = 0.3
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048  # oder 4096x4096 für Apple Review
```

### SSD-1B (ohne Refiner)

```python
SAMPLER = "DPM++ 2M Karras"
STEPS = 25
CFG_SCALE = 7.0
REFINER_STRENGTH = None
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048
```

---

## 📊 Performance

### Lokal (RTX 4090)

- **SDXL Base + Refiner:** ~45 Sek/Bild
- **SSD-1B:** ~20 Sek/Bild
- **Batch-Processing:** ~600-800 Bilder/Tag möglich

### Cloud (RunPod A6000)

- **SDXL Base + Refiner:** ~60 Sek/Bild
- **Kosten:** ~$0.50/Stunde
- **Batch-Processing:** ~500 Bilder/Tag

### Replicate API

- **Generierung:** ~30-60 Sek/Bild
- **Kosten:** ~$0.004/Bild
- **600 Bilder:** ~$2.40

---

## 🎯 Qualitäts-Checkliste

✅ **Vor Produktions-Start prüfen:**

1. **Konsistenz:** Alle Bilder haben einheitlichen Look?
2. **Qualität:** Keine AI-Artefakte (extra Finger, unrealistische Strukturen)?
3. **Licht:** Natürliches Tageslicht, keine künstlichen Schatten?
4. **Komposition:** Professionelles Plating, keine Ablenkungen?
5. **Details:** Scharfe Texturen, appetitliches Aussehen?

**Test-Sample generieren:**
```bash
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --limit 10
```

Dann manuell prüfen, ob Qualität stimmt.

---

## 🔍 Troubleshooting

### Out of Memory (OOM)

```bash
# Verwende kleinere Modelle
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --no-refiner  # Reduziert VRAM um ~40%
```

### Langsame Generierung

```bash
# Verwende SSD-1B statt SDXL
# Oder: Deaktiviere Upscaling
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --no-upscale
```

### API-Rate-Limits (Replicate)

- Implementiere Retry-Logic (bereits im Code)
- Nutze Batch-Processing mit Delays
- Oder: Lokale GPU nutzen

---

## 📁 Output-Struktur

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
3. **Batch-Processing starten** für alle Supermärkte
4. **JSONs aktualisieren** mit `heroImageUrl` Pfaden

**Automatisches JSON-Update:**
```python
# TODO: Script zum automatischen Update von heroImageUrl in recipes JSON
```

---

## 🎓 Weitere Optimierungen

### LoRA Training (Optional, Advanced)

Trainiere eigenes LoRA für Food-Photography:
- Verbessert Konsistenz
- Reduziert Generierungszeit
- Erhöht Qualität

### Caching / Preprocessing

- Cache Prompts für gleiche Rezepte
- Pre-load Models für Batch-Processing
- Parallel Processing mit Multi-GPU

---

**Erstellt:** 2025-01-05  
**Version:** 1.0.0  
**Status:** Production-Ready ✅

