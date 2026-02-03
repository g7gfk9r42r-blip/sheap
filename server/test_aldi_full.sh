#!/bin/bash
# Full test script for ALDI Nord Vision AI - ALL PAGES

echo "🧪 ALDI NORD - VOLLSTÄNDIGE VERARBEITUNG"
echo "========================================"
echo ""
echo "📋 Dieser Test verarbeitet:"
echo "   - ALLE Seiten des PDFs"
echo "   - Baseline aus HTML + PDF"
echo "   - Vision AI findet fehlende Angebote"
echo "   - Vollständige Pipeline"
echo ""
echo "⏳ Starte in 3 Sekunden..."
sleep 3

cd /Users/romw24/dev/AppProjektRoman/roman_app/server

# Check .env
if [ ! -f .env ]; then
    echo "❌ .env file not found"
    exit 1
fi

# Run full pipeline
python3 -m prospekt_pipeline.aldi_nord.run_aldi_nord

echo ""
echo "✅ Fertig! Prüfe offers.json im Ordner"
