#!/bin/bash
# Holt automatisch das Lidl-Prospekt für nächste Woche

set -e

echo "════════════════════════════════════════════════════════════════"
echo "📅 LIDL PROSPEKT FÜR NÄCHSTE WOCHE"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd "$(dirname "$0")"

# Berechne nächste Woche
NEXT_WEEK=$(date -v+1w +%V 2>/dev/null || date -d "+1 week" +%V)
NEXT_YEAR=$(date -v+1w +%Y 2>/dev/null || date -d "+1 week" +%Y)
WEEK_KEY="${NEXT_YEAR}-W${NEXT_WEEK}"

echo "📆 Nächste Woche: ${WEEK_KEY}"
echo "📆 Datum: 15.12.2025 - 21.12.2025"
echo ""

# Erstelle Ziel-Ordner
TARGET_DIR="media/prospekte/lidl/${NEXT_YEAR}/W${NEXT_WEEK}"
mkdir -p "${TARGET_DIR}"

echo "1️⃣  Hole Lidl-Prospekt..."
echo "────────────────────────────────────────────────────────────────"
echo ""

# Hole das Prospekt (verwendet automatisch das aktuelle)
if npm run fetch:lidl; then
    echo ""
    echo "✅ Prospekt erfolgreich geholt!"
    echo ""
    
    # Finde die neueste PDF
    LATEST_PDF=$(ls -t media/prospekte/lidl/lidl_*.pdf 2>/dev/null | head -1)
    
    if [ -n "$LATEST_PDF" ]; then
        # Kopiere in Wochen-Ordner
        cp "${LATEST_PDF}" "${TARGET_DIR}/lidl_prospekt.pdf"
        
        PDF_SIZE=$(du -h "${TARGET_DIR}/lidl_prospekt.pdf" | cut -f1)
        
        echo "════════════════════════════════════════════════════════════════"
        echo "✅ FERTIG!"
        echo "════════════════════════════════════════════════════════════════"
        echo ""
        echo "📁 PDF gespeichert:"
        echo "   ${TARGET_DIR}/lidl_prospekt.pdf"
        echo ""
        echo "📊 Größe: ${PDF_SIZE}"
        echo ""
        echo "🎯 PDF ÖFFNEN:"
        echo "   open ${TARGET_DIR}/lidl_prospekt.pdf"
        echo ""
        echo "📋 ODER DIREKT:"
        echo "   open $(pwd)/${TARGET_DIR}/lidl_prospekt.pdf"
        echo ""
        echo "════════════════════════════════════════════════════════════════"
    else
        echo "⚠️  Keine PDF gefunden"
    fi
else
    echo ""
    echo "❌ Fehler beim Holen des Prospekts"
    echo ""
    echo "💡 Versuche es später nochmal oder führe manuell aus:"
    echo "   npm run fetch:lidl"
fi

