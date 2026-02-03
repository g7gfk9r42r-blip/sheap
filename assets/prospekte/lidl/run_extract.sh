#!/bin/bash
# Script zum Ausführen von extract_lidl_offers_vision.py

cd "$(dirname "$0")"

# Lade .env aus Projekt-Root
if [ -f ../../../../.env ]; then
    set -a
    source ../../../../.env
    set +a
    echo "✅ .env geladen"
fi

# Prüfe ob API-Key gesetzt ist
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY nicht gesetzt!"
    echo "   Bitte setze ihn in .env Datei oder:"
    echo "   export OPENAI_API_KEY='dein-key'"
    exit 1
fi

echo "🚀 Starte extract_lidl_offers_vision.py..."
python3 extract_lidl_offers_vision.py > run.log 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Script erfolgreich ausgeführt"
    echo "📋 Log: run.log"
else
    echo "❌ Fehler beim Ausführen"
    echo "📋 Log:"
    tail -20 run.log
fi
