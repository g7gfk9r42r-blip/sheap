# 🗓️ Wöchentlicher Automatisierungs-Prompt

## 🎯 Ziel
Jede Woche automatisch:
1. ✅ Neue Prospekte erkennen
2. ✅ Angebote extrahieren (PDF + JSON)
3. ✅ Verfügbarkeit prüfen
4. ✅ Nährwerte bestimmen
5. ✅ Rezepte generieren (50-100 pro Supermarkt)
6. ✅ Image Jobs erstellen

## 🚀 Wöchentlicher Befehl

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 weekly_pipeline.py
```

**Oder mit spezifischer Woche:**
```bash
python3 weekly_pipeline.py --week-key 2025-W52
```

## 📋 Was passiert?

1. **Prospekte scannen**
   - Sucht in `server/media/prospekte/<supermarket>/`
   - Findet neueste PDF und JSON

2. **Für jeden Supermarkt:**
   - Phase 1: Angebots-Extraktion (PDF + JSON)
   - Phase 2: Verfügbarkeit prüfen
   - Phase 3: Nährwerte bestimmen
   - Phase 4: Rezepte generieren
   - Phase 5: Image Jobs erstellen

3. **Global Report**
   - Manifest mit allen Ergebnissen
   - Metriken pro Supermarkt

## 📊 Output

```
out/
├── offers/              # offers_<supermarket>_<weekKey>.json
├── recipes/             # recipes_<supermarket>_<weekKey>.json
├── reports/             # Qualitäts-Reports
├── images/              # image_jobs_<supermarket>_<weekKey>.json
├── cache/               # Zwischen-Cache (resumable)
└── manifest_<weekKey>.json  # Global Manifest
```

## ⏰ Automatisierung (Cron)

```bash
# Jeden Montag um 00:00
0 0 * * 1 cd /path/to/grocify_scraper && export OPENAI_API_KEY="..." && python3 weekly_pipeline.py >> logs/weekly_$(date +\%Y-\%W).log 2>&1
```

## 📝 Nach Ausführung prüfen

```bash
# Manifest anzeigen
cat out/manifest_2025-W52.json | python3 -m json.tool

# Erfolgreiche Supermärkte
cat out/manifest_2025-W52.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
print('✅ Erfolgreich:')
for sm, result in data['supermarkets'].items():
    if result.get('status') == 'OK':
        metrics = result.get('metrics', {})
        print(f'  {sm}: {metrics.get(\"offers\", 0)} offers, {metrics.get(\"recipes\", 0)} recipes')
"
```

