# 🗓️ FINALER WÖCHENTLICHER PROMPT

## 📋 Zusammenfassung

**Ziel:** Jede Woche automatisch alle 13 Supermärkte verarbeiten:
- ✅ Präzise Angebots-Extraktion (PDF + JSON Fusion)
- ✅ Zutaten-Verfügbarkeit prüfen
- ✅ Nährwerte bestimmen (OpenFoodFacts + Fallback)
- ✅ 50-100 Rezepte generieren
- ✅ Image Jobs erstellen

## 🚀 WÖCHENTLICHER BEFEHL

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 weekly_pipeline.py --week-key 2025-W52
```

**Oder automatisch (aktuelle Woche):**
```bash
python3 weekly_pipeline.py
```

## 📊 Was wird erstellt?

### Pro Supermarkt:
1. `out/offers/offers_<supermarket>_<weekKey>.json` - Finale Offers
2. `out/recipes/recipes_<supermarket>_<weekKey>.json` - 50-100 Rezepte
3. `out/images/image_jobs_<supermarket>_<weekKey>.json` - Image Prompts
4. `out/reports/page_quality_<supermarket>_<weekKey>.json` - Qualitäts-Metriken
5. `out/reports/reconcile_<supermarket>_<weekKey>.json` - Reconciliation Report

### Global:
6. `out/manifest_<weekKey>.json` - Global Manifest mit allen Metriken

### Cache (Resumable):
7. `out/cache/<supermarket>/<weekKey>/pages/page_<n>.png` - Gerenderte Seiten
8. `out/cache/<supermarket>/<weekKey>/page_<n>_tiles.json` - Tile-Counts
9. `out/cache/<supermarket>/<weekKey>/page_<n>_offers.json` - Per-Page Offers

## 🎯 Erwartete Ausgabe (NUR JSON)

```json
{
  "status": "OK",
  "manifestPath": "out/manifest_2025-W52.json",
  "metrics": {
    "totalOffers": 800,
    "totalRecipes": 650
  }
}
```

## ⏰ Automatisierung (Cron)

```bash
# Jeden Montag um 00:00
0 0 * * 1 cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper && export OPENAI_API_KEY="..." && python3 weekly_pipeline.py >> logs/weekly_$(date +\%Y-\%W).log 2>&1
```

## 📝 Nach Ausführung

```bash
# Manifest prüfen
cat out/manifest_2025-W52.json | python3 -m json.tool | head -50

# Erfolgreiche Supermärkte
cat out/manifest_2025-W52.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
ok = [sm for sm, r in data['supermarkets'].items() if r.get('status') == 'OK']
print(f'✅ {len(ok)}/{len(data[\"supermarkets\"])} Supermärkte erfolgreich')
for sm in ok:
    m = data['supermarkets'][sm].get('metrics', {})
    print(f'  {sm}: {m.get(\"offers\", 0)} offers, {m.get(\"recipes\", 0)} recipes')
"
```

## 🔧 Implementierte Features

✅ **Phase 1:** Präzise Extraktion (PDF + JSON)
✅ **Phase 2:** Verfügbarkeits-Prüfung (Angebote + Grundsortiment)
✅ **Phase 3:** Nährwerte (OpenFoodFacts + Kategorie-Fallback)
✅ **Phase 4:** Image Jobs (Prompts für DALL-E)
✅ **Phase 5:** Wöchentliche Automatisierung

## 📚 Dokumentation

- `THEORETISCHE_ANALYSE.md` - Theoretische Überprüfung
- `5_TEILIGER_UMSETZUNGSPLAN.md` - Detaillierter Plan
- `WOECHENTLICHER_PROMPT.md` - Automatisierungs-Details

