# 🧪 FINALER TEST-PROMPT

## Was wurde implementiert?

✅ **Cache-System** - Keine Re-Extraktion wenn Cache existiert
✅ **Tile Consensus** - 2-3x GPT Calls für genauen Tile-Count
✅ **Per-Page Caching** - Jede Seite wird nur einmal vollständig extrahiert
✅ **Targeted Verification** - Nur schlechte Seiten werden re-gecheckt
✅ **Image Jobs** - Image-Prompts werden generiert (nicht inline)
✅ **Strikte Preis-Regeln** - Loyalty/Base/UVP korrekt getrennt

## 🚀 TEST-KOMMANDO

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 run_cached_pipeline.py \
  --supermarket biomarkt \
  --week-key 2025-W52 \
  --pdf-path "../server/media/prospekte/biomarkt/Handzettel BioMarkt Verbund - BioMarkt_HZ_12s_kw_51-52_2025_ohne_Vorherpreis.pdf" \
  --raw-list-path "../server/media/prospekte/biomarkt/biomarkt.json" \
  --out-dir out \
  --max-loops 10
```

**Erwartete Ausgabe (NUR JSON):**
```json
{
  "status": "OK",
  "manifestPath": "out/manifest_biomarkt_2025-W52.json",
  "metrics": {
    "offers": 80,
    "recipes": 50,
    "gptCalls": 60,
    "badPagesFinal": 0,
    "pagesProcessed": 16
  }
}
```

## 📊 Was prüfen?

### 1. Cache-Dateien
```bash
ls -lh out/cache/biomarkt/2025-W52/pages/
# Sollte 16 PNG-Dateien sein

ls -lh out/cache/biomarkt/2025-W52/page_*_tiles.json
# Sollte 16 Tile-Dateien sein

ls -lh out/cache/biomarkt/2025-W52/page_*_offers.json
# Sollte 16 Offer-Dateien sein
```

### 2. Finale Offers
```bash
python3 -c "
import json
offers = json.load(open('out/offers/offers_biomarkt_2025-W52.json'))
print(f'Offers: {len(offers)}')
print(f'Sample: {offers[0] if offers else \"N/A\"}')
"
```

### 3. Rezepte
```bash
python3 -c "
import json
recipes = json.load(open('out/recipes/recipes_biomarkt_2025-W52.json'))
print(f'Rezepte: {len(recipes)}')
print(f'Sample: {recipes[0].get(\"shortTitle\") if recipes else \"N/A\"}')
"
```

### 4. Image Jobs
```bash
cat out/images/image_jobs_biomarkt_2025-W52.json | python3 -m json.tool | head -20
```

### 5. Manifest
```bash
cat out/manifest_biomarkt_2025-W52.json | python3 -m json.tool
```

## 🎯 Erfolgskriterien

✅ Status = "OK"
✅ 50-100 Offers
✅ 50-100 Rezepte
✅ Cache-Dateien vorhanden
✅ Image Jobs erstellt
✅ Manifest erstellt

## 📝 Nach dem Test bitte teilen:

1. **Status:** Was steht in `status`?
2. **Metrics:** Was steht in `metrics`?
3. **Offers:** Wie viele wurden extrahiert?
4. **Rezepte:** Wie viele wurden generiert?
5. **Fehler:** Gab es welche?
6. **Cache:** Wurden Cache-Dateien erstellt?

