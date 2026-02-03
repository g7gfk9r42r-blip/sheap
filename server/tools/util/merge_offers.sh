#!/usr/bin/env bash
set -euo pipefail
YEAR="${1:-2025}"
WEEK="${2:-W44}"

outDir="assets/offers/${YEAR}/${WEEK}"
mkdir -p "$outDir"

# Alle Einzelmarkt-Dateien (z. B. rewe.json, aldi_*.json, ...) mergen
if compgen -G "${outDir}/*.json" > /dev/null; then
  jq -s 'reduce .[] as $x ({"week":"'"${YEAR}-${WEEK}"'","markets":[]}; .markets += [$x])' \
    "${outDir}"/*.json \
    > "${outDir}/offers_merged.json"
  echo "✅ Merged: ${outDir}/offers_merged.json"
else
  echo "⚠️  Keine Markt-JSONs in ${outDir} gefunden."
fi

