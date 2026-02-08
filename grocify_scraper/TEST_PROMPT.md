# Test-Prompt für GPT Vision Pipeline

## Schnelltest (1 Supermarkt, ~5-10 Minuten)

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 test_single.py biomarkt --week-key 2025-W52
```

**Erwartetes Ergebnis:**
- ✅ 50-100 Offers extrahiert (GPT Vision)
- ✅ 50 Rezepte generiert
- ✅ Alle JSON-Dateien valide
- ✅ Checkpoint gespeichert

## Volltest (Alle Supermärkte, ~1-2 Stunden)

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="sk-..."

python3 test_all_supermarkets.py --week-key 2025-W52
```

**Erwartetes Ergebnis:**
- ✅ 11-13 Supermärkte erfolgreich
- ✅ 550-1300 Offers insgesamt
- ✅ 550-1300 Rezepte insgesamt
- ✅ Manifest JSON erstellt

## Was prüfen?

1. **Offers-Dateien:**
   ```bash
   ls -lh out/offers/*.json
   # Sollte mehrere MB groß sein, nicht leer
   ```

2. **Rezepte:**
   ```bash
   python3 -c "import json; print(len(json.load(open('out/recipes/recipes_biomarkt_2025-W52.json'))))"
   # Sollte 50-100 sein
   ```

3. **Checkpoint:**
   ```bash
   cat out/reports/checkpoints/checkpoint_2025-W52.json | jq '.supermarkets.biomarkt.status'
   # Sollte "RECIPES_DONE" sein
   ```

4. **Manifest:**
   ```bash
   cat out/manifest_2025-W52.json | jq '.summary'
   ```

## Mögliche Probleme & Lösungen

**Problem:** "OPENAI_API_KEY not set"
- Lösung: `export OPENAI_API_KEY="..."` setzen

**Problem:** "pdf2image not available"
- Lösung: `pip install pdf2image` (benötigt poppler)

**Problem:** Sehr langsam (>10 Min pro Supermarkt)
- Normal bei GPT Vision! Jede Seite braucht 3-5 API-Calls
- Optimierungen: weniger Passes, nur bei großen Lücken

**Problem:** "Offer missing id"
- Sollte jetzt automatisch generiert werden

## Erfolgskriterien

✅ Pipeline läuft durch ohne Crash
✅ Mindestens 50 Offers pro Supermarkt (mit PDF)
✅ Mindestens 50 Rezepte pro Supermarkt
✅ Alle JSON-Dateien sind valide (keine Syntax-Fehler)
✅ Checkpoint wird gespeichert
✅ Manifest wird erstellt

