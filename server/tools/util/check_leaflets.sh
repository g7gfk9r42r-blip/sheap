#!/usr/bin/env bash
set -euo pipefail

BASE="${1:-$PWD}"
YEAR="${2:-2025}"
WEEK="${3:-W44}"
THRESH=${4:-50000} # Bytes: PDFs darunter werden als Platzhalter gelöscht

shopt -s nullglob
while IFS= read -r -d '' pdf; do
  echo "=============================="
  echo "🔎 Prüfe: $pdf"
  dir="$(dirname "$pdf")"
  mkdir -p "$dir/__check"

  if command -v qpdf >/dev/null 2>&1; then
    echo "— qpdf --check —"
    qpdf --check "$pdf" || true
  fi

  if command -v pdfinfo >/dev/null 2>&1; then
    echo "— pdfinfo —"
    pdfinfo "$pdf" || true
  fi

  # Previews (erste/letzte Seite, wenn pdftoppm verfügbar)
  if command -v pdftoppm >/dev/null 2>&1; then
    first="$dir/__check/preview_first"
    last="$dir/__check/preview_last"
    pages=$(pdfinfo "$pdf" 2>/dev/null | awk -F': *' '/Pages:/ {print $2}')
    if [[ "$pages" =~ ^[0-9]+$ && "$pages" -ge 1 ]]; then
      pdftoppm -f 1 -l 1 -png "$pdf" "$first" >/dev/null 2>&1 || true
      pdftoppm -f "$pages" -l "$pages" -png "$pdf" "$last" >/dev/null 2>&1 || true
      echo "🖼  Previews: ${first}.png, ${last}.png"
    fi
  fi

  bytes=$(wc -c < "$pdf" | tr -d ' ')
  if [ "$bytes" -lt "$THRESH" ]; then
    echo "🗑  Entferne Platzhalter-PDF ($bytes Bytes): $pdf"
    rm -f "$pdf"
  fi
done < <(find "$BASE/media/prospekte" -path "*/${YEAR}/${WEEK}/leaflet.pdf" -type f -print0)

echo "✅ Check abgeschlossen."

