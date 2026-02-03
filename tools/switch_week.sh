#!/bin/bash
# Weekly Switch Script
# Wechselt zu einer neuen Week-Quelle und baut Assets neu

set -e  # Exit on error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Weekly Switch${NC}"
echo "=========================================="

# Parse Arguments
WEEK_KEY=""
if [ $# -ge 1 ]; then
    WEEK_KEY="$1"
    echo -e "${YELLOW}Week-Key: $WEEK_KEY${NC}"
fi

# Wenn Week-Key angegeben: Prüfe ob weekly/<weekKey>/ existiert
if [ -n "$WEEK_KEY" ]; then
    WEEK_SOURCE_DIR="weekly/$WEEK_KEY"
    
    if [ ! -d "$WEEK_SOURCE_DIR" ]; then
        echo -e "${RED}❌ Week-Quelle nicht gefunden: $WEEK_SOURCE_DIR${NC}"
        echo -e "${RED}   Erwartet: weekly/$WEEK_KEY/recipes_*.json${NC}"
        exit 2
    fi
    
    # Prüfe ob recipes_*.json Dateien vorhanden sind
    recipe_count=$(find "$WEEK_SOURCE_DIR" -name "recipes_*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$recipe_count" -eq 0 ]; then
        echo -e "${RED}❌ Keine recipes_*.json Dateien in $WEEK_SOURCE_DIR${NC}"
        exit 2
    fi
    
    echo -e "${GREEN}📋 Kopiere Rezept-JSONs aus $WEEK_SOURCE_DIR...${NC}"
    
    # Erstelle assets/recipes/ falls nicht vorhanden
    mkdir -p assets/recipes
    
    # Kopiere alle recipes_*.json Dateien
    copied=0
    for json_file in "$WEEK_SOURCE_DIR"/recipes_*.json; do
        if [ -f "$json_file" ]; then
            filename=$(basename "$json_file")
            target="assets/recipes/$filename"
            cp "$json_file" "$target"
            echo -e "  ✅ $filename"
            ((copied++))
        fi
    done
    
    if [ $copied -eq 0 ]; then
        echo -e "${RED}❌ Keine recipes_*.json Dateien gefunden in $WEEK_SOURCE_DIR${NC}"
        exit 2
    else
        echo -e "${GREEN}✅ $copied Dateien kopiert${NC}"
    fi
fi

# Validiere Rezepte
echo ""
echo -e "${GREEN}🔍 Validiere Rezepte...${NC}"
python3 tools/validate_recipes.py --strict-count

# Prüfe Exit-Code
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Validierung fehlgeschlagen!${NC}"
    exit 1
fi

# Baue Assets
echo ""
echo -e "${GREEN}🔨 Baue Offline-Assets...${NC}"
python3 tools/build_offline_assets.py --fill-missing-with-placeholder --only-allowed-markets

# Prüfe Exit-Code
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Build fehlgeschlagen!${NC}"
    exit 1
fi

# Parse Build-Output für Tabelle
echo ""
echo -e "${GREEN}📊 Zusammenfassung:${NC}"
echo ""
printf "%-20s %-15s %-20s\n" "Market" "Recipes" "Missing Images"
echo "------------------------------------------------------------"

# Extrahiere Statistiken aus build_offline_assets.py Output
python3 << 'PYEOF'
import json
from pathlib import Path

index_file = Path("assets/index/asset_index.json")
if index_file.exists():
    with open(index_file, 'r', encoding='utf-8') as f:
        index = json.load(f)
    
    for market in sorted(index['recipes'].keys()):
        recipe_data = index['recipes'][market]
        recipes_count = recipe_data['count']
        recipe_ids = set(recipe_data['recipe_ids'])
        image_ids = set(index['recipe_images'].get(market, []))
        missing_count = len(recipe_ids - image_ids)
        
        print(f"{market:20} {recipes_count:15} {missing_count:20}")
PYEOF

echo ""
echo -e "${GREEN}✅ Weekly Switch abgeschlossen!${NC}"
echo ""
echo -e "${YELLOW}📋 Nächste Schritte:${NC}"
echo "   1. flutter pub get"
echo "   2. flutter clean (optional, falls Assets nicht geladen werden)"
echo "   3. App neu starten"
