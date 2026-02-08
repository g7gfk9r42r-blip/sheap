#!/bin/bash
# weekly_deploy.sh - Einfaches Deployment der wöchentlichen Rezepte
# 
# Usage:
#   chmod +x weekly_deploy.sh
#   export OPENAI_API_KEY="sk-..."
#   export REPLICATE_API_TOKEN="..."
#   ./weekly_deploy.sh
#
# Was das Script macht:
# 1. Generiert neue Rezepte + Bilder mit Python
# 2. Kopiert sie in server/media/ (--publish-server)
# 3. Committed zu Git
# 4. Pusht zum Remote
#

set -e  # Exit on error

PROJECT_DIR="/Users/romw24/dev/AppProjektRoman/roman_app"
cd "$PROJECT_DIR"

echo "📅 Wöchentliche Rezept-Generierung & Deployment"
echo "=================================================="

# Aktuelle Woche
WEEK_KEY=$(python3 -c "from datetime import datetime; import sys; print(datetime.now().strftime('%Y-W%V'))")
echo "📍 Woche: $WEEK_KEY"

# 1. Überprüfe Environment
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEY nicht gesetzt!"
    exit 1
fi

if [ -z "$REPLICATE_API_TOKEN" ]; then
    echo "❌ REPLICATE_API_TOKEN nicht gesetzt!"
    exit 1
fi

echo "✅ Environment-Variablen gesetzt"

# 2. Generiere Rezepte + Bilder
echo ""
echo "🚀 Starten: weekly_pro.py..."
python3 tools/weekly_pro.py \
    --image-backend replicate \
    --strict \
    --publish-server \
    --week "$WEEK_KEY" \
    --valid-from "$(python3 -c "from datetime import datetime, timedelta; d = datetime.now(); week_start = d - timedelta(days=d.weekday()); print(week_start.strftime('%Y-%m-%d'))")"

if [ $? -ne 0 ]; then
    echo "❌ weekly_pro.py fehlgeschlagen!"
    exit 1
fi

echo "✅ Rezepte + Bilder generiert"

# 3. Überprüfe ob server/media aktualisiert wurde
if [ ! -d "server/media/prospekte" ]; then
    echo "⚠️  Warnung: server/media/prospekte nicht gefunden!"
    exit 1
fi

echo "✅ server/media/ aktualisiert"

# 4. Git commit + push
echo ""
echo "📤 Uploading zu Git..."

git add server/media/
git add build_logs/  # Optional: Build-Report mitgitenn

COMMIT_MSG="Weekly recipes update: $WEEK_KEY"
git commit -m "$COMMIT_MSG" || echo "⚠️  Nichts zu committen (keine Änderungen)"

git push origin main || git push origin master

echo ""
echo "✅ Erfolgreich deployed!"
echo ""
echo "📋 Nächste Schritte (optional):"
echo "   1. Deploy server/media/ auf deinen Server:"
echo "      rsync -av server/media/ user@server:/var/www/html/"
echo "   2. Vercelā geht automatisch via Git-Push"
echo ""
echo "🎉 Nutzer bekommen neue Rezepte beim nächsten App-Start (Montag)"
