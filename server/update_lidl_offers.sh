#!/bin/bash
# Aktualisiert Lidl-Angebote und exportiert sie für ChatGPT

set -e

echo "========================================================================"
echo "🔄 LIDL ANGEBOTE AKTUALISIERUNG"
echo "========================================================================"
echo ""

cd "$(dirname "$0")"

# Schritt 1: Prüfe Dependencies
echo "1️⃣  Prüfe Dependencies..."
if ! command -v node &> /dev/null; then
    echo "❌ Node.js nicht gefunden!"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm nicht gefunden!"
    exit 1
fi

echo "   ✅ Node.js $(node --version)"
echo "   ✅ npm $(npm --version)"

# Schritt 2: Installiere Dependencies (falls nötig)
if [ ! -d "node_modules" ]; then
    echo ""
    echo "2️⃣  Installiere Dependencies (einmalig)..."
    npm install
else
    echo ""
    echo "2️⃣  Dependencies bereits installiert ✅"
fi

# Schritt 3: Prüfe Playwright
if [ ! -d "node_modules/playwright" ]; then
    echo ""
    echo "3️⃣  Installiere Playwright..."
    npx playwright install chromium
else
    echo ""
    echo "3️⃣  Playwright bereits installiert ✅"
fi

# Schritt 4: Hole aktuelle Angebote
echo ""
echo "4️⃣  Hole aktuelle Lidl-Angebote..."
echo "   ⏳ Dies kann 30-60 Sekunden dauern..."
echo ""

if npm run fetch:lidl; then
    echo ""
    echo "   ✅ Angebote erfolgreich geholt!"
else
    echo ""
    echo "   ⚠️  Fehler beim Holen der Angebote"
    echo "   💡 Verwende vorhandene Angebote..."
fi

# Schritt 5: Erstelle offers.json aus View
echo ""
echo "5️⃣  Exportiere Angebote als JSON..."
npm run view:lidl > offers.json 2>/dev/null || echo "[]" > offers.json

OFFER_COUNT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('offers.json', 'utf-8')).length)" 2>/dev/null || echo "0")
echo "   ✅ $OFFER_COUNT Angebote in offers.json"

# Schritt 6: Exportiere für ChatGPT
echo ""
echo "6️⃣  Exportiere für ChatGPT..."
node export_for_chatgpt.mjs

# Schritt 7: Fertig
echo ""
echo "========================================================================"
echo "✅ FERTIG!"
echo "========================================================================"
echo ""

if [ -f "lidl_for_chatgpt.txt" ]; then
    FILE_SIZE=$(wc -c < lidl_for_chatgpt.txt)
    FILE_SIZE_KB=$((FILE_SIZE / 1024))
    
    echo "📁 Datei: lidl_for_chatgpt.txt"
    echo "📊 Größe: ${FILE_SIZE_KB} KB"
    echo ""
    echo "🎯 NÄCHSTE SCHRITTE:"
    echo ""
    echo "1. Text kopieren:"
    echo "   cat lidl_for_chatgpt.txt | pbcopy"
    echo ""
    echo "2. Oder Datei öffnen:"
    echo "   open lidl_for_chatgpt.txt"
    echo ""
    echo "3. In ChatGPT einfügen mit:"
    echo '   "Erstelle mir 10 Rezepte basierend auf diesen Lidl-Angeboten:"'
    echo '   [Text einfügen]'
    echo ""
    echo "========================================================================"
else
    echo "❌ Fehler: lidl_for_chatgpt.txt nicht erstellt"
    exit 1
fi

