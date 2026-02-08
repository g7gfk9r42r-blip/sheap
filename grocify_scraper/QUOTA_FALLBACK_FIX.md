# Quota-Fallback & JSON-Parsing Fix

## ✅ Behobene Probleme

### 1. OpenAI API Quota-Fehler (429)
- **Problem:** GPT Vision API Quota überschritten → Pipeline bricht ab
- **Lösung:** 
  - `QuotaExceededError` Exception hinzugefügt
  - Automatischer Fallback auf traditionelle PDF-Extraktion
  - Pipeline läuft weiter auch ohne GPT Vision

### 2. aldi_nord hat 0 Offers
- **Problem:** JSON-Parsing erkennt Recipe-Format nicht richtig
- **Lösung:**
  - Verbesserte Recipe-Format-Erkennung (prüft `is_offer_product` und `offer_price`)
  - Zusätzliche Indikatoren: `steps`, `portions`, `difficulty`
  - Test bestätigt: 19 Offers werden jetzt extrahiert ✅

## 🔧 Änderungen

### `src/extract/gpt_vision_extractor.py`
- `QuotaExceededError` Exception hinzugefügt
- Quota-Fehler werden erkannt und Exception geworfen

### `src/pipeline/cached_pipeline.py`
- Fallback auf traditionelle PDF-Extraktion bei Quota-Fehlern
- `_phase2_traditional_pdf_extraction()` Methode hinzugefügt
- Pipeline läuft weiter auch wenn GPT Vision fehlschlägt

### `src/extract/list_parser.py`
- Verbesserte Recipe-Format-Erkennung
- Prüft `is_offer_product` und zusätzliche Recipe-Indikatoren

## 🚀 Test

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper

export OPENAI_API_KEY="..."  # Auch wenn Quota überschritten

python3 weekly_pipeline.py --week-key 2025-W52
```

**Erwartetes Verhalten:**
- Bei Quota-Fehler: Fallback auf traditionelle PDF-Extraktion
- JSON-Parsing funktioniert (z.B. aldi_nord: 19 Offers)
- Pipeline läuft durch, auch ohne GPT Vision

## 📊 Status

✅ Quota-Fallback implementiert
✅ JSON-Parsing verbessert
✅ Pipeline robust gegen API-Fehler

