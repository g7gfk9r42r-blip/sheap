#!/bin/bash
# Helper Script: Kopiert Angebots-JSONs vom Server-Verzeichnis nach assets/data/
# und benennt sie im korrekten Format um

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SERVER_DIR="$PROJECT_ROOT/server/media/prospekte"
ASSETS_DIR="$PROJECT_ROOT/assets/data"

# Erstelle assets/data/ falls nicht vorhanden
mkdir -p "$ASSETS_DIR"

# Aktuelle Woche für Dateinamen
WEEK=$(date +%Y-W%V)  # Format: 2025-W49
DATE=$(date +%Y%m%d)  # Format: 20250101

echo "📋 Copying offer JSON files to assets/data/"
echo "   Using date format: $WEEK"
echo ""

# Funktion zum Kopieren einer Datei
copy_offer_file() {
    local source_file="$1"
    local supermarket="$2"
    local target_file="$ASSETS_DIR/angebote_${supermarket}_${WEEK}.json"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$target_file"
        echo "✅ Copied: $(basename "$source_file") → $(basename "$target_file")"
        return 0
    else
        return 1
    fi
}

# Zähle kopierte Dateien
copied=0

# REWE
if [ -f "$SERVER_DIR/rewe/rewe.json" ]; then
    copy_offer_file "$SERVER_DIR/rewe/rewe.json" "rewe" && ((copied++))
fi

# LIDL
if [ -f "$SERVER_DIR/lidl/lidl.json" ]; then
    copy_offer_file "$SERVER_DIR/lidl/lidl.json" "lidl" && ((copied++))
fi

# EDEKA (Hauptdatei)
if [ -f "$SERVER_DIR/edeka/edeka.json" ]; then
    copy_offer_file "$SERVER_DIR/edeka/edeka.json" "edeka" && ((copied++))
fi

# ALDI Nord
if [ -f "$SERVER_DIR/aldi_nord/aldi_nord.json" ]; then
    copy_offer_file "$SERVER_DIR/aldi_nord/aldi_nord.json" "aldi_nord" && ((copied++))
fi

# ALDI Süd
if [ -f "$SERVER_DIR/aldi_sued/aldi_sued.json" ]; then
    copy_offer_file "$SERVER_DIR/aldi_sued/aldi_sued.json" "aldi_sued" && ((copied++))
fi

# NETTO
if [ -f "$SERVER_DIR/netto/netto.json" ]; then
    copy_offer_file "$SERVER_DIR/netto/netto.json" "netto" && ((copied++))
fi

echo ""
if [ $copied -eq 0 ]; then
    echo "⚠️  No offer files found in $SERVER_DIR"
    echo "   Please ensure offer JSON files exist in the server directory"
    exit 1
else
    echo "✅ Copied $copied file(s) to $ASSETS_DIR"
    echo ""
    echo "You can now run:"
    echo "  dart run tools/generate_recipes_from_offers.dart"
fi

