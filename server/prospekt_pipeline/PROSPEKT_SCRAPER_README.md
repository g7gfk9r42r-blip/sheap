# Prospekt Pipeline - Selbstheilende Supermarkt-Prospekt-Parser

Eine vollständig selbstheilende, modulare Parsing-Pipeline für Supermarkt-Prospekte (Flyer). Dieses System **produziert immer** gültige `offers.json` Dateien, auch wenn die Eingabedaten unvollständig, defekt oder chaotisch sind.

## 🎯 Kernphilosophie

**Fehlertoleranz ist Priorität #1.** Das System stürzt niemals ab und produziert immer Output, auch wenn es nur eine leere Angebotsliste mit detaillierten Fehlermetadaten ist.

## 📁 Architektur

```
prospekt_pipeline/
├── parsers/              # Extraktions-Module
│   ├── html_parser.py        # BeautifulSoup-basiertes HTML-Parsing (confidence: 1.0)
│   ├── pdf_parser.py         # pdfminer Text-Extraktion (confidence: 0.7)
│   ├── ocr_parser.py         # pytesseract OCR-Fallback (confidence: 0.5)
│   └── fallback_parser.py    # Letzte Heuristik (confidence: 0.3)
├── pipeline/            # Orchestrierung
│   ├── process_prospekt.py   # Hauptprozessor (stürzt nie ab)
│   ├── merge_results.py      # Deduplizierung & Merging
│   ├── normalize.py          # Daten-Normalisierung
│   └── validate.py           # Input-Validierung
├── utils/               # Gemeinsame Utilities
│   ├── logger.py             # Custom Logging mit FALLBACK-Level
│   ├── exceptions.py         # Exception-Hierarchie
│   ├── file_loader.py        # Sichere Datei-I/O
│   ├── ocr_cleaner.py        # OCR-Text-Bereinigung
│   └── brand_heuristics.json # Markenerkennungs-Regeln
├── cli/                 # Command-Line Interface
│   └── run_parser.py         # Haupt-Einstiegspunkt
└── tests/               # Umfassende Test-Suite
    ├── test_html_parser.py
    ├── test_pdf_parser.py
    ├── test_ocr_parser.py
    ├── test_fallback_parser.py
    ├── test_merge.py
    ├── test_normalize.py
    ├── test_confidence_scores.py
    ├── test_process_integration.py
    └── test_sample_pipeline.py
```

## 🚀 Schnellstart

### Installation

```bash
# Alle Dependencies installieren
pip install -r prospekt_pipeline/requirements.txt

# Für Tests (optional)
pip install pytest pytest-cov
```

### Verwendung

```bash
# Alle Prospekt-Ordner rekursiv verarbeiten
python3 -m prospekt_pipeline.cli.run_parser --base media/prospekte

# Einzelnen Ordner verarbeiten
python3 -m prospekt_pipeline.cli.run_parser --folder media/prospekte/edeka/berlin

# Mit custom Log-Level
python3 -m prospekt_pipeline.cli.run_parser --base media/prospekte --log-level DEBUG
```

### Erwartete Ordnerstruktur

```
media/prospekte/
├── edeka/
│   ├── berlin/
│   │   ├── raw.html
│   │   ├── raw.pdf
│   │   └── offers.json  (generiert)
│   └── münchen/
│       ├── raw.html
│       ├── raw.pdf
│       └── offers.json  (generiert)
└── lidl/
    └── ...
```

## 🔄 Verarbeitungs-Pipeline

1. **Quellen validieren** - Prüft HTML/PDF Verfügbarkeit und Qualität
2. **HTML-Parsing** - Primäre Extraktion (höchste Confidence)
3. **PDF-Parsing** - Fallback wenn HTML fehlt/unvollständig
4. **OCR-Parsing** - Wenn PDF-Text-Extraktion fehlschlägt
5. **Fallback-Parsing** - Letzte Text-Scavenging-Heuristik
6. **Ergebnisse mergen** - Dedupliziert und kombiniert alle Quellen
7. **Normalisieren** - Bereinigt und standardisiert Daten
8. **JSON schreiben** - Produziert immer gültigen Output

## 📊 Output-Format

```json
{
  "metadata": {
    "folder": "media/prospekte/edeka/berlin",
    "html_candidates": 45,
    "pdf_candidates": 42,
    "ocr_candidates": 8,
    "fallback_candidates": 0,
    "final_offers": 38
  },
  "offers": [
    {
      "title": "test kaffee",
      "price": 4.99,
      "unit_price": 9.98,
      "confidence": 1.0,
      "source": "html"
    }
  ]
}
```

