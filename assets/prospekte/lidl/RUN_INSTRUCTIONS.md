# LIDL Extraktion - So führst du es aus

## ⚠️ Problem: Rate Limits

Das Script kann sehr lange dauern wegen OpenAI Rate Limits. Neue Features:

- ✅ **Checkpoint-System**: Speichert Fortschritt automatisch
- ✅ **Test-Modus**: Nur erste 5 Seiten (`--test`)
- ✅ **Limit**: Maximal X Seiten (`--limit X`)
- ✅ **Skip Rate Limits**: Überspringe statt warten (`--skip-rate-limit`)
- ✅ **Stoppbar**: Ctrl+C speichert teilweise Ergebnisse

## 🚀 Empfohlene Ausführung

### Option 1: Test-Modus (Erste 5 Seiten)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/lidl
source ../../../../.env
python3 extract_lidl_offers_vision.py --test
```

### Option 2: Mit Limit (z.B. 20 Seiten)
```bash
python3 extract_lidl_offers_vision.py --limit 20
```

### Option 3: Skip Rate Limits (schneller, aber weniger vollständig)
```bash
python3 extract_lidl_offers_vision.py --skip-rate-limit
```

### Option 4: Vollständig (dauert sehr lange!)
```bash
python3 extract_lidl_offers_vision.py
```

## 📋 Checkpoint-System

Das Script speichert automatisch einen Checkpoint nach jeder 5. Seite in `.extraction_checkpoint.json`.

Falls du das Script stoppst (Ctrl+C) oder es abstürzt, kannst du es einfach neu starten - es setzt automatisch dort fort, wo es aufgehört hat.

Um von vorne zu beginnen, lösche die Checkpoint-Datei:
```bash
rm .extraction_checkpoint.json
```

## 🛑 Script stoppen

Wenn das Script zu lange läuft:
1. Drücke `Ctrl+C` im Terminal
2. Das Script speichert automatisch alle bisher extrahierten Angebote in `lidl.json`
3. Du kannst später weitermachen (Checkpoint-System)

## ❌ Problem: zsh-Fehler

Der Fehler `zsh: unknown file attribute: b/i` kommt, wenn du mehrere Zeilen auf einmal kopierst/einfügst.

**Lösung:** Führe Befehle einzeln aus, nicht alle auf einmal!

## 📋 Der Prompt

Der Prompt ist bereits im Script (`EXTRACTION_PROMPT`) und funktioniert wie letzte Woche.
Siehe auch: `LIDL_EXTRACTION_PROMPT.txt`
