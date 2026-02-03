#!/bin/bash
#
# Wöchentlicher Lidl-Offer-Extraktor
# Läuft jeden Montag und extrahiert alle Lidl-Angebote für die aktuelle Woche
#

set -e  # Exit bei Fehler

# Pfade
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$SERVER_DIR/logs"

# Erstelle Log-Verzeichnis falls nicht vorhanden
mkdir -p "$LOG_DIR"

# Log-Datei mit Datum
LOG_FILE="$LOG_DIR/lidl_extraction_$(date +%Y-%m-%d_%H-%M-%S).log"

# Funktion für Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "==============================================="
log "🚀 Starte wöchentliche Lidl-Offer-Extraktion"
log "==============================================="

# Wechsle ins Server-Verzeichnis
cd "$SERVER_DIR" || {
    log "❌ Fehler: Kann nicht ins Server-Verzeichnis wechseln: $SERVER_DIR"
    exit 1
}

# Lade .env Datei falls vorhanden
if [ -f ".env" ]; then
    log "📋 Lade Umgebungsvariablen aus .env"
    set -a
    source .env
    set +a
fi

# Prüfe ob Node.js verfügbar ist
if ! command -v node &> /dev/null; then
    log "❌ Fehler: Node.js nicht gefunden. Bitte installieren."
    exit 1
fi

# Prüfe ob npm verfügbar ist
if ! command -v npm &> /dev/null; then
    log "❌ Fehler: npm nicht gefunden. Bitte installieren."
    exit 1
fi

# Schritt 1: TypeScript bauen
log "📦 Baue TypeScript-Projekt..."
if npm run build >> "$LOG_FILE" 2>&1; then
    log "✅ Build erfolgreich"
else
    log "❌ Build fehlgeschlagen. Siehe Log: $LOG_FILE"
    exit 1
fi

# Schritt 2: Prüfe ob Playwright Browser installiert ist
log "🔍 Prüfe Playwright Browser..."
if [ ! -d "$HOME/.cache/ms-playwright" ] && ! command -v playwright &> /dev/null; then
    log "⚠️  Playwright Browser nicht gefunden. Installiere..."
    npx playwright install chromium >> "$LOG_FILE" 2>&1 || {
        log "❌ Playwright-Installation fehlgeschlagen"
        exit 1
    }
    log "✅ Playwright Browser installiert"
fi

# Schritt 3: Starte Offer-Extraktion via Playwright-Script
log "🎯 Starte Offer-Extraktion..."

# Option 1: Direkter Playwright-Script-Aufruf (schneller, erstellt JSON)
if [ -f "tools/leaflets/fetch_lidl_leaflet.mjs" ]; then
    log "📥 Führe fetch_lidl_leaflet.mjs aus..."
    if node tools/leaflets/fetch_lidl_leaflet.mjs --capture-only >> "$LOG_FILE" 2>&1; then
        log "✅ Offer-Extraktion erfolgreich"
    else
        log "❌ Offer-Extraktion fehlgeschlagen. Siehe Log: $LOG_FILE"
        exit 1
    fi
fi

# Schritt 4: Importiere Offers in SQLite via TypeScript-Fetcher
log "💾 Importiere Offers in SQLite..."
if node dist/fetchers/fetcher_lidl_playwright.js >> "$LOG_FILE" 2>&1; then
    log "✅ SQLite-Import erfolgreich"
else
    log "⚠️  SQLite-Import fehlgeschlagen (möglicherweise keine neuen Offers)"
fi

# Schritt 5: Optional - Rufe Refresh-Endpoint auf (falls Server läuft)
if [ -n "$ADMIN_SECRET" ] && [ -n "$API_BASE_URL" ]; then
    log "🔄 Rufe Refresh-Endpoint auf..."
    if curl -s -X POST "$API_BASE_URL/admin/refresh-offers" \
        -H "x-admin-secret: $ADMIN_SECRET" >> "$LOG_FILE" 2>&1; then
        log "✅ Refresh-Endpoint erfolgreich aufgerufen"
    else
        log "⚠️  Refresh-Endpoint nicht erreichbar (Server läuft möglicherweise nicht)"
    fi
fi

# Zusammenfassung
log "==============================================="
log "✅ Wöchentliche Extraktion abgeschlossen"
log "==============================================="
log "📄 Log-Datei: $LOG_FILE"
log "📁 Offers: data/lidl/{year}/W{week}/offers.json"
log "💾 SQLite: data/app.db"
log ""

# Optional: Sende E-Mail-Benachrichtigung bei Fehlern
if [ -n "$ALERT_EMAIL" ] && [ $? -ne 0 ]; then
    log "📧 Sende Fehler-Benachrichtigung an $ALERT_EMAIL"
    echo "Lidl-Extraktion fehlgeschlagen. Siehe Log: $LOG_FILE" | \
        mail -s "Lidl-Extraktion Fehler" "$ALERT_EMAIL" || true
fi

exit 0

