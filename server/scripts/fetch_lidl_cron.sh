#!/bin/bash
#
# Cron-Job Script für wöchentliche Lidl-Offer-Extraktion
# Vereinfachte Version - nutzt direkt den TypeScript-Fetcher
#

# Pfade
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SERVER_DIR" || exit 1

# Lade .env falls vorhanden
[ -f ".env" ] && export $(grep -v '^#' .env | xargs)

# Log-Datei
LOG_DIR="$SERVER_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/lidl_$(date +%Y-%m-%d).log"

# Führe Extraktion aus
{
    echo "=== $(date) ==="
    echo "Starte Lidl-Extraktion..."
    
    # Build
    npm run build || exit 1
    
    # Schritt 1: Extrahiere Offers via Playwright-Script (erstellt JSON)
    if [ -f "tools/leaflets/fetch_lidl_leaflet.mjs" ]; then
        echo "📥 Führe fetch_lidl_leaflet.mjs aus..."
        node tools/leaflets/fetch_lidl_leaflet.mjs --capture-only || exit 1
    fi
    
    # Schritt 2: Importiere Offers in SQLite via TypeScript-Fetcher
    echo "💾 Importiere Offers in SQLite..."
    node test/test_lidl_playwright.mjs || exit 1
    
    echo "✅ Fertig: $(date)"
} >> "$LOG_FILE" 2>&1

