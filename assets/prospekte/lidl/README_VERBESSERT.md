# ✅ Verbesserte LIDL Extraktion

## Was wurde verbessert:

Das Script `extract_lidl_offers_vision.py` wurde aktualisiert:

1. ✅ **Automatisches .env Loading**
   - Lädt `.env` automatisch aus Projekt-Root
   - Kein `source ../../../../.env` mehr nötig
   - Funktioniert auch ohne dotenv-Package (Fallback)

2. ✅ **Korrekte Pfade**
   - Script läuft von `assets/prospekte/lidl/`
   - Findet Projekt-Root automatisch
   - PDFs werden im aktuellen Verzeichnis gesucht

## Verwendung:

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/assets/prospekte/lidl

# Einfacher - .env wird automatisch geladen!
python3 extract_lidl_offers_vision.py --full-page --dpi 200
```

**Vereinfacht:** Kein `source ../../../../.env` mehr nötig! Das Script lädt `.env` automatisch.

## Alternativ (falls OPENAI_API_KEY nicht in .env):

```bash
export OPENAI_API_KEY="sk-proj-..."
python3 extract_lidl_offers_vision.py --full-page --dpi 200
```

## Was passiert:

1. Script bestimmt automatisch Projekt-Root: `assets/prospekte/lidl/` → `roman_app/`
2. Lädt `.env` aus `roman_app/.env`
3. Extrahiert Angebote aus PDFs im aktuellen Verzeichnis
4. Speichert JSON-Output