## 🛡️ Fehlerbehandlung

- **HTML-Parsing schlägt fehl** → Fällt zurück auf PDF
- **PDF-Parsing schlägt fehl** → Fällt zurück auf OCR
- **OCR schlägt fehl** → Fällt zurück auf Text-Scavenging
- **Alle Parser schlagen fehl** → Schreibt leere `offers.json` mit Fehlermetadaten
- **Datei-I/O-Fehler** → Geloggt, Verarbeitung setzt fort
- **Ungültige Daten** → Normalisiert zu sicheren Standardwerten

## 🧪 Testing

```bash
# Alle Tests ausführen
./prospekt_pipeline/run_tests.sh

# Oder direkt
python3 -m pytest prospekt_pipeline/tests/ -v

# Spezifischen Test ausführen
python3 -m pytest prospekt_pipeline/tests/test_html_parser.py -v
```

## 📝 Confidence-Scores

- **HTML Parser**: 1.0 (strukturierte Daten, höchste Zuverlässigkeit)
- **PDF Parser**: 0.7 (Text-Extraktion, mittlere Zuverlässigkeit)
- **OCR Parser**: 0.5 (Bilderkennung, niedrigere Zuverlässigkeit)
- **Fallback Parser**: 0.3 (heuristisches Matching, niedrigste Zuverlässigkeit)

## 🔧 Konfiguration

### Brand Heuristics

Bearbeite `utils/brand_heuristics.json` um bekannte Marken und schwache Suffixe hinzuzufügen:

```json
{
  "brands": ["coca cola", "milka", "lindt"],
  "weak_suffixes": ["original", "classic", "medium"]
}
```

### Logging

Der Logger unterstützt ein custom `FALLBACK`-Level (25) für Fallback-Operationen:

```python
from prospekt_pipeline.utils.logger import get_logger
logger = get_logger("my_module")
logger.fallback("Using fallback parser")
```

## 🎓 Hauptfeatures

- ✅ **Stürzt nie ab** - Alle Exceptions werden abgefangen und geloggt
- ✅ **Produziert immer JSON** - Auch wenn leer
- ✅ **Selbstheilend** - Versucht automatisch Fallbacks
- ✅ **Deduplizierung** - Fuzzy-Matching verhindert Duplikate
- ✅ **Confidence-Scoring** - Verfolgt Datenqualität
- ✅ **Umfassendes Logging** - INFO, WARNING, FALLBACK, ERROR
- ✅ **Type-annotated** - Vollständige Type-Hints für Python 3.11+
- ✅ **Getestet** - Umfassende Test-Suite

## 📚 Modul-Dokumentation

### Parser

- **html_parser.py**: Extrahiert strukturierte Daten aus HTML mit BeautifulSoup
- **pdf_parser.py**: Extrahiert Text aus PDF mit pdfminer
- **ocr_parser.py**: OCR-Fallback mit pytesseract und Preprocessing
- **fallback_parser.py**: Letzte Text-Pattern-Matching-Heuristik

### Pipeline

- **process_prospekt.py**: Haupt-Orchestrator (stürzt nie ab)
- **merge_results.py**: Dedupliziert und merged Parser-Outputs
- **normalize.py**: Bereinigt und standardisiert Angebotsdaten
- **validate.py**: Validiert Eingabedateien vor der Verarbeitung

### Utils

- **logger.py**: Custom Logging mit FALLBACK-Level
- **exceptions.py**: Exception-Hierarchie
- **file_loader.py**: Sichere Datei-I/O-Operationen
- **ocr_cleaner.py**: OCR-Text-Bereinigungs-Utilities

## 🐛 Troubleshooting

### Keine Angebote extrahiert

- Prüfe Logs auf Parser-Fehler
- Verifiziere HTML/PDF-Dateien sind gültig
- Versuche OCR-Preprocessing-Qualität zu erhöhen
- Prüfe brand_heuristics.json Konfiguration

### Niedrige Confidence-Scores

- HTML-Parser bevorzugt über PDF/OCR
- Fehlende Preise reduzieren Confidence
- Einheitspreise erhöhen Confidence
- Fallback-Parser hat niedrigste Confidence

### Langsame Verarbeitung

- OCR ist der langsamste Schritt (läuft nur wenn nötig)
- PDF-Parsing ist schneller als OCR
- HTML-Parsing ist am schnellsten
- Erwäge parallele Ordner-Verarbeitung

## 📄 Lizenz

Internes Projekt - Alle Rechte vorbehalten.

