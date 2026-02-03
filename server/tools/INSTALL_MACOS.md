# 🍎 macOS Installation Guide

## Python Setup

### Option 1: Homebrew (Empfohlen)

```bash
# Homebrew installieren (falls nicht vorhanden)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Python installieren
brew install python3

# Prüfe Installation
python3 --version  # Sollte 3.10+ sein
pip3 --version
```

### Option 2: Python.org Installer

1. Lade Python 3.10+ von https://www.python.org/downloads/
2. Installiere .pkg Datei
3. Öffne Terminal und prüfe:
   ```bash
   python3 --version
   pip3 --version
   ```

---

## Dependencies installieren

### Option 1: Replicate API (Empfohlen, kein Setup)

```bash
# Wechsel ins Projekt-Verzeichnis
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Installiere nur Replicate (kein GPU nötig)
pip3 install replicate requests pillow python-dotenv

# Setze API Token
export REPLICATE_API_TOKEN="r8_..."
# Oder: Füge zu ~/.zshrc hinzu:
echo 'export REPLICATE_API_TOKEN="r8_..."' >> ~/.zshrc
```

### Option 2: Lokale GPU (Fortgeschritten)

⚠️ **Warnung:** Benötigt NVIDIA GPU (Mac mit M1/M2/M3 haben keine CUDA-Unterstützung)

Für Mac mit M1/M2/M3:
- **Nutze Replicate API** (keine lokale GPU möglich)
- Oder: **Cloud-GPU** (RunPod/Vast.ai)

Für Mac mit externer NVIDIA GPU:
```bash
# Installiere PyTorch mit CUDA
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu118

# Installiere restliche Dependencies
pip3 install -r server/tools/requirements_sdxl.txt
```

---

## Verwendung

### Mit Run-Script (Empfohlen)

```bash
# Wechsel ins Projekt-Verzeichnis
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Test mit 5 Rezepten
./server/tools/run_sdxl.sh aldi_nord 5

# Produktion (alle Rezepte)
./server/tools/run_sdxl.sh aldi_nord
```

### Manuell

```bash
# Wechsel ins Projekt-Verzeichnis
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Dependencies installieren (nur bei erster Nutzung)
pip3 install replicate requests pillow python-dotenv

# Test mit 5 Rezepten
python3 server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord --limit 5

# Produktion
python3 server/tools/generate_recipe_images_sdxl.py --retailer aldi_nord --skip-existing
```

---

## Troubleshooting

### "command not found: python3"

```bash
# Prüfe ob Python installiert ist
which python3

# Falls nicht: Installiere mit Homebrew
brew install python3
```

### "command not found: pip3"

```bash
# Prüfe ob pip installiert ist
which pip3

# Falls nicht: Installiere mit Python
python3 -m ensurepip --upgrade
```

### "ModuleNotFoundError: No module named 'replicate'"

```bash
# Installiere Dependencies
pip3 install replicate requests pillow python-dotenv
```

### "REPLICATE_API_TOKEN nicht gesetzt"

```bash
# Setze Token (für aktuelle Session)
export REPLICATE_API_TOKEN="r8_..."

# Oder: Permanent in ~/.zshrc
echo 'export REPLICATE_API_TOKEN="r8_..."' >> ~/.zshrc
source ~/.zshrc
```

---

## Empfehlung für macOS

✅ **Nutze Replicate API:**
- Kein Setup nötig
- Funktioniert auf allen Macs (auch M1/M2/M3)
- Günstig (~$0.004/Bild)
- Keine GPU nötig

❌ **Vermeide lokale GPU:**
- Mac mit M1/M2/M3 haben keine CUDA-Unterstützung
- SDXL läuft sehr langsam auf CPU
- Nicht praktikabel für Produktion

---

**Erstellt:** 2025-01-05  
**Version:** 1.0.0
