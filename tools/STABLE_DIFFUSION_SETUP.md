# Stable Diffusion Setup Guide

## Übersicht

Das `weekly_refresh.py` Script nutzt **Automatic1111 WebUI** (Stable Diffusion) um Rezept-Bilder zu generieren.

## Installation

### Option 1: Automatic1111 WebUI (Empfohlen)

#### macOS

```bash
# 1. Python 3.10+ installieren (falls nicht vorhanden)
brew install python@3.10

# 2. Automatic1111 klonen
cd ~
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui

# 3. WebUI starten
./webui.sh
```

#### Windows

```powershell
# 1. Git installieren (falls nicht vorhanden)
# Download: https://git-scm.com/download/win

# 2. Python 3.10+ installieren
# Download: https://www.python.org/downloads/

# 3. Automatic1111 klonen
cd C:\
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui

# 4. WebUI starten
webui-user.bat
```

#### Linux

```bash
# 1. Python 3.10+ installieren
sudo apt install python3.10 python3.10-venv

# 2. Automatic1111 klonen
cd ~
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui

# 3. WebUI starten
./webui.sh
```

### Option 2: Docker (Alternative)

```bash
# Docker Image mit Automatic1111
docker run -it --gpus all -p 7860:7860 \
  -v $(pwd)/models:/app/models \
  -v $(pwd)/outputs:/app/outputs \
  ghcr.io/runpod/stable-diffusion-webui:latest
```

## Erste Schritte

### 1. WebUI starten

Nach dem Start sollte die WebUI auf **http://127.0.0.1:7860** erreichbar sein.

**Wichtig:** Die WebUI muss laufen, bevor du `weekly_refresh.py` ausführst!

### 2. Modell herunterladen (optional)

Standardmäßig nutzt Automatic1111 ein Basis-Modell. Für bessere Food-Fotos empfehle ich:

- **Realistic Vision** (für realistische Food-Fotos)
- **DreamShaper** (allgemein gut)
- **SDXL** (höhere Qualität, benötigt mehr VRAM)

**Download-Links:**
- https://civitai.com/models/4201/realistic-vision-v50-b1
- https://civitai.com/models/4384/dreamshaper
- https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0

**Installation:**
1. Modell-Datei (`.safetensors` oder `.ckpt`) herunterladen
2. In `stable-diffusion-webui/models/Stable-diffusion/` kopieren
3. WebUI neu starten
4. In der WebUI das Modell auswählen

### 3. API aktivieren

Die WebUI hat standardmäßig die API aktiviert. Falls nicht:

1. Öffne `webui-user.sh` (oder `webui-user.bat` auf Windows)
2. Füge hinzu: `export COMMANDLINE_ARGS="--api"`
3. WebUI neu starten

## Verwendung mit weekly_refresh.py

### Basis-Kommando

```bash
# Stelle sicher, dass Automatic1111 auf http://127.0.0.1:7860 läuft
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes
```

### Alternative SD URL

Falls SD auf einem anderen Port/Server läuft:

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --sd-url http://192.168.1.100:7860
```

### Dry-Run (Test ohne Bilder)

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --dry-run
```

## Troubleshooting

### "SD nicht erreichbar"

**Problem:** Connection refused

**Lösung:**
1. Prüfe ob Automatic1111 läuft: Öffne http://127.0.0.1:7860 im Browser
2. Prüfe den Port: Standard ist 7860, kann in `webui-user.sh` geändert werden
3. Prüfe Firewall: Port 7860 muss erreichbar sein

### "Request timeout"

**Problem:** SD braucht zu lange

**Lösung:**
1. Reduziere Bildgröße in `sd_image.py` (aktuell 768x768)
2. Nutze ein kleineres Modell
3. Prüfe GPU/VRAM: Mehr VRAM = schneller

### "Out of memory"

**Problem:** Nicht genug VRAM

**Lösung:**
1. Nutze `--medvram` Flag in `webui-user.sh`:
   ```bash
   export COMMANDLINE_ARGS="--medvram --api"
   ```
2. Reduziere Bildgröße auf 512x512
3. Nutze CPU-Modus (sehr langsam):
   ```bash
   export COMMANDLINE_ARGS="--cpu --api"
   ```

### Bilder sind nicht gut genug

**Lösung:**
1. Nutze ein besseres Modell (siehe oben)
2. Passe Prompts in `sd_image.py` an
3. Nutze LoRA-Modelle für Food-Fotografie (z.B. von Civitai)

## Performance-Tipps

### Batch-Processing

Das Script generiert Bilder sequenziell. Für bessere Performance:

1. Nutze GPU mit viel VRAM (8GB+ empfohlen)
2. Nutze `--xformers` für bessere Performance:
   ```bash
   export COMMANDLINE_ARGS="--xformers --api"
   ```
3. Nutze ein optimiertes Modell (z.B. quantisiert)

### Rate Limiting

SD kann bei vielen Requests überlasten. Das Script hat bereits Retry-Logik, aber du kannst auch:

1. Manuell pausieren zwischen Markets
2. SD auf einem separaten Server laufen lassen
3. Batch-Size in SD erhöhen (nicht im Script, sondern in SD-Config)

## Alternative: Cloud-Services

Falls lokale SD zu langsam/teuer ist:

### RunPod / Vast.ai

1. GPU-Instance mieten (RTX 3090/4090)
2. Automatic1111 installieren
3. `--sd-url` auf Cloud-URL setzen

### Replicate API

Für API-basierte Lösung könnte `sd_image.py` auf Replicate umgestellt werden (kostet pro Bild).

## Beispiel: Kompletter Workflow

```bash
# 1. Terminal 1: Starte Automatic1111
cd ~/stable-diffusion-webui
./webui.sh

# Warte bis "Running on http://127.0.0.1:7860" erscheint

# 2. Terminal 2: Führe weekly_refresh aus
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --dry-run  # Erst testen!

# 3. Wenn alles OK: Ohne --dry-run
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes
```

## Weitere Ressourcen

- **Automatic1111 Docs:** https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki
- **Civitai (Modelle):** https://civitai.com
- **SD Prompts Guide:** https://stable-diffusion-art.com/prompts/

