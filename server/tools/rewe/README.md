# REWE Angebots-Scraper

⚠️ **RECHTLICHE HINWEISE**: Bitte prüfe vor Nutzung die REWE AGB und robots.txt.

## Installation

```bash
pip install -r requirements.txt
```

## Nutzung

### Einfache Abfrage

```bash
python fetch_rewe_offers.py 53113
```

### Mit Ausgabe-Datei

```bash
python fetch_rewe_offers.py 53113 -o angebote_rewe_2025-12-01.json
```

### Als Python-Modul

```python
from fetch_rewe_offers import fetch_rewe_offers

offers = fetch_rewe_offers("53113")
for offer in offers:
    print(f"{offer['title']}: {offer['price_str']}")
```

## Wöchentliche Ausführung

### Mit Cron (Linux/Mac)

```bash
# Jeden Montag um 8:00 Uhr
0 8 * * 1 cd /path/to/tools/rewe && python fetch_rewe_offers.py 53113 -o "angebote_rewe_$(date +\%Y\%m\%d).json"
```

### Mit Python-Script

```python
#!/usr/bin/env python3
import subprocess
from datetime import datetime

zip_code = "53113"
output_file = f"angebote_rewe_{datetime.now().strftime('%Y%m%d')}.json"

subprocess.run([
    "python", "fetch_rewe_offers.py",
    zip_code,
    "-o", output_file
])
```

## Anpassung bei Strukturänderungen

Wenn REWE die HTML-Struktur ändert, passe folgende Funktionen an:

1. **`_extract_offers_from_html()`**: CSS-Selektoren für Angebots-Karten
2. **`_extract_offer_from_card()`**: Selektoren für Titel, Preis, Bild
3. **`_extract_validity_period()`**: Pattern für Gültigkeitszeitraum

**Tipp**: Nutze Browser DevTools (Inspect Element) um aktuelle Selektoren zu finden.

## Erweiterung für andere Märkte

1. Erstelle Basis-Klasse `BaseMarketScraper`:
```python
class BaseMarketScraper:
    def fetch_offers(self, zip_code: str) -> List[Dict]:
        raise NotImplementedError
```

2. Implementiere für jeden Markt:
```python
class EdekaScraper(BaseMarketScraper):
    def fetch_offers(self, zip_code: str) -> List[Dict]:
        # EDEKA-spezifische Logik
        pass
```

3. Nutze Factory-Pattern:
```python
def get_scraper(market: str) -> BaseMarketScraper:
    scrapers = {
        'rewe': ReweScraper(),
        'edeka': EdekaScraper(),
        'kaufland': KauflandScraper(),
    }
    return scrapers.get(market.lower())
```

