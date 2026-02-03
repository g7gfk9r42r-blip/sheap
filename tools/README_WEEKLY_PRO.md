# Weekly “Pro” Workflow (alle Supermärkte, 1 Command)

Ziel: Du ersetzt wöchentlich nur die Rohdaten und startest **ein** Script. Danach sind **Rezepte + Bilder** in der App-Asset-Struktur aktualisiert.

## 1) Wo du wöchentlich die Rohdaten ablegst

### Standard (für alle Märkte)
Lege je Supermarkt eine Textdatei ab (Standard-Ordner ist `weekly_raw/`):

- `weekly_raw/aldi_nord.txt`
- `weekly_raw/aldi_sued.txt`
- `weekly_raw/biomarkt.txt`
- `weekly_raw/kaufland.txt`
- `weekly_raw/lidl.txt`
- `weekly_raw/nahkauf.txt`
- `weekly_raw/netto.txt`
- `weekly_raw/norma.txt`
- `weekly_raw/penny.txt`
- `weekly_raw/rewe.txt`
- `weekly_raw/tegut.txt`

Inhalt: Rohtext aus dem Prospekt (kopiert/zusammengefügt). Je mehr “Angebotsdaten”, desto besser.

> Wenn du stattdessen `weekly/raw/` angelegt hast: du kannst `weekly_pro.py` so starten:  
> `python3 tools/weekly_pro.py ... --raw-dir "weekly/raw"`

### Lidl (optional: PDF statt Text)
Wenn du die Lidl-PDF hast, kannst du stattdessen ablegen:

- `weekly_raw/lidl.pdf`

Dann extrahiert `tools/weekly_pro.py` automatisch via `assets/prospekte/lidl/extract_lidl_offers_vision.py` eine `lidl.txt` und nutzt diese.

## 2) Das eine Kommando

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app
export OPENAI_API_KEY="sk-..."

# einmalig (oder im CI)
pip3 install -r tools/recipe_generator_requirements.txt
pip3 install -r tools/requirements.txt

# wöchentlich
python3 tools/weekly_pro.py \
  --image-backend none
```

### Bilder generieren (empfohlen)
Wenn du Bilder wirklich generieren willst, brauchst du ein Backend für `tools/weekly_refresh.py`.

- **replicate**: setze `REPLICATE_API_TOKEN=...`

Dann:

```bash
python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict
```

### Ohne Store-Update nach dem Release (HTTP Publish)
Wenn du **nach dem App-Release** wöchentlich Updates ausliefern willst, ohne jedes Mal ein Store-Update:

1) App (Release) muss `API_BASE_URL=https://dein-server.tld` nutzen (Dart define).
2) `weekly_pro.py` soll nach `server/media/` publishen:

```bash
python3 tools/weekly_pro.py \
  --image-backend replicate \
  --strict \
  --publish-server
```

> Hinweis: `--week` und `--valid-from` sind optional.  
> Wenn du nichts angibst, nimmt das Script automatisch die **aktuelle ISO‑Woche** und setzt `valid_from` auf den **Montag dieser Woche**.

Dann liegen die Dateien unter:
- `server/media/prospekte/<market>/<market>_recipes.json`
- `server/media/recipe_images/<market>/R###.png`

## 3) Output (wird automatisch überschrieben)

- **Rezepte (App-Assets)**: `assets/recipes/<market>/<market>_recipes.json`
- **Bilder (App-Assets)**: `assets/images/recipes/<market>_R###.png`

## 4) Wenn etwas fehlt

- **Fehlende Raw Datei**: `❌ Missing weekly raw input: weekly_raw/<market>.txt`
  - → Datei anlegen und Rohtext reinkopieren.
- **OPENAI_API_KEY fehlt**:
  - → in Shell exportieren oder in `.env` im Projekt-Root setzen.


