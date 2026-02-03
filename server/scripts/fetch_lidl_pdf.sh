#!/bin/bash
# Einfaches Script zum Erstellen einer PDF vom Lidl-Prospekt

set -e

cd "$(dirname "$0")/.."

# URL aus .env oder als Argument
URL="${1:-${LIDL_LEAFLET_URL}}"

if [ -z "$URL" ]; then
  echo "❌ Keine URL angegeben!"
  echo ""
  echo "Usage:"
  echo "  ./scripts/fetch_lidl_pdf.sh [URL]"
  echo ""
  echo "Oder setze LIDL_LEAFLET_URL in .env:"
  echo "  LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/..."
  echo ""
  exit 1
fi

echo "📄 Erstelle PDF vom Lidl-Prospekt..."
echo "🔗 URL: $URL"
echo ""

LIDL_LEAFLET_URL="$URL" node tools/leaflets/fetch_lidl_leaflet.mjs

echo ""
echo "✅ Fertig! PDF wurde erstellt."
echo "📂 Pfad: media/prospekte/lidl/YYYY/WW/[ID]/leaflet.pdf"

