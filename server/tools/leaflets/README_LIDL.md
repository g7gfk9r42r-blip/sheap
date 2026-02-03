# Lidl Prospekt Downloader

## Installation

```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
npm install
npx playwright install chromium
```

## Verwendung

### Basis-Befehl
```bash
npm run fetch:lidl
```

### Mit Optionen
```bash
# PDF überschreiben (auch wenn bereits vorhanden)
npm run fetch:lidl -- --force

# Temporäre WebP-Dateien behalten
npm run fetch:lidl -- --keep-images

# Hilfe anzeigen
npm run fetch:lidl -- --help
```

### Mit eigener URL
```bash
LIDL_LEAFLET_URL="https://www.lidl.de/l/prospekte/..." npm run fetch:lidl
```

## Test-Prompts

### 1. Schneller Test (prüft ob Script startet)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
npm run fetch:lidl 2>&1 | head -20
```

### 2. Vollständiger Test (lädt Prospekt)
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
npm run fetch:lidl
```

### 3. Test mit Debug-Output
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
DEBUG=1 npm run fetch:lidl
```

### 4. Test mit WebP-Dateien behalten
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
npm run fetch:lidl -- --keep-images
```

### 5. Prüfe ob PDF existiert
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
ls -lh media/prospekte/lidl/$(date +%Y)/W$(date +%V)/leaflet.pdf 2>/dev/null && echo "✅ PDF gefunden" || echo "❌ PDF nicht gefunden"
```

### 6. Prüfe PDF-Info
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
file media/prospekte/lidl/$(date +%Y)/W$(date +%V)/leaflet.pdf
```

## PDF öffnen

### macOS
```bash
# Aktuelle Woche öffnen
open /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/lidl/$(date +%Y)/W$(date +%V)/leaflet.pdf

# Oder direkt:
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
open media/prospekte/lidl/$(date +%Y)/W$(date +%V)/leaflet.pdf
```

### Mit Finder öffnen
```bash
cd /Users/romw24/dev/AppProjektRoman/roman_app/server
open -R media/prospekte/lidl/$(date +%Y)/W$(date +%V)/leaflet.pdf
```

### Spezifische Woche öffnen
```bash
# Beispiel: Woche 47, 2025
open /Users/romw24/dev/AppProjektRoman/roman_app/server/media/prospekte/lidl/2025/W47/leaflet.pdf
```

## Automatisierung

Das Script wird automatisch von `src/refresh.ts` aufgerufen bei jedem `/admin/refresh-offers` Aufruf.

## Troubleshooting

### "Cannot find package 'playwright'"
```bash
npm install
npx playwright install chromium
```

### "Keine Bilder gefunden"
- Prüfe ob die Lidl-URL noch gültig ist
- Prüfe ob `leaflets.schwarz` erreichbar ist
- Versuche mit `--force` erneut

### PDF ist zu groß
- Das Script verwendet die originalen WebP-Bilder
- Für kleinere PDFs könnte man die Bildqualität reduzieren (nicht implementiert)

