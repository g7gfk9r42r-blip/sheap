#!/usr/bin/env bash
# Vollautomatische OCR-Extraktion aller PDFs für W44/2025
set -eo pipefail

YEAR=2025
WEEK=W44
BASE="$HOME/dev/AppProjektRoman/roman_app/server"
PROSPEKTE_DIR="$BASE/media/prospekte"
OUTPUT_DIR="$BASE/assets/offers/$YEAR/$WEEK"

cd "$BASE"

echo "🔍 Suche nach PDFs in media/prospekte/*/$YEAR/$WEEK/..."

# Finde alle PDFs rekursiv
PDFS=()
while IFS= read -r pdf; do
  PDFS+=("$pdf")
done < <(find "$PROSPEKTE_DIR" -type f -name "*.pdf" -path "*/$YEAR/$WEEK/*" 2>/dev/null || true)

if [ ${#PDFS[@]} -eq 0 ]; then
  echo "⚠️  Keine PDFs gefunden in $PROSPEKTE_DIR/*/$YEAR/$WEEK/"
  exit 0
fi

echo "📄 Gefunden: ${#PDFS[@]} PDF(s)"
echo ""

# Erstelle Output-Verzeichnis
mkdir -p "$OUTPUT_DIR"

# Verarbeite jedes PDF
EXTRACTED=0
for pdf in "${PDFS[@]}"; do
  # Extrahiere Marktname aus Pfad: media/prospekte/<markt>/...
  if [[ "$pdf" =~ /media/prospekte/([^/]+)/ ]]; then
    MARKT="${BASH_REMATCH[1]}"
  else
    # Fallback: Nutze Dateiname ohne Extension
    MARKT=$(basename "$pdf" .pdf | sed 's/[^a-z0-9_]/_/g')
  fi
  
  JSON_OUT="$OUTPUT_DIR/${MARKT}.json"
  
  echo "▶️  $MARKT: $(basename "$pdf")"
  ./tools/extract/extract_offers.sh "$pdf" "$MARKT" "$JSON_OUT" || {
    echo "  ⚠️  Fehler bei $MARKT, erstelle leeres JSON"
    echo "{\"market\":\"$MARKT\",\"items\":[]}" > "$JSON_OUT"
  }
  EXTRACTED=$((EXTRACTED + 1))
  echo ""
done

# Merge alle JSONs
echo "🔗 Merge JSONs..."
MERGED="$OUTPUT_DIR/offers_merged.json"

if command -v jq >/dev/null 2>&1; then
  # Sammle alle validen JSONs
  VALID_JSONS=()
  for json in "$OUTPUT_DIR"/*.json; do
    [ -f "$json" ] && [[ "$(basename "$json")" != "offers_merged.json" ]] && VALID_JSONS+=("$json")
  done
  
  if [ ${#VALID_JSONS[@]} -gt 0 ]; then
    jq -s 'reduce .[] as $x ({"week":"'"${YEAR}-${WEEK}"'","markets":[]}; .markets += [$x])' "${VALID_JSONS[@]}" > "$MERGED"
    echo "  ✅ Merged: $MERGED"
  else
    echo '{"week":"'"${YEAR}-${WEEK}"'","markets":[]}' > "$MERGED"
    echo "  ⚠️  Keine JSONs zum Mergen gefunden"
  fi
else
  echo '{"week":"'"${YEAR}-${WEEK}"'","markets":[]}' > "$MERGED"
  echo "  ⚠️  jq nicht gefunden, erstelle leeres Merged-JSON"
fi

# Statistik
echo ""
echo "📊 Statistik:"
echo "  ┌──────────────────────────┬──────────┐"
echo "  │ Markt                    │ Artikel  │"
echo "  ├──────────────────────────┼──────────┤"

TOTAL=0
for json in "$OUTPUT_DIR"/*.json; do
  [ -f "$json" ] || continue
  [[ "$(basename "$json")" == "offers_merged.json" ]] && continue
  
  MARKT=$(basename "$json" .json)
  if command -v jq >/dev/null 2>&1; then
    COUNT=$(jq '.items | length' "$json" 2>/dev/null || echo "0")
  else
    COUNT=$(grep -c '"name"' "$json" 2>/dev/null || echo "0")
  fi
  TOTAL=$((TOTAL + COUNT))
  printf "  │ %-24s │ %8d │\n" "$MARKT" "$COUNT"
done

echo "  ├──────────────────────────┼──────────┤"
printf "  │ %-24s │ %8d │\n" "GESAMT" "$TOTAL"
echo "  └──────────────────────────┴──────────┘"
echo ""
echo "✅ Fertig! $EXTRACTED PDF(s) verarbeitet."
echo "   Merged JSON: $MERGED"

