#!/bin/bash
# Weekly Recipe Refresh Pipeline - Einfaches Script

set -e  # Exit on error

# Projekt-Root
PROJECT_ROOT="/Users/romw24/dev/AppProjektRoman/roman_app"
cd "$PROJECT_ROOT"

echo "🚀 Weekly Recipe Refresh Pipeline"
echo "================================"
echo ""

# Prüfe Python3
if ! command -v python3 &> /dev/null; then
    echo "❌ python3 nicht gefunden!"
    echo "   Installiere Python 3: brew install python3"
    exit 1
fi

echo "✅ Python3 gefunden: $(python3 --version)"
echo ""

# Prüfe REPLICATE_API_TOKEN
if [ -z "$REPLICATE_API_TOKEN" ]; then
    echo "⚠️  REPLICATE_API_TOKEN nicht gesetzt!"
    echo ""
    echo "Bitte setze den Token:"
    echo "  export REPLICATE_API_TOKEN='r8_dein_token_hier'"
    echo ""
    echo "Oder füge ihn in diesem Script hinzu (Zeile 22)."
    exit 1
fi

echo "✅ REPLICATE_API_TOKEN gesetzt"
echo ""

# Parse Arguments
IMAGE_BACKEND="${1:-replicate}"  # Default: replicate
DRY_RUN="${2:-false}"            # Default: false
ONLY_MARKETS="${3:-}"            # Optional: comma-separated list

# Build command
CMD="python3 tools/weekly_refresh.py \
  --input assets/prospekte \
  --out assets/recipes \
  --images assets/images/recipes \
  --image-backend $IMAGE_BACKEND \
  --strict"

if [ "$DRY_RUN" = "dry-run" ] || [ "$DRY_RUN" = "true" ]; then
    CMD="$CMD --dry-run"
    echo "⚠️  DRY-RUN MODUS: Keine Dateien werden geschrieben"
fi

if [ -n "$ONLY_MARKETS" ]; then
    CMD="$CMD --only $ONLY_MARKETS"
    echo "🎯 Nur Märkte: $ONLY_MARKETS"
fi

echo "📋 Befehl:"
echo "$CMD"
echo ""
echo "================================"
echo ""

# Execute
eval $CMD

