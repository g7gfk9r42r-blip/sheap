# ✅ Fixes angewendet

## Problem 1: aldi_nord hat 0 Offers
**Ursache:** `_extract_base_price()` suchte nur nach `priceTiers`, aber JSON-Offers haben `prices` Array.

**Lösung:**
- `_extract_base_price()` erweitert: Unterstützt jetzt sowohl `priceTiers` als auch `prices`
- Prüft `is_reference` Flag, um Standard-Preis von Referenz-Preis zu unterscheiden
- Verbesserte Normalisierung in `_phase3_raw_ingest()`: Überspringt Offers ohne Titel oder Preis

## Problem 2: Quota-Fehler wird nicht richtig behandelt
**Ursache:** `QuotaExceededError` wurde nicht geworfen, daher greift Fallback nicht.

**Lösung:**
- `_call_vision_api()` wirft jetzt `QuotaExceededError` bei 429/insufficient_quota
- `_call_vision_api_raw()` wirft jetzt auch `QuotaExceededError`
- Pipeline fängt `QuotaExceededError` und fällt auf traditionelle PDF-Extraktion zurück

## Test

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/grocify_scraper
export OPENAI_API_KEY="..."
python3 weekly_pipeline.py --week-key 2025-W52
```

**Erwartet:**
- ✅ aldi_nord: 19 Offers (aus JSON)
- ✅ aldi_sued: Fallback auf traditionelle PDF-Extraktion bei Quota-Fehler
- ✅ Pipeline läuft durch, auch ohne GPT Vision

