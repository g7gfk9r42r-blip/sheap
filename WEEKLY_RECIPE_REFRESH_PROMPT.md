# Wöchentlicher Recipe-Refresh Prompt

## ROLE
Senior Software Engineer (Python), spezialisiert auf Offline-First Mobile Apps, Asset-Pipelines und AI-Image-Generation.

## GOAL
Führe wöchentlich einen vollautomatisierten Recipe-Refresh durch, der:
1. Alle Recipe-JSONs aus `assets/prospekte/<market>/<market>_recipes.json` lädt (12 Märkte)
2. Für jedes Rezept ein Bild generiert und unter `assets/images/<market>_<recipeId>.png` speichert
3. Die Recipe-JSONs mit `image_path` aktualisiert
4. Sicherstellt, dass alle 12 Märkte korrekt verarbeitet werden

## STRUCTURE

### Input:
- `assets/prospekte/<market>/<market>_recipes.json`
- Märkte: aldi_nord, aldi_sued, biomarkt, kaufland, lidl, nahkauf, netto, norma, penny, rewe, tegut
- **WICHTIG:** Nur Dateien die auf `_recipes.json` enden (NICHT `<market>.json`)

### Output:
- `assets/prospekte/<market>/<market>_recipes.json` (aktualisiert mit `image_path`: `assets/images/<market>_<recipeId>.png`)
- `assets/images/<market>_<recipeId>.png` (generierte Bilder)

## RULES

1. **KEINE Rezepte erfinden/supplementieren/entfernen**
   - Anzahl Output = Anzahl Input (exakt)
   - IDs dürfen NICHT geändert werden
   - Valid IDs: R001-R999 (Format: ^R\d{3}$)

2. **Image-Generation:**
   - Prompt: "high quality food photography, realistic, dish: <title>, ingredients: <top 5 ingredients>, no text, no logo, clean background, 1:1, soft light"
   - Negative Prompt: "text, logo, watermark, packaging, brand, hands, people"
   - Format: PNG, 1024x1024
   - Rate limiting: Exponential backoff (mind. 1s zwischen Requests)
   - Wenn Bild bereits existiert und nicht `--force-images`: Skip

3. **Image-Pfad (strikt):**
   - Format: `assets/images/<market>_<recipeId>.png`
   - Beispiel: `assets/images/rewe_R042.png`
   - Setze `image_path` im Recipe-JSON
   - Fallback auf .jpg/.jpeg/.webp wenn vorhanden

4. **Strict Mode:**
   - Abort bei: duplicate IDs, invalid IDs (nicht R###), missing required fields
   - Log: loaded count, valid count, invalid count pro Market

5. **Market Discovery:**
   - Nur `<market>_recipes.json` laden (NICHT `<market>.json`)
   - Ignoriere: .DS_Store, .pdf, .txt, .md, .py, etc.
   - Alle 12 Märkte müssen gefunden werden

## COMMAND

```bash
export REPLICATE_API_TOKEN="r8_YOUR_TOKEN"
cd /Users/romw24/dev/AppProjektRoman/roman_app
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/prospekte \
  --images assets/images \
  --image-backend replicate \
  --strict
```

## EXPECTED RESULT

Nach dem Run:
- Alle 12 Märkte haben aktualisierte `*_recipes.json` mit `image_path`
- Alle Rezepte haben korrespondierende Bilder unter `assets/images/<market>_<recipeId>.png`
- Flutter App lädt alle Rezepte offline
- Asset Audit zeigt: X recipes loaded, Y images matched

## WÖCHENTLICHE AUSFÜHRUNG

**Montags morgens:**
```bash
# 1. Setze API Token
export REPLICATE_API_TOKEN="r8_YOUR_TOKEN"

# 2. Navigiere zum Projekt
cd /Users/romw24/dev/AppProjektRoman/roman_app

# 3. Führe Pipeline aus
python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/prospekte \
  --images assets/images \
  --image-backend replicate \
  --strict

# 4. Prüfe Ergebnis
flutter clean && flutter pub get
flutter run -d chrome  # Prüfe Asset Audit Output
```

## NOTES

- Pipeline lädt NUR `*_recipes.json` (kein `<market>.json`)
- Bilder werden strikt als `assets/images/<market>_<recipeId>.png` gespeichert
- Wenn Bild existiert: Skip (außer `--force-images`)
- Rate limiting beachten: Mindestens 1s zwischen API-Requests
