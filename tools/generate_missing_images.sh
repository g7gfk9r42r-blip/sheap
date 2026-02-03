#!/bin/bash
# Generiert alle fehlenden Bilder für aldi_nord, aldi_sued, biomarkt

export REPLICATE_API_TOKEN="${REPLICATE_API_TOKEN:?Set REPLICATE_API_TOKEN in your shell/.env (do not commit tokens)}"

RETAILERS=("aldi_nord" "aldi_sued" "biomarkt")

echo "🖼️  Generiere fehlende Rezept-Bilder..."
echo "============================================================"
echo ""
echo "⚠️  HINWEIS: Dies kann sehr lange dauern!"
echo "   • Rate-Limit: 6 Requests/Minute (kostenlose Accounts)"
echo "   • ca. 10 Sekunden pro Bild"
echo "   • Für 62 fehlende Bilder: ca. 10-15 Minuten"
echo ""
read -p "Fortfahren? (j/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[JjYy]$ ]]; then
    echo "❌ Abgebrochen"
    exit 1
fi

for retailer in "${RETAILERS[@]}"; do
    echo ""
    echo "📦 Verarbeite: $retailer"
    echo "============================================================"
    ./server/tools/run_sdxl.sh "$retailer" 0
done

echo ""
echo "✅ Alle Bilder generiert!"
echo ""
echo "🔄 Kopiere nach assets/..."
python3 tools/copy_recipe_images_to_assets.py

echo ""
echo "✅ FERTIG!"
