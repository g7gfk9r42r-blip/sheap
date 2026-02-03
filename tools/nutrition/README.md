# Nutrition Enrichment Pipeline

Automatisches Hinzufügen von Nährwertdaten (Kalorien, Proteine, Fette, Kohlenhydrate) zu Rezept-JSONs.

## Features

✅ **Automatische Nährwertsuche** über Open Food Facts & USDA FoodData Central  
✅ **Intelligente Normalisierung** mit deutschen Synonymen und Marken-Filtering  
✅ **Persistentes Caching** - keine doppelten API-Anfragen  
✅ **Pantry-Item-Erkennung** - Gewürze/Basis-Zutaten optional ausschließen  
✅ **Unit-Konvertierung** - g/kg/ml/l mit Dichte-Tabelle  
✅ **Robuste Fehlerbehandlung** - einzelne Fehler brechen Pipeline nicht ab  
✅ **Detaillierte Reports** - Missing/Ambiguous/Cache-Listen  

## Voraussetzungen

### Python-Pakete

```bash
pip install requests
```

### API-Keys (Optional aber empfohlen)

#### USDA FoodData Central (kostenlos)

Für generische Lebensmittel (Zwiebeln, Milch, Reis, etc.):

1. Registrieren: https://fdc.nal.usda.gov/api-key-signup.html
2. API-Key per Email erhalten
3. Umgebungsvariable setzen:

```bash
export USDA_FDC_API_KEY="your-api-key-here"
```

**Ohne USDA-Key**: Nur Open Food Facts wird verwendet (funktioniert, aber weniger generische Zutaten verfügbar).

#### Open Food Facts

Keine Registrierung nötig - kostenlos und offen!

## Installation

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app

