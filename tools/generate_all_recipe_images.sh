#!/bin/bash
# Generiert alle fehlenden Rezept-Bilder mit SDXL Pipeline

export REPLICATE_API_TOKEN="${REPLICATE_API_TOKEN:?Set REPLICATE_API_TOKEN in your shell/.env (do not commit tokens)}"

# Retailer-Liste (nur die wichtigsten zuerst)
RETAILERS=("aldi_nord" "aldi_sued" "biomarkt")

echo "🖼️  Generiere fehlende Rezept-Bilder..."
echo "=" * 60

for retailer in "${RETAILERS[@]}"; do
    echo ""
    echo "📦 Verarbeite: $retailer"
    ./server/tools/run_sdxl.sh "$retailer" 0
done

echo ""
echo "✅ Abgeschlossen!"
