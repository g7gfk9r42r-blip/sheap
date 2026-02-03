#!/bin/bash
# Automatischer wöchentlicher Lidl-Update
# Holt neue Angebote + PDF und organisiert alles

set -e

echo "════════════════════════════════════════════════════════════════"
echo "🔄 LIDL WÖCHENTLICHER UPDATE"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd "$(dirname "$0")"

# Aktuelles Datum und Woche
CURRENT_YEAR=$(date +%Y)
CURRENT_WEEK=$(date +%V)
WEEK_KEY="${CURRENT_YEAR}-W${CURRENT_WEEK}"

echo "📅 Aktuelle Woche: ${WEEK_KEY}"
echo ""

# ============================================================================
# SCHRITT 1: Hole neue Angebote
# ============================================================================
echo "1️⃣  Hole aktuelle Lidl-Angebote..."
echo "────────────────────────────────────────────────────────────────"

if npm run fetch:lidl; then
    echo "✅ Angebote erfolgreich geholt!"
else
    echo "⚠️  Fehler beim Holen der Angebote"
    echo "💡 Verwende ggf. vorhandene Daten..."
fi

echo ""

# ============================================================================
# SCHRITT 2: Organisiere PDF
# ============================================================================
echo "2️⃣  Organisiere PDF..."
echo "────────────────────────────────────────────────────────────────"

# Erstelle Wochen-Ordner
WEEK_DIR="media/prospekte/lidl/${CURRENT_YEAR}/W${CURRENT_WEEK}"
mkdir -p "${WEEK_DIR}"

# Finde die neueste PDF
LATEST_PDF=$(ls -t media/prospekte/lidl/lidl_*.pdf 2>/dev/null | head -1)

if [ -n "$LATEST_PDF" ]; then
    # Kopiere PDF in Wochen-Ordner
    cp "${LATEST_PDF}" "${WEEK_DIR}/lidl_prospekt.pdf"
    echo "✅ PDF kopiert: ${WEEK_DIR}/lidl_prospekt.pdf"
    
    # Zeige Größe
    PDF_SIZE=$(du -h "${WEEK_DIR}/lidl_prospekt.pdf" | cut -f1)
    echo "📄 Größe: ${PDF_SIZE}"
else
    echo "⚠️  Keine PDF gefunden"
fi

echo ""

# ============================================================================
# SCHRITT 3: Exportiere Lebensmittel für ChatGPT
# ============================================================================
echo "3️⃣  Exportiere Lebensmittel..."
echo "────────────────────────────────────────────────────────────────"

if node export_only_food.mjs; then
    echo "✅ Export erfolgreich!"
    
    # Kopiere auch in den Wochen-Ordner
    if [ -f "lidl_for_chatgpt.txt" ]; then
        cp "lidl_for_chatgpt.txt" "${WEEK_DIR}/lidl_for_chatgpt.txt"
        
        OFFER_COUNT=$(grep -c "^## [0-9]" "lidl_for_chatgpt.txt" || echo "?")
        FILE_SIZE=$(du -h "lidl_for_chatgpt.txt" | cut -f1)
        
        echo "📊 ${OFFER_COUNT} Angebote exportiert"
        echo "💾 ${FILE_SIZE} Textdatei"
    fi
else
    echo "⚠️  Export fehlgeschlagen"
fi

echo ""

# ============================================================================
# SCHRITT 4: Zusammenfassung
# ============================================================================
echo "════════════════════════════════════════════════════════════════"
echo "✅ UPDATE ABGESCHLOSSEN"
echo "════════════════════════════════════════════════════════════════"
echo ""

echo "📁 Dateien in: ${WEEK_DIR}/"
ls -lh "${WEEK_DIR}/" 2>/dev/null | tail -n +2 | awk '{printf "   • %-30s %5s\n", $9, $5}'

echo ""
echo "🎯 NÄCHSTE SCHRITTE:"
echo ""
echo "1. Text für ChatGPT kopieren:"
echo "   cat ${WEEK_DIR}/lidl_for_chatgpt.txt | pbcopy"
echo ""
echo "2. PDF öffnen:"
echo "   open ${WEEK_DIR}/lidl_prospekt.pdf"
echo ""
echo "3. In ChatGPT einfügen:"
echo '   "Erstelle mir 10 Rezepte basierend auf diesen Lidl-Angeboten:"'
echo '   [Text einfügen]'
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""

# Optional: Automatisch kopieren
read -p "📋 Text jetzt in Zwischenablage kopieren? (j/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[JjYy]$ ]]; then
    cat "${WEEK_DIR}/lidl_for_chatgpt.txt" | pbcopy
    echo "✅ Text kopiert! Jetzt in ChatGPT einfügen."
fi

