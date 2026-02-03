#!/bin/bash
# Einfaches Script zum Verarbeiten aller Prospekt-Ordner

cd "$(dirname "$0")/.."

# Verwende venv falls vorhanden
if [ -d "crawl4ai_env" ]; then
    crawl4ai_env/bin/python scripts/process_all_prospekte.py "$@"
else
    python3 scripts/process_all_prospekte.py "$@"
fi