# Optional: USDA API-Key setzen
export USDA_FDC_API_KEY="your-key"
```

## Verwendung

### Basis-Aufruf

```bash
python tools/enrich_nutrition.py --root ./server/media/prospekte
```

Scannt alle JSON-Dateien in `server/media/prospekte` (rekursiv) und erstellt für jede Datei eine `*_nutrition.json` mit angereicherten Daten.

### Nur spezifische Supermärkte

```bash
python tools/enrich_nutrition.py --root ./server/media/prospekte --only-market aldi_nord
```

### Nur spezifische Woche

```bash
python tools/enrich_nutrition.py --root ./server/media/prospekte --only-kw kw52_2025
```

### Originaldateien überschreiben

```bash
python tools/enrich_nutrition.py --root ./server/media/prospekte --overwrite
```

⚠️ **Vorsicht**: Überschreibt die Original-JSONs!

### Verbose-Modus (detaillierte Logs)

```bash
python tools/enrich_nutrition.py --root ./server/media/prospekte --verbose
```

### Alle Optionen

```bash
python tools/enrich_nutrition.py --help
```

## Output-Struktur

### Pro Zutat (Ingredient)

Vor:
```json
{
  "name": "Zwiebeln",
  "qty": 200,
  "unit": "g"
}
```

Nach:
```json
{
  "name": "Zwiebeln",
  "qty": 200,
  "unit": "g",
  "canonical_key": "onions",
  "nutrition_source": {
    "provider": "usda_fdc",
    "id": "170000",
    "name": "Onions, raw",
    "confidence": 0.85
  },
  "nutrition_per_100g": {
    "kcal": 40.0,
    "protein_g": 1.1,
    "fat_g": 0.1,
    "carbs_g": 9.3
  },
  "nutrition_total": {
    "kcal": 80.0,
    "protein_g": 2.2,
    "fat_g": 0.2,
    "carbs_g": 18.6
  },
  "flags": {
    "exclude_from_shopping": false,
    "exclude_from_price": false,
    "exclude_from_nutrition": false,
    "needs_manual_check": false
  }
}
```

### Pro Rezept

```json
{
  "title": "Spaghetti Bolognese",
  "servings": 4,
  "ingredients": [...],
  "nutrition_total": {
    "kcal": 2400.0,
    "protein_g": 120.0,
    "fat_g": 80.0,
    "carbs_g": 200.0
  },
  "nutrition_per_serving": {
    "kcal": 600.0,
    "protein_g": 30.0,
    "fat_g": 20.0,
    "carbs_g": 50.0
  },
  "nutrition_coverage": {
    "ingredients_total": 10,
    "ingredients_with_nutrition": 8,
    "missing": 2
  }
}
```

## Cache & Reports

Die Pipeline erstellt automatisch ein `nutrition_cache/` Verzeichnis mit:

### `nutrition_cache.json`
Persistenter Cache aller gefundenen Nährwerte:
```json
{
  "onions": {
    "nutrition": {
      "kcal": 40.0,
      "protein_g": 1.1,
      "fat_g": 0.1,
      "carbs_g": 9.3
    },
    "metadata": {
      "source": {
        "provider": "usda_fdc",
        "id": "170000"
      }
    },
    "cached_at": "2025-12-22T10:30:00"
  }
}
```

### `nutrition_missing.json`
Zutaten, die nicht gefunden wurden:
```json
{
  "exotische zutat xyz": {
    "original_names": ["Exotische Zutat XYZ"],
    "reason": "not_found",
    "first_seen": "2025-12-22T10:30:00",
    "count": 3
  }
}
```

👉 **Aktion**: Diese Zutaten manuell in `normalization.py` als Synonym hinzufügen oder externe Quelle suchen.

### `nutrition_ambiguous.json`
Zutaten mit mehreren möglichen Matches:
```json
{
  "milch": {
    "original_names": ["Milch frisch", "Frische Milch 1,5%"],
    "matches": [
      {
        "provider": "usda_fdc",
        "name": "Milk, lowfat, 1.5%",
        "confidence": 0.75
      },
      {
        "provider": "openfoodfacts",
        "name": "Fresh Milk Aldi",
        "confidence": 0.72
      }
    ],
    "count": 5
  }
}
```

👉 **Aktion**: Bester Match wird automatisch verwendet, aber prüfen ob korrekt.

## Konfiguration

### Pantry-Items erweitern

In `nutrition/normalization.py`:

```python
PANTRY_EXCLUDE: Set[str] = {
    "salz", "pfeffer", "gewuerze",
    # Füge hier weitere Gewürze/Basics hinzu:
    "vanillezucker", "backpulver", ...
}
```

### Synonyme hinzufügen

In `nutrition/normalization.py`:

```python
SYNONYM_MAP: Dict[str, str] = {
    "hackfleisch": "ground meat",
    # Füge hier deutsche -> englische Übersetzungen hinzu:
    "schweinefilet": "pork tenderloin",
    ...
}
```

### Dichte-Tabelle erweitern

In `nutrition/normalization.py`:

```python
DENSITY_TABLE: Dict[str, float] = {
    "milch": 1.03,  # g/ml
    # Füge hier weitere Flüssigkeiten hinzu:
    "sojasauce": 1.15,
    ...
}
```

## Troubleshooting

### "USDA provider not available"

➜ USDA API-Key fehlt. Entweder:
- Key setzen: `export USDA_FDC_API_KEY="..."`
- Oder ohne USDA weitermachen (nur Open Food Facts)

### Viele "Missing" Ingredients

➜ Häufige Ursachen:
1. **Markennamen/Supermarkt-Suffixe**: werden normalerweise entfernt, aber evtl. noch zu spezifisch
2. **Exotische Zutaten**: nicht in USDA/OFF vorhanden
3. **Schreibfehler**: in Original-Daten

➜ Lösungen:
- Synonyme in `normalization.py` hinzufügen
- `nutrition_missing.json` prüfen und manuell in Cache eintragen
- Oder externe deutsche Nährwert-API integrieren

### "Low confidence" Warnungen

➜ Match-Qualität ist unsicher (< 0.5)
- Prüfe `nutrition_ambiguous.json`
- Falls korrekt: Confidence-Threshold in `enrich_nutrition.py` senken (Zeile 25)
- Falls falsch: Synonym hinzufügen

### Rate-Limiting / Timeouts

➜ Open Food Facts ist kostenlos aber limitiert
- Pipeline enthält bereits 1s-Pause zwischen Requests
- Bei Timeout: Script einfach nochmal starten (Cache wird genutzt)
- Oder `MIN_REQUEST_INTERVAL` in `providers/openfoodfacts.py` erhöhen

## Erweiterung

### Neue Provider hinzufügen

1. Neue Datei: `nutrition/providers/myprovider.py`
2. Implementiere Interface aus `providers/__init__.py`
3. In `enrich_nutrition.py` initialisieren und in `_fetch_nutrition()` einbinden

### Deutsche Nährwert-APIs

Mögliche Kandidaten:
- **Bundeslebensmittelschlüssel (BLS)**: Offiziell, aber kommerziell
- **Fatsecret**: Kostenlose API mit deutschen Daten
- **MyFitnessPal**: Keine offizielle API

## Performance

- **Mit Cache**: ~0.1s pro Zutat (Disk-Read)
- **Ohne Cache**: ~1-2s pro Zutat (API-Call + Rate-Limit)
- **Beispiel**: 100 Rezepte mit je 10 Zutaten (1000 Zutaten)
  - Erste Ausführung: ~30 Minuten
  - Zweite Ausführung: ~2 Minuten (Cache!)

## License

Teil des `roman_app` Projekts.

## Support

Bei Problemen:
1. `--verbose` Flag nutzen für detaillierte Logs
2. `nutrition_cache/nutrition_missing.json` prüfen
3. `nutrition_cache/nutrition_ambiguous.json` prüfen

