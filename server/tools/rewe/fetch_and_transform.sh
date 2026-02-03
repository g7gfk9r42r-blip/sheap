#!/usr/bin/env bash
# REWE Angebote holen und transformieren
set -eo pipefail

YEAR="${YEAR:-2025}"
WEEK="${WEEK:-W44}"
REWE_MARKET_ID="${REWE_MARKET_ID:-440884}"

BASE="$HOME/dev/AppProjektRoman/roman_app/server"
cd "$BASE" || exit 1

OUT="media/prospekte/rewe/${YEAR}/${WEEK}"
echo "📥 REWE Angebote holen für Markt ${REWE_MARKET_ID}..."
node tools/rewe/fetch_rewe_offers.mjs "https://www.rewe.de/angebote/?market=${REWE_MARKET_ID}" "$OUT"

echo ""
echo "🔄 Transformiere zu Grocify-Format..."
YEAR="$YEAR" WEEK="$WEEK" node tools/rewe/transform_rewe_offers.mjs

echo ""
echo "🔍 Prüfe Leaflets..."
./tools/util/check_leaflets.sh "$BASE" "$YEAR" "$WEEK" 50000

echo ""
echo "🔗 Merge alle Angebote..."
./tools/util/merge_offers.sh "$YEAR" "$WEEK"

echo ""
echo "📂 Relevante Dateien:"
echo "  - REWE raw:     media/prospekte/rewe/${YEAR}/${WEEK}/raw.json   (falls vorhanden)"
echo "  - REWE offers:  media/prospekte/rewe/${YEAR}/${WEEK}/offers.json"
echo "  - REWE leaflet: media/prospekte/rewe/${YEAR}/${WEEK}/leaflet.pdf (falls >50KB behalten)"
echo "  - Grocify:      assets/offers/${YEAR}/${WEEK}/rewe.json"
echo "  - Merged:       assets/offers/${YEAR}/${WEEK}/offers_merged.json"
echo "✅ Fertig."

