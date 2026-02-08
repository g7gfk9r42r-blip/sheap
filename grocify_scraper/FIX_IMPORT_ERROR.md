# Import-Fehler behoben

## Problem
```
ImportError: cannot import name 'extract_text_from_pdf' from 'src.extract.pdf_extractor'
```

## Lösung
- `extract_text_from_pdf` existiert nicht als Funktion
- Stattdessen: `PDFExtractor` Klasse verwenden
- Import korrigiert: `from ..extract.pdf_extractor import PDFExtractor`

## Shell-Problem (dquote>)
Wenn die Shell im `dquote>` Prompt hängt:
1. Drücke `Ctrl+C` um abzubrechen
2. Oder beende das Zitat mit `"` und Enter

**Korrekter Befehl:**
```bash
export OPENAI_API_KEY="sk-proj-..."
python3 weekly_pipeline.py --week-key 2025-W52
```

**NICHT:**
```bash
export OPENAI_API_KEY="sk-proj-...  # <- Unvollständiges Zitat!
```

