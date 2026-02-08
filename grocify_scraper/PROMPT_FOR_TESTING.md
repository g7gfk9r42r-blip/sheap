# 🧪 TEST-PROMPT: GPT Vision Pipeline

## Was wurde verbessert?

✅ **GPT Vision Extraktion** - Seitenbasierte Extraktion mit 3 Passes (Initial, Completeness, Microtext)
✅ **Checkpoint-System** - Resumable runs, Fortsetzung nach Abbruch möglich
✅ **RAW-Priorität** - RAW (list) hat Priorität über PDF bei Reconciliation
✅ **50-100 Rezepte** - Automatische Generierung mit Varietät-Buckets
✅ **Robuste Validierung** - Funktioniert mit Dicts und Offer-Objekten
✅ **Optimierungen** - Weniger Passes, nur bei signifikanten Lücken

## 🚀 SCHNELLTEST (Empfohlen für ersten Test)

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 test_single.py biomarkt --week-key 2025-W52
```

**Dauer:** ~10-15 Minuten (16 Seiten × 3-5 API-Calls pro Seite)

**Erwartetes Ergebnis:**
- ✅ 50-100 Offers extrahiert (GPT Vision)
- ✅ 50 Rezepte generiert
- ✅ Alle JSON-Dateien valide
- ✅ Checkpoint in `out/reports/checkpoints/checkpoint_2025-W52.json`

## 📊 Was prüfen nach dem Test?

### 1. Offers prüfen
```bash
python3 -c "
import json
offers = json.load(open('out/offers/offers_biomarkt_2025-W52.json'))
print(f'✅ Offers: {len(offers)}')
print(f'   Sample: {offers[0][\"title\"] if offers else \"N/A\"}')
print(f'   Mit Preis: {sum(1 for o in offers if o.get(\"priceTiers\"))}')
"
```

### 2. Rezepte prüfen
```bash
python3 -c "
import json
recipes = json.load(open('out/recipes/recipes_biomarkt_2025-W52.json'))
print(f'✅ Rezepte: {len(recipes)}')
print(f'   Sample: {recipes[0][\"title\"] if recipes else \"N/A\"}')
"
```

### 3. Checkpoint prüfen
```bash
cat out/reports/checkpoints/checkpoint_2025-W52.json | python3 -m json.tool | grep -A 5 biomarkt
```

**Erwarteter Status:** `"status": "RECIPES_DONE"`

### 4. Page Stats prüfen
```bash
cat out/reports/pdf_page_stats_biomarkt_2025-W52.json | python3 -m json.tool | head -30
```

**Sollte zeigen:**
- `total_pages`: 16
- `total_offers`: 50-100
- `pages`: Details pro Seite

## 🎯 Erfolgskriterien

✅ Pipeline läuft durch ohne Crash
✅ Mindestens 50 Offers (GPT Vision sollte deutlich mehr finden als traditionelle Methode)
✅ Mindestens 50 Rezepte
✅ Alle JSON-Dateien sind valide (keine Syntax-Fehler)
✅ Checkpoint wird gespeichert
✅ Manifest wird erstellt

## ⚠️ Bekannte Einschränkungen

- **Geschwindigkeit:** GPT Vision ist langsam (~30-60 Sekunden pro Seite)
- **Kosten:** Jede Seite = 3-5 API-Calls (kostet ~$0.01-0.02 pro Seite)
- **Timeout:** Falls API-Call zu lange dauert, wird nach 60s abgebrochen

## 🔧 Bei Problemen

**"OPENAI_API_KEY not set"**
→ `export OPENAI_API_KEY="..."` setzen

**"pdf2image not available"**
→ `pip install pdf2image` (benötigt poppler: `brew install poppler`)

**"Offer missing id"**
→ Sollte automatisch generiert werden, wenn nicht vorhanden

**Sehr langsam**
→ Normal! GPT Vision braucht Zeit. Jede Seite = mehrere API-Calls.

## 📝 Was solltest du mir sagen?

Nach dem Test, bitte teile:

1. **Anzahl Offers:** Wie viele wurden extrahiert?
2. **Anzahl Rezepte:** Wie viele wurden generiert?
3. **Fehler:** Gab es Fehler? Wenn ja, welche?
4. **Geschwindigkeit:** Wie lange hat es gedauert?
5. **Qualität:** Siehen die Offers/Rezepte gut aus?

---

**JETZT TESTEN:**
```bash
export OPENAI_API_KEY="sk-..."
python3 test_single.py biomarkt --week-key 2025-W52
```

