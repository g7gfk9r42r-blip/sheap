#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-$(cd "$(dirname "$0")/../.." && pwd)}"
YEAR="${1:-2025}"
WEEK="${2:-W44}"
OPEN_FLAG="${3:-}"

# Hilfsfunktion: Prüfe ein PDF und rendere 1. & letzte Seite als PNG
check_one () {
  local pdf="$1"
  [ -f "$pdf" ] || { echo "⚠️  fehlt: $pdf"; return; }

  echo "=============================="
  echo "🔎 Prüfe: $pdf"
  echo "— qpdf --check —"
  qpdf --check "$pdf" || echo "❗ qpdf meldet Probleme"

  echo "— pdfinfo —"
  pdfinfo "$pdf" | egrep 'Title|Creator|Producer|Pages|Page size|CreationDate|ModDate' || true

  # Seitenzahl ermitteln
  local pages
  pages="$(pdfinfo "$pdf" | awk '/^Pages:/ {print $2}')"
  [ -z "${pages:-}" ] && pages=1

  # Render erste & letzte Seite als PNG
  local outdir
  outdir="$(dirname "$pdf")/__check"
  mkdir -p "$outdir"
  pdftoppm -f 1 -l 1 -png "$pdf" "$outdir/preview_first" >/dev/null 2>&1 || true
  pdftoppm -f "$pages" -l "$pages" -png "$pdf" "$outdir/preview_last" >/dev/null 2>&1 || true
  echo "🖼  Previews:"
  echo "   $outdir/preview_first.png"
  echo "   $outdir/preview_last.png"

  # Kurze Textprobe (erste Seite)
  local tmptxt
  tmptxt="$(mktemp)"
  pdftotext -f 1 -l 1 -layout -nopgbrk "$pdf" "$tmptxt" >/dev/null 2>&1 || true
  echo "— Textprobe (erste ~300 Zeichen) —"
  head -c 300 "$tmptxt" | tr -d '\000' || echo "(kein extrahierbarer Text auf Seite 1)"
  echo; echo
  rm -f "$tmptxt"

  # Optional in Vorschau öffnen
  if [ "$OPEN_FLAG" = "--open" ]; then
    open "$pdf" >/dev/null 2>&1 || true
    [ -f "$outdir/preview_first.png" ] && open "$outdir/preview_first.png" >/dev/null 2>&1 || true
    [ -f "$outdir/preview_last.png" ]  && open "$outdir/preview_last.png"  >/dev/null 2>&1 || true
  fi
}

# Alle vorhandenen leaflet.pdf für Woche prüfen
mapfile -t pdfs < <(find "$BASE/media/prospekte" -path "*/${YEAR}/${WEEK}/leaflet.pdf" -type f | sort)
if [ "${#pdfs[@]}" -eq 0 ]; then
  echo "ℹ️  Keine PDFs gefunden unter $BASE/media/prospekte/*/${YEAR}/${WEEK}/leaflet.pdf"
  exit 0
fi

for f in "${pdfs[@]}"; do
  check_one "$f"
done

echo "✅ Check abgeschlossen. (Previews liegen im __check/ Ordner neben jedem PDF)"
