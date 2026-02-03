# 📝 Text-Format für ALDI Nord Angebote

## Übersicht

Der `text_parser.py` konvertiert einfachen Text oder Pages-Dateien in strukturierte JSON-Format.

## Unterstützte Formate

### 1. Einfaches Text-Format

Jede Zeile = ein Angebot:

```
Milch 1,99 € / L
Brot - 2,49 €
Joghurt 0,79 € / 500g
Apfel | 1,29 € | kg
```

### 2. Separator-Format

Verwende `|`, `-`, oder `/` als Trenner:

```
Produktname | Preis | Einheit
Milch | 1,99 € | L
Brot - 2,49 €
Joghurt / 0,79 € / 500g
```

### 3. Automatische Erkennung

Der Parser erkennt automatisch:
- Preise mit `€` oder `EUR`
- Einheiten: `kg`, `g`, `L`, `l`, `ml`, `Stück`, `Stk`, `St`
- Dezimaltrennzeichen: `,` oder `.`

## Verwendung

### Pages-Datei parsen:

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
python3 -m prospekt_pipeline.aldi_nord.text_parser media/prospekte/aldi_nord/Aldi-nord.pages
```

### Text-Datei parsen:

```bash
python3 -m prospekt_pipeline.aldi_nord.text_parser input.txt output.json
```

### In Python:

```python
from prospekt_pipeline.aldi_nord.text_parser import TextParser
from pathlib import Path

parser = TextParser()

# Pages-Datei parsen
offers = parser.parse_pages_file(Path("Aldi-nord.pages"))

# Text parsen
text = """
Milch 1,99 € / L
Brot 2,49 €
"""
offers = parser.parse_text(text)

# Als JSON speichern
parser.to_json(offers, Path("offers.json"))
```

## Ausgabe-Format (JSON)

```json
[
  {
    "title": "Milch",
    "price": 1.99,
    "price_raw": "1,99 €",
    "unit": "L",
    "brand": null,
    "category": null,
    "confidence": 0.8,
    "source": "text_input",
    "source_page": 1,
    "valid_from": null,
    "valid_to": null
  }
]
```

## Beispiele

### Beispiel 1: Einfache Liste

```
Milch 1,99 € / L
Brot 2,49 €
Joghurt 0,79 € / 500g
Apfel 1,29 € / kg
```

### Beispiel 2: Mit Separator

```
Milch | 1,99 € | L
Brot - 2,49 €
Joghurt / 0,79 € / 500g
```

### Beispiel 3: Kommentare (werden ignoriert)

```
# Milchprodukte
Milch 1,99 € / L
Joghurt 0,79 € / 500g

# Backwaren
Brot 2,49 €
```

## Integration in Pipeline

Der Text-Parser kann in die ALDI Nord Pipeline integriert werden:

```python
from prospekt_pipeline.aldi_nord.text_parser import TextParser
from prospekt_pipeline.aldi_nord.aldi_nord_processor import AldiNordProcessor

# Text-Parser für manuelle Eingaben
text_parser = TextParser()
manual_offers = text_parser.parse_file(Path("manual_input.txt"))

# Mit anderen Quellen mergen
processor = AldiNordProcessor()
# ... normal processing ...
# manual_offers können zu baseline_offers hinzugefügt werden
```

## Tipps

1. **Konsistenz**: Verwende das gleiche Format für alle Zeilen
2. **Einheiten**: Immer angeben für bessere Genauigkeit
3. **Preise**: Verwende `,` oder `.` als Dezimaltrennzeichen
4. **Kommentare**: Zeilen mit `#` werden ignoriert

