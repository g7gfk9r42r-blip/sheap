#!/bin/sh
# scripts/fetch_edeka_cron.sh
# Cronjob für automatisches Laden von EDEKA-Prospekten als PDF
# POSIX-kompatibel, keine Bash-spezifischen Features

set -e

# Lade .env (POSIX-kompatibel)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

if [ -f .env ]; then
  # POSIX-kompatible .env-Ladung
  export $(grep -v '^#' .env | xargs)
fi

# Erstelle Log-Verzeichnis
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/edeka_$(date +%Y-%m-%d).log"

echo "[$(date +'%Y-%m-%d %H:%M:%S')] Starting EDEKA PDF cron job" >> "$LOG_FILE"

# Build TypeScript
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Building TypeScript..." >> "$LOG_FILE"
npm run build >> "$LOG_FILE" 2>&1 || {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] Build failed!" >> "$LOG_FILE"
  exit 1
}

# Lade alle EDEKA-Prospekte als PDF
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Fetching EDEKA PDFs..." >> "$LOG_FILE"

node dist/fetchers/edeka_pdf_fetcher.js >> "$LOG_FILE" 2>&1 || {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] PDF fetch failed!" >> "$LOG_FILE"
  exit 1
}

echo "[$(date +'%Y-%m-%d %H:%M:%S')] EDEKA PDF cron job completed" >> "$LOG_FILE"

