#!/bin/bash
# 🍖 LIDL LEBENSMITTEL-AUTOMATISMUS - 1-KLICK!

echo "════════════════════════════════════════════════════════════════"
echo "🍖 LIDL KOCH-LEBENSMITTEL AUTOMATISMUS"
echo "════════════════════════════════════════════════════════════════"
echo ""

cd /Users/romw24/dev/AppProjektRoman/roman_app/server

# Finde neueste PDF
PDF=$(find media/prospekte/lidl -name "*.pdf" -type f | sort -r | head -1)

if [ -z "$PDF" ]; then
    echo "❌ Keine PDF gefunden!"
    echo "   Führe erst aus: npm run fetch:lidl"
    exit 1
fi

echo "📄 Gefundene PDF: $PDF"
echo ""

# Öffne PDF
echo "🔄 Öffne PDF..."
open "$PDF"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "⚠️  BITTE TEXT KOPIEREN:"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "1. In der geöffneten PDF: ⌘+A (alles markieren)"
echo "2. Dann: ⌘+C (kopieren)"
echo "3. Öffne input.txt: ⌘+Tab zu Terminal, dann:"
echo "   open -e input.txt"
echo "4. In input.txt: ⌘+V (einfügen), ⌘+S (speichern)"
echo ""
echo "5. Dann ENTER drücken um fortzufahren..."
echo ""
read -p "Bereit? [ENTER] "

echo ""
echo "🔄 Prüfe input.txt..."

if [ ! -f "input.txt" ]; then
    echo "❌ input.txt nicht gefunden!"
    exit 1
fi

SIZE=$(wc -c < input.txt | tr -d ' ')

if [ "$SIZE" -lt 10000 ]; then
    echo "⚠️  input.txt ist sehr klein ($SIZE Zeichen)"
    echo "   Hast du den kompletten Text kopiert?"
    echo ""
    read -p "Trotzdem fortfahren? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ input.txt hat $SIZE Zeichen"
echo ""

# Extrahiere Lebensmittel
echo "🤖 GPT-4 extrahiert Koch-Lebensmittel..."
echo ""

node extract_food_only.mjs

if [ $? -ne 0 ]; then
    echo ""
    echo "❌ Fehler beim Extrahieren!"
    exit 1
fi

# Prüfe Ergebnis
if [ ! -f "lidl_koch_lebensmittel.txt" ]; then
    echo "⚠️  Keine Lebensmittel extrahiert!"
    exit 0
fi

COUNT=$(grep -c "Produktname:" lidl_koch_lebensmittel.txt || echo "0")

if [ "$COUNT" -eq "0" ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "⚠️  KEINE KOCH-LEBENSMITTEL GEFUNDEN"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Diese Woche hat Lidl hauptsächlich Getränke/Non-Food."
    echo "Versuche es nächste Woche nochmal!"
    echo ""
    exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "✅ FERTIG! $COUNT KOCH-LEBENSMITTEL"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "📁 Gespeichert: lidl_koch_lebensmittel.txt"
echo ""

# Frage ob kopieren
read -p "Für ChatGPT kopieren? [Y/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    cat lidl_koch_lebensmittel.txt | pbcopy
    echo "✅ In Zwischenablage kopiert!"
    echo ""
    echo "🎯 Jetzt in ChatGPT einfügen:"
    echo "   'Erstelle mir 10 kreative Rezepte basierend auf diesen Lidl-Angeboten!'"
    echo ""
fi

echo "════════════════════════════════════════════════════════════════"
echo "🎉 FERTIG!"
echo "════════════════════════════════════════════════════════════════"

