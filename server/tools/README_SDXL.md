# 🎨 SDXL Food Photography Pipeline - README

## ⚡ Schnellstart

### 1. Setup (Einmalig)

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Option A: Mit Run-Script (Empfohlen - erstellt automatisch Virtual Environment)
./server/tools/run_sdxl.sh aldi_nord 5

# Option B: Manuell
python3 -m venv .venv_sdxl
source .venv_sdxl/bin/activate
pip install replicate requests pillow python-dotenv
export REPLICATE_API_TOKEN="r8_..."
```

### 2. Test

```bash
# Test mit 5 Rezepten (überspringt vorhandene)
./server/tools/run_sdxl.sh aldi_nord 5

# Test mit 5 Rezepten (überschreibt vorhandene)
./server/tools/run_sdxl.sh aldi_nord 5 force
```

### 3. Produktion

```bash
# Alle Rezepte (überspringt vorhandene)
./server/tools/run_sdxl.sh aldi_nord

# Alle Rezepte (überschreibt vorhandene - NEU generieren)
./server/tools/run_sdxl.sh aldi_nord 0 force
```

---

## 📋 Commands Übersicht

### Run-Script

```bash
./server/tools/run_sdxl.sh [RETAILER] [LIMIT] [FORCE]
```

**Parameter:**
- `RETAILER`: Supermarkt (z.B. `aldi_nord`, `kaufland`, `nahkauf`)
- `LIMIT`: Maximale Anzahl Rezepte (optional, `0` = alle)
- `FORCE`: `force` = überschreibt vorhandene Bilder (optional)

**Beispiele:**
```bash
./server/tools/run_sdxl.sh aldi_nord 5          # 5 Rezepte, skip existing
./server/tools/run_sdxl.sh aldi_nord 5 force    # 5 Rezepte, force
./server/tools/run_sdxl.sh aldi_nord            # Alle Rezepte, skip existing
./server/tools/run_sdxl.sh aldi_nord 0 force    # Alle Rezepte, force
```

### Direkt mit Python

```bash
# Virtual Environment aktivieren
source .venv_sdxl/bin/activate

# Test
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --limit 5 \
    --no-skip-existing

# Produktion
python server/tools/generate_recipe_images_sdxl.py \
    --retailer aldi_nord \
    --skip-existing
```

---

## 🔧 Virtual Environment (PEP 668)

macOS Python 3.14+ verwendet PEP 668 (externally-managed-environment).

**Lösung:** Virtual Environment wird automatisch erstellt:
- Erstellt: `.venv_sdxl/`
- Aktiviert automatisch im Run-Script
- Dependencies werden isoliert installiert

**Manuell aktivieren:**
```bash
source .venv_sdxl/bin/activate
```

**Deaktivieren:**
```bash
deactivate
```

---

## ⚙️ Konfiguration

### Replicate API Token

```bash
# Für aktuelle Session
export REPLICATE_API_TOKEN="r8_..."

# Permanent (hinzufügen zu ~/.zshrc)
echo 'export REPLICATE_API_TOKEN="r8_..."' >> ~/.zshrc
source ~/.zshrc
```

### Modelle

**Replicate API (Empfohlen für macOS):**
- Kein Setup nötig
- Funktioniert auf allen Macs (auch M1/M2/M3)
- Günstig (~$0.004/Bild)

**Lokale GPU (Nur für NVIDIA):**
- Benötigt CUDA
- Nicht für Mac M1/M2/M3

---

## 📊 Output

**Struktur:**
```
server/media/recipe_images/
├── aldi_nord/
│   ├── R001.webp
│   ├── R002.webp
│   └── _stats_20250105_120000.json
└── ...
```

**Statistik-Datei:**
- Enthält Verarbeitungs-Statistiken
- Wird automatisch generiert

---

## 🐛 Troubleshooting

### "externally-managed-environment"

✅ **Gelöst:** Virtual Environment wird automatisch erstellt vom Run-Script.

### "Alle Bilder übersprungen"

✅ **Lösung:** Nutze Force-Modus:
```bash
./server/tools/run_sdxl.sh aldi_nord 5 force
```

### "REPLICATE_API_TOKEN nicht gesetzt"

```bash
export REPLICATE_API_TOKEN="r8_..."
```

### "command not found: python3"

```bash
brew install python3
```

---

## 📖 Weitere Dokumentation

- `SDXL_SETUP_GUIDE.md` - Vollständige Setup-Anleitung
- `SDXL_PROMPT_REFERENCE.md` - Prompt-Referenz
- `QUICK_START_SDXL.md` - 5-Minuten Quick-Start
- `INSTALL_MACOS.md` - macOS-spezifische Installation

---

**Erstellt:** 2025-01-05  
**Version:** 1.0.0
