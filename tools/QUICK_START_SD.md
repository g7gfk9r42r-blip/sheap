# Quick Start: Stable Diffusion für Rezept-Bilder

## Minimal-Setup (5 Minuten)

### 1. Automatic1111 installieren

```bash
# macOS/Linux
cd ~
git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git
cd stable-diffusion-webui
./webui.sh
```

**Windows:** Siehe `STABLE_DIFFUSION_SETUP.md`

### 2. WebUI starten

Nach dem ersten Start:
- Öffne Browser: http://127.0.0.1:7860
- Warte bis WebUI geladen ist

### 3. Test mit weekly_refresh

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Dry-Run (Test ohne Bilder)
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --dry-run

# Echter Run (generiert Bilder)
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes
```

## Häufige Probleme

### ❌ "SD nicht erreichbar"
→ Prüfe: Läuft Automatic1111? Browser: http://127.0.0.1:7860

### ❌ "Request timeout"
→ SD ist zu langsam. Nutze `--medvram` in `webui-user.sh`

### ❌ "Out of memory"
→ Nutze `--medvram` oder `--lowvram` Flag

## Nächste Schritte

Für detaillierte Anleitung siehe: `STABLE_DIFFUSION_SETUP.md`
