# Weekly Refresh Pipeline

## Setup

### 1. Dependencies installieren

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
pip3 install -r tools/requirements.txt
```

### 2. OpenAI API Key setzen

```bash
export OPENAI_API_KEY="sk-..."
```

Oder in `.env` Datei:
```
OPENAI_API_KEY=sk-...
```

## Usage

### Basis-Kommando

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes
```

### Nur bestimmte Markets

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --only aldi_sued,lidl
```

### Dry-Run (Test ohne Writes)

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --dry-run
```

### Bilder neu generieren

```bash
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --overwrite-images
```

## Beispielausgabe

```
🔄 Weekly Recipe Refresh Pipeline
============================================================
⚠️  DRY RUN MODUS - Keine Dateien werden geschrieben

📁 3 Market(s) gefunden

📋 Verarbeite aldi_sued...
   Input: assets/prospekte/aldi_sued/aldi_sued_recipes.json
   📚 50 Rezepte geladen
   ✅ 50 valide Rezepte
   🖼️  [DRY RUN] Würde Bild generieren: R001
   🖼️  [DRY RUN] Würde Bild generieren: R002
   ...
   [DRY RUN] Würde schreiben: aldi_sued_recipes.json (50 Rezepte)

📋 Verarbeite lidl...
   Input: assets/prospekte/lidl/lidl_recipes.json
   📚 75 Rezepte geladen
   ✅ 75 valide Rezepte
   ✅ Bild generiert: R001
   ✅ Bild generiert: R002
   ...
   💾 Backup erstellt: _backup/20250106_143022/lidl_recipes.json
   ✅ Gespeichert: lidl_recipes.json

============================================================
📊 REPORT
============================================================

✅ Markets verarbeitet: 2

📚 Rezepte pro Market:
   aldi_sued: 50
   lidl: 75

🖼️  Bilder:
   Generiert: 125
   Übersprungen: 0
   Fehlgeschlagen: 0

   Pro Market (generiert):
      aldi_sued: 50
      lidl: 75

💾 Dateien geschrieben: 2

============================================================
```

## Exit Codes

- `0`: Erfolgreich (Markets verarbeitet, mögliche einzelne Fehler)
- `1`: Teilweise Fehler (viele Fehler)
- `2`: Kein Market verarbeitet (kritisch)

## Struktur

```
assets/
├── prospekte/              # INPUT: Neue Rezept-JSONs
│   ├── aldi_sued_recipes.json
│   └── lidl_recipes.json
├── recipes/                # OUTPUT: Aktualisierte Rezept-JSONs
│   ├── aldi_sued_recipes.json
│   ├── lidl_recipes.json
│   └── _backup/            # Backups
│       └── 20250106_143022/
│           └── aldi_sued_recipes.json
└── images/
    └── recipes/            # OUTPUT: Generierte Bilder
        ├── aldi_sued/
        │   ├── R001.png
        │   └── R002.png
        └── lidl/
            ├── R001.png
            └── R002.png
```

## Flutter Assets

Das Script prüft automatisch `pubspec.yaml` und warnt, falls `assets/images/recipes/` nicht als Asset registriert ist.

Manuelle Prüfung:

```yaml
flutter:
  assets:
    - assets/images/recipes/
```

