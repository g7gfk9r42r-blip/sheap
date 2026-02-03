#!/usr/bin/env bash
set -eo pipefail

YEAR=2025
WEEK=W44
MARKETS=(aldi_nord aldi_sued kaufland penny norma nahkauf netto tegut denns)
BASE="$HOME/dev/AppProjektRoman/roman_app/server"

declare -A URLS=(
  ["aldi_nord"]="https://www.aldi-nord.de/prospekte/aldi-aktuell.html"
  ["aldi_sued"]="https://www.aldi-sued.de/de/angebote/prospekte.html"
  ["kaufland"]="https://filiale.kaufland.de/prospekte.html"
  ["penny"]="https://www.penny.de/angebote?ecid=sea_google_vs_brands_penn%7Cak%7Cenga%7Cn%7Csc-br-angebote_penny-prospekt_text-ad_1357786047_54421881756_kw:penny%20prospekt_mt:e_cr:669803514611_d:c&gad_source=1&gad_campaignid=1357786047&gbraid=0AAAAADj5UhANvy0L-GkpTD9ed6F4bxKjo&gclid=Cj0KCQjw35bIBhDqARIsAGjd-caoqzcJvZk70Dts_ScErBMqFwwTgkiV-6yGXyj_ufp3OZm6fH3vHvgaAtyVEALw_wcB"
  ["norma"]="https://www.norma-online.de/at/angebote/online-prospekt/2025-44_AT.pdf"
  ["nahkauf"]="https://www.nahkauf.de/angebote-im-markt"
  ["netto"]="https://www.netto-online.de/ueber-netto/Online-Prospekte.chtm?stores_id=4353"
  ["tegut"]="https://www.tegut.com/angebote-produkte/angebote.html?offers%5Bstore%5D=6064&cHash=8fc6b112f64eac0565ff1f4f4a75969b"
  ["denns"]="https://www.biomarkt.de/angebote/?utm_source=google&utm_medium=PaidSearch&utm_campaign=23165160142-188030848940&utm_term=denns%20prospekt&gad_source=1&gad_campaignid=23165160142&gbraid=0AAAAACmDzXNVGEesP7cUaUSm_g1b13hOb&gclid=Cj0KCQjw35bIBhDqARIsAGjd-cYU8L5SWxKiEKM8FxCSyANx0nRTtMYWSMTksr51z8GKV7zm1V8JtHgaAq-QEALw_wcB"
)

cd "$BASE"

echo "📥 Schritt 1: PDFs herunterladen..."
for m in "${MARKETS[@]}"; do
  PDF_PATH="media/prospekte/$m/$YEAR/$WEEK/leaflet.pdf"
  if [ ! -f "$PDF_PATH" ]; then
    URL="${URLS[$m]:-}"
    if [ -z "$URL" ]; then
      echo "  ⚠️  $m: Keine URL definiert"
      continue
    fi
    echo "  → $m: $URL"
    node tools/leaflets/fetch_pdf.mjs "$URL" "$PDF_PATH" || echo "  ⚠️  $m: Fehler beim Download"
  else
    echo "  ⏭️  $m: PDF existiert bereits"
  fi
done

echo ""
echo "🔍 Schritt 2: OCR/Extraktion..."
for m in "${MARKETS[@]}"; do
  PDF_PATH="media/prospekte/$m/$YEAR/$WEEK/leaflet.pdf"
  JSON_PATH="assets/offers/$YEAR/$WEEK/$m.json"
  ./tools/extract/extract_offers.sh "$PDF_PATH" "$m" "$JSON_PATH"
done

echo ""
echo "🔗 Schritt 3: Merge JSONs..."
MERGED="assets/offers/$YEAR/$WEEK/offers_merged.json"
mkdir -p "$(dirname "$MERGED")"
if command -v jq >/dev/null 2>&1; then
  jq -s 'reduce .[] as $x ({"week":"'"${YEAR}-${WEEK}"'","markets":[]}; .markets += [$x])' assets/offers/$YEAR/$WEEK/*.json > "$MERGED"
else
  echo '{"week":"'"${YEAR}-${WEEK}"'","markets":[]}' > "$MERGED"
  echo "⚠️  jq nicht gefunden, Merge übersprungen"
fi

echo ""
echo "📊 Statistik:"
TOTAL=0
for m in "${MARKETS[@]}"; do
  JSON_PATH="assets/offers/$YEAR/$WEEK/$m.json"
  if [ -f "$JSON_PATH" ]; then
    if command -v jq >/dev/null 2>&1; then
      COUNT=$(jq '.items | length' "$JSON_PATH" 2>/dev/null || echo "0")
    else
      COUNT=$(grep -c '"name"' "$JSON_PATH" 2>/dev/null || echo "0")
    fi
    TOTAL=$((TOTAL + COUNT))
    printf "  %-20s | %4d items\n" "$m" "$COUNT"
  else
    printf "  %-20s | %4d items\n" "$m" "0"
  fi
done
printf "  %-20s | %4d items\n" "GESAMT" "$TOTAL"
echo ""
echo "✅ Fertig! Merged JSON: $MERGED"

