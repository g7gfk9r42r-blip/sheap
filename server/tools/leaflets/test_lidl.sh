#!/bin/bash
# Test-Script für Lidl Prospekt Downloader

cd "$(dirname "$0")/../.." || exit 1

YEAR=$(date +%Y)
WEEK=$(date +%V)
PDF_PATH="media/prospekte/lidl/${YEAR}/W${WEEK}/leaflet.pdf"

case "${1:-test}" in
  test)
    echo "🧪 Test: Prüfe ob Script startet..."
    npm run fetch:lidl 2>&1 | head -20
    ;;
  
  run)
    echo "📥 Starte vollständigen Download..."
    npm run fetch:lidl
    ;;
  
  open)
    if [ -f "$PDF_PATH" ]; then
      echo "📄 Öffne PDF: $PDF_PATH"
      open "$PDF_PATH"
    else
      echo "❌ PDF nicht gefunden: $PDF_PATH"
      echo "   Führe zuerst 'test_lidl.sh run' aus"
      exit 1
    fi
    ;;
  
  info)
    if [ -f "$PDF_PATH" ]; then
      echo "📊 PDF-Info:"
      ls -lh "$PDF_PATH"
      file "$PDF_PATH"
    else
      echo "❌ PDF nicht gefunden: $PDF_PATH"
    fi
    ;;
  
  path)
    echo "$(pwd)/$PDF_PATH"
    ;;
  
  *)
    echo "Usage: $0 [test|run|open|info|path]"
    echo ""
    echo "Commands:"
    echo "  test  - Schneller Test (prüft ob Script startet)"
    echo "  run   - Vollständiger Download"
    echo "  open  - PDF öffnen"
    echo "  info  - PDF-Informationen anzeigen"
    echo "  path  - PDF-Pfad ausgeben"
    exit 1
    ;;
esac

