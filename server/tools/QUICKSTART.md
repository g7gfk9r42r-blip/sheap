# Quick Start Guide

## Test-Prompt ausführen

**Von überall:**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 server/tools/test_image_prompt.py
```

**Oder direkt aus tools-Verzeichnis:**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools
python3 test_image_prompt.py
```

## Rezept-Bilder generieren

**Vom Projekt-Root:**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 server/tools/generate_recipe_images.py --limit 3
```

**Oder direkt aus tools-Verzeichnis:**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/tools
python3 generate_recipe_images.py --limit 3
```

**Alle Rezepte (ohne Limit):**
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 server/tools/generate_recipe_images.py
```

## Custom Pfade

Wenn du andere Pfade verwenden möchtest:

```bash
python3 server/tools/generate_recipe_images.py \
  --input-dir /pfad/zu/recipes \
  --output-dir /pfad/zu/bilder \
  --out-json-dir /pfad/zu/output
```

## Test-Prompt anpassen

Öffne `server/tools/test_image_prompt.py` und ändere die Variable `test_prompt`.
