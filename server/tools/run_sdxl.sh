#!/bin/bash
# SDXL Pipeline - Run Script für macOS/Linux
# ===========================================

# Projekt-Root finden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Wechsel ins Projekt-Root
cd "$PROJECT_ROOT"

# Python/Pip Detection (macOS verwendet python3/pip3)
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    echo "❌ Fehler: Python nicht gefunden!"
    echo "   Installiere Python 3.10+ mit: brew install python3"
    exit 1
fi

# Prüfe Python-Version
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
echo "✅ Python gefunden: $PYTHON_CMD ($PYTHON_VERSION)"
echo "✅ Projekt-Root: $PROJECT_ROOT"
echo ""

# Virtual Environment Setup (PEP 668 Compliance)
VENV_DIR="$PROJECT_ROOT/.venv_sdxl"

if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Erstelle Virtual Environment..."
    $PYTHON_CMD -m venv "$VENV_DIR"
    
    if [ $? -ne 0 ]; then
        echo "⚠️  Virtual Environment Erstellung fehlgeschlagen."
        echo "   Versuche ohne Virtual Environment (mit --break-system-packages)..."
        VENV_DIR=""
    else
        echo "✅ Virtual Environment erstellt: $VENV_DIR"
    fi
else
    echo "✅ Virtual Environment gefunden: $VENV_DIR"
fi

# Aktiviere Virtual Environment (falls vorhanden)
if [ -n "$VENV_DIR" ] && [ -d "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
    echo "✅ Virtual Environment aktiviert"
    PYTHON_CMD="python"
    PIP_CMD="pip"
fi

# Parse Arguments
RETAILER="${1:-aldi_nord}"
LIMIT="${2:-}"
FORCE="${3:-}"

# Prüfe ob Dependencies installiert sind
echo "🔍 Prüfe Dependencies..."
if ! $PYTHON_CMD -c "import requests" &> /dev/null 2>&1; then
    echo "⚠️  Dependencies fehlen. Installiere..."
    
    # Installiere nur Requests (Replicate HTTP API, kein Python-Package nötig)
    echo "📦 Installiere Dependencies (Replicate HTTP API)..."
    $PIP_CMD install requests pillow python-dotenv
    
    if [ $? -ne 0 ]; then
        echo "❌ Installation fehlgeschlagen!"
        echo "   Versuche mit --break-system-packages (nicht empfohlen)..."
        $PIP_CMD install --break-system-packages requests pillow python-dotenv
    fi
else
    echo "✅ Dependencies gefunden"
fi

echo ""
echo "🚀 Starte SDXL Pipeline..."
echo "   Retailer: $RETAILER"

# Build Command
CMD_ARGS=("--retailer" "$RETAILER")

if [ -n "$LIMIT" ] && [ "$LIMIT" != "0" ]; then
    echo "   Limit: $LIMIT"
    CMD_ARGS+=("--limit" "$LIMIT")
fi

if [ "$FORCE" = "force" ] || [ "$FORCE" = "--force" ] || [ "$FORCE" = "-f" ]; then
    echo "   ⚠️  Force-Modus: Überschreibe vorhandene Bilder"
    CMD_ARGS+=("--no-skip-existing")
else
    echo "   Skip-Modus: Überspringe vorhandene Bilder (nutze 'force' als 3. Argument zum Überschreiben)"
    CMD_ARGS+=("--skip-existing")
fi

# Führe Pipeline aus
$PYTHON_CMD server/tools/generate_recipe_images_sdxl.py "${CMD_ARGS[@]}"

# Deaktiviere Virtual Environment (falls aktiviert)
if [ -n "$VENV_ACTIVATED" ]; then
    deactivate
fi

