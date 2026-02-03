# Testing Guide

## Quick Start

### Im virtuellen Environment (empfohlen)

```bash
# Aktiviere das venv
source crawl4ai_env/bin/activate

# Oder wenn du bereits im venv bist:
cd /Users/romw24/dev/AppProjektRoman/roman_app/server

# Führe Tests aus
python3 -m pytest prospekt_pipeline/tests/ -v
```

### Mit dem Test-Script

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
./prospekt_pipeline/run_tests.sh
```

## Warum "command not found: pytest"?

Das System-Python hat pytest nicht installiert. pytest ist nur im virtuellen Environment (`crawl4ai_env`) installiert.

**Lösung:** Verwende `python3 -m pytest` statt nur `pytest`:

```bash
# ❌ Funktioniert nicht (pytest nicht im PATH)
pytest prospekt_pipeline/tests/

# ✅ Funktioniert (nutzt pytest aus dem venv)
python3 -m pytest prospekt_pipeline/tests/ -v

# ✅ Oder direkt aus dem venv
crawl4ai_env/bin/python -m pytest prospekt_pipeline/tests/ -v
```

## Alle Tests ausführen

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
python3 -m pytest prospekt_pipeline/tests/ -v
```

## Einzelne Tests

```bash
# HTML Parser
python3 -m pytest prospekt_pipeline/tests/test_html_parser.py -v

# Normalize (Unit-Preis Test)
python3 -m pytest prospekt_pipeline/tests/test_normalize.py -v

# PDF Parser (leere PDF Test)
python3 -m pytest prospekt_pipeline/tests/test_pdf_parser.py -v
```

## Erwartete Ergebnisse

Nach den Fixes sollten alle Tests durchlaufen:
- ✅ `test_normalize_parses_prices` - Unit-Preis wird korrekt geparst
- ✅ `test_pdf_parser_handles_empty` - Leere PDFs werden abgefangen

