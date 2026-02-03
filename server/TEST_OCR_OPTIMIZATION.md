# 🧪 Test-Prompt für OCR-Optimierung

## Test-Befehl

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
python3 scripts/process_all_prospekte.py
```

## Oder für einen einzelnen Prospekt:

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
python3 -m prospekt_pipeline.cli.run_parser --folder media/prospekte/edeka/edeka\ berlin
```

## Erwartete Ergebnisse

### Performance
- **Vorher**: ~17 Minuten für 58 Seiten
- **Nachher**: ~5-7 Minuten für 58 Seiten
- **Verbesserung**: 60-70% schneller

### Qualität
- ✅ Erste 20 Seiten: Volle Qualität (2 Strategien, 350 DPI)
- ✅ Letzte 5 Seiten: Volle Qualität (2 Strategien, 350 DPI)
- ✅ Mittlere Seiten: Gute Qualität (1 Strategie, 250 DPI, jede 3. Seite)
- ✅ Mindestens 90% der wichtigen Angebote erkannt

## Log-Ausgaben prüfen

Suche nach folgenden Log-Meldungen:

```
INFO | prospekt_pipeline.parsers.ocr | PDF has X pages
INFO | prospekt_pipeline.parsers.ocr | Selected Y pages for OCR processing (quality-preserving strategy)
INFO | prospekt_pipeline.parsers.ocr | Converting pages A-B with 350 DPI
INFO | prospekt_pipeline.parsers.ocr | Converting pages C-D with 250 DPI
INFO | prospekt_pipeline.parsers.ocr | Processing X pages with OCR (quality-preserving)
FALLBACK | prospekt_pipeline.parsers.ocr | OCR recovered Z unique offers from X pages
```

## Vergleichstest

### Test 1: Großer Prospekt (58 Seiten)
```bash
python3 -m prospekt_pipeline.cli.run_parser --folder media/prospekte/edeka/edeka\ berlin
```

**Erwartet:**
- Verarbeitung: ~5-7 Minuten
- Seiten: Erste 20 + letzte 5 vollständig, mittlere jede 3.
- DPI: 350 für wichtige, 250 für mittlere
- Strategien: 2 für wichtige, 1 für mittlere

### Test 2: Kleiner Prospekt (< 20 Seiten)
```bash
python3 -m prospekt_pipeline.cli.run_parser --folder media/prospekte/aldi/aldi\ nord
```

**Erwartet:**
- Alle Seiten verarbeitet
- 2 Strategien auf allen Seiten
- 350 DPI

### Test 3: OCR wird übersprungen
Wenn PDF-Parsing gut funktioniert (> 30% Ergebnisse), sollte OCR komplett übersprungen werden:

```
INFO | prospekt_pipeline.pipeline.process_prospekt | OCR übersprungen (PDF-Parsing lieferte genug Ergebnisse: X)
```

## Qualitäts-Check

Nach der Verarbeitung prüfe `offers.json`:

1. **Anzahl der Angebote**: Sollte ähnlich oder besser sein als vorher
2. **Erste Seiten**: Sollten vollständig erkannt sein
3. **Letzte Seiten**: Sollten vollständig erkannt sein
4. **Mittlere Seiten**: Sollten zumindest teilweise erkannt sein

## Performance-Messung

```bash
time python3 -m prospekt_pipeline.cli.run_parser --folder media/prospekte/edeka/edeka\ berlin
```

**Erwartete Zeit**: 5-7 Minuten (statt 17 Minuten)

## Troubleshooting

### Problem: Zu langsam
- Prüfe ob alle Seiten konvertiert werden (sollte nicht sein)
- Prüfe ob DPI korrekt ist (350/250, nicht 400)

### Problem: Zu wenige Angebote
- Prüfe ob erste 20 + letzte 5 Seiten vollständig verarbeitet werden
- Prüfe ob 2 Strategien auf wichtigen Seiten laufen

### Problem: OCR läuft immer
- Prüfe ob PDF-Parsing genug Ergebnisse liefert
- Prüfe Log: "OCR übersprungen" sollte erscheinen wenn PDF-Parsing gut ist

