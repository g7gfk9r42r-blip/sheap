# Universal Prospekt Scraper

Ein umfassender Scraper, der alle Prospekt-Dateien in `media/prospekte/` rekursiv verarbeitet und Angebote extrahiert.

## 🎯 Features

- ✅ **Rekursive Ordner-Durchsuchung** - Verarbeitet alle Unterordner automatisch
- ✅ **Multi-Format Support** - PDF, HTML, JSON, TXT
- ✅ **Robuste Fehlerbehandlung** - Einzelne Fehler stoppen nicht die gesamte Verarbeitung
- ✅ **Metadaten-Tracking** - Speichert Informationen über alle verarbeiteten Dateien
- ✅ **Klar gekennzeichnete Ausgabe** - Dateien mit `_processed_` im Namen
- ✅ **Deduplizierung** - Entfernt doppelte Angebote automatisch
- ✅ **Detailliertes Logging** - Zeigt Fortschritt und Ergebnisse

## 📁 Struktur

```
media/prospekte/
├── aldi_nord/
│   └── *.pdf
├── lidl/
│   └── *.pdf
├── edeka/
│   ├── edeka berlin/
│   │   ├── *.pdf
│   │   ├── *.html
│   │   └── *.json
│   └── edeka münchen/
│       └── *.pdf
└── ...
```

## 🚀 Verwendung

### Einmalige Ausführung

```bash
npm run process:all
```

Oder direkt:

```bash
npm run build && node scripts/process_all_prospekte.mjs
```

### Wöchentliche Ausführung (Cron)

Füge folgende Zeile zu deinem Crontab hinzu:

```bash
# Jeden Montag um 6:00 Uhr
0 6 * * 1 cd /path/to/server && npm run process:all >> logs/prospekt_scraper.log 2>&1
```

## 📋 Ausgabe

Für jeden Ordner wird eine JSON-Datei erstellt:

**Dateiname:** `{retailer}_{region}_processed_{weekKey}.json`

**Beispiel:** `edeka_berlin_processed_2025-W48.json`

### Struktur der Ausgabe-Datei

```json
{
  "metadata": {
    "retailer": "EDEKA",
    "region": "Berlin",
    "weekKey": "2025-W48",
    "year": 2025,
    "week": 48,
    "processedAt": "2025-11-25T10:30:00.000Z",
    "source": "prospekt-scraper",
    "version": "1.0.0",
    "totalFilesProcessed": 3,
    "successfulFiles": 3,
    "failedFiles": 0
  },
  "processedFiles": [
    {
      "path": "edeka/edeka berlin/kaufDA - EDEKA - Aktuelle Angebote.pdf",
      "type": "pdf",
      "success": true,
      "offersCount": 150,
      "processedAt": "2025-11-25T10:30:15.000Z"
    }
  ],
  "offers": [
    {
      "name": "Prodomo",
      "price": 6.99,
      "price_old": 10.49,
      "savings": 3.50
    }
  ]
}
```

## 🔧 Unterstützte Formate

### PDF
- Extrahiert Text mit `pdf-parse`
- Erkennt Preise, Produktnamen, Rabatte
- Unterstützt verschiedene Layouts

### HTML
- Verarbeitet vollständig gespeicherte HTML-Dateien (mit Assets)
- Nutzt `cheerio` für Parsing
- Extrahiert Angebote aus KaufDA-Format

### JSON
- Unterstützt verschiedene JSON-Formate:
  - Array von Angeboten
  - Objekt mit `offers` Array
  - Raw-Format mit `raw` Array
- Normalisiert alle Formate zu einheitlichem Format

### TXT
- Zeilenweise Verarbeitung
- Erkennt Preise im Format `X,XX €`
- Extrahiert Produktnamen

## ⚙️ Konfiguration

Der Scraper erkennt automatisch:
- **Retailer** aus Ordnernamen (z.B. `aldi_nord` → `ALDI`)
- **Region** aus Unterordnernamen (z.B. `edeka berlin` → `Berlin`)
- **Dateityp** aus Dateiendung

## 📊 Logging

Der Scraper gibt detaillierte Informationen aus:

```
🚀 Universal Prospekt Scraper

📂 Prospekt-Verzeichnis: /path/to/media/prospekte

🏪 EDEKA
═══════════════════════════════════════════════════════════
📁 edeka berlin
  📄 kaufDA - EDEKA - Aktuelle Angebote.pdf (pdf)
  ✅ 150 Angebote extrahiert, 1/1 Dateien erfolgreich
  📋 Gespeichert: edeka_berlin_processed_2025-W48.json

═══════════════════════════════════════════════════════════
📊 ZUSAMMENFASSUNG
═══════════════════════════════════════════════════════════

📁 Verarbeitete Ordner: 5
📄 Gesamt Dateien: 12
✅ Erfolgreich: 11
❌ Fehlgeschlagen: 1
📦 Gesamt Angebote: 1250
```

## 🛡️ Fehlerbehandlung

- **Einzelne Dateifehler** stoppen nicht die gesamte Verarbeitung
- **Fehlgeschlagene Dateien** werden in Metadaten dokumentiert
- **Detaillierte Fehlermeldungen** für Debugging
- **Fortsetzung nach Fehlern** - verarbeitet weiterhin andere Dateien

## 🔍 Übersprungene Dateien

Folgende Dateien werden automatisch übersprungen:
- Bereits verarbeitete Dateien (`*_processed_*.json`, `*_final_*.json`)
- `_files` Ordner (HTML-Assets)
- `jsondateivoll` Dateien

## 💡 Tipps

1. **Vollständige HTML-Dateien**: Speichere Prospekt-Seiten als "Webseite, vollständig" (mit allen Assets)
2. **PDF bevorzugen**: PDFs liefern meist bessere Ergebnisse
3. **Mehrere Formate**: Wenn ein Format unvollständig ist, hilft ein anderes Format
4. **Wöchentliche Ausführung**: Führe den Scraper jeden Montag aus, nachdem neue Prospekte hochgeladen wurden

## 🐛 Troubleshooting

### Keine Angebote gefunden
- Prüfe, ob die Datei lesbar ist
- Prüfe das Dateiformat (PDF sollte Text enthalten, nicht nur Bilder)
- Prüfe die Logs für Fehlermeldungen

### Fehler beim Parsen
- Prüfe, ob die Datei korrekt formatiert ist
- Prüfe, ob alle Abhängigkeiten installiert sind (`npm install`)
- Prüfe die Logs für detaillierte Fehlermeldungen

### Langsame Verarbeitung
- PDF-Verarbeitung kann bei großen Dateien langsam sein
- HTML-Verarbeitung ist meist schneller
- JSON-Verarbeitung ist am schnellsten

## 📝 Changelog

### Version 1.0.0
- Initiale Version
- Unterstützung für PDF, HTML, JSON, TXT
- Rekursive Ordner-Durchsuchung
- Metadaten-Tracking
- Deduplizierung

