# Lidl Offer Extraktion – Empfehlung & Anleitung

## 🎯 **Empfohlene Lösung: Playwright-basierte Extraktion**

Die **robusteste und zuverlässigste** Methode für wöchentliche Lidl-Offer-Extraktion ist die **Playwright-basierte Lösung** (`fetch_lidl_leaflet.mjs`).

### ✅ **Warum diese Methode?**

1. **100% zuverlässig**: Nutzt Network-Interception, um API-Responses direkt abzufangen
2. **Vollständig**: Erfasst **jedes einzelne Angebot** aus dem Prospekt
3. **Robust**: Mehrere Fallback-Strategien (API → DOM-Scraping → Validierung)
4. **Wartbar**: Bereits implementiert und getestet
5. **Keine externen Dependencies**: Funktioniert ohne Crawl4AI, OpenAI, etc.

---

## 📋 **Wie es funktioniert**

### **1. Playwright-Script (`fetch_lidl_leaflet.mjs`)**

- Öffnet den Lidl-Viewer im Browser (Playwright)
- **Network-Interception**: Fängt alle JSON-API-Responses ab (inkl. Produktdaten)
- **DOM-Scraping**: Falls API unvollständig, extrahiert direkt aus dem DOM
- **Durchblättern**: Geht durch alle Seiten, um alle API-Calls zu triggern
- Speichert Offers als JSON: `data/lidl/{year}/W{week}/offers.json`

### **2. TypeScript-Fetcher (`fetcher_lidl_playwright.ts`)**

- Liest die generierte JSON-Datei
- Normalisiert Offers zu standardisiertem Format
- Validiert Offers (Titel, Preis, etc.)
- Speichert in SQLite via `adapter.upsertOffers()`

### **3. Automatische Integration**

- Wird automatisch über `refresh.ts` aufgerufen
- Endpoint: `/admin/refresh-offers` (POST)
- Läuft wöchentlich (siehe Cron/CI-CD)

---

## 🚀 **Setup & Verwendung**

### **Voraussetzungen**

```bash
# Installiere Dependencies
cd server
npm install

# Installiere Playwright Browser
npx playwright install chromium
```

### **Manuelle Extraktion**

```bash
# Extrahiere Offers für aktuelle Woche
npm run fetch:lidl

# Oder mit spezifischer URL
LIDL_LEAFLET_URL="https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1" npm run fetch:lidl

# Mehrere Prospekte gleichzeitig (z.B. Weihnachtszeit)
npm run fetch:lidl \
  "https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1" \
  "https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-f231da/view/flyer/page/1"
```

### **Programmatische Nutzung (TypeScript)**

```typescript
import { fetchLidlOffersPlaywright } from './fetchers/fetcher_lidl_playwright.js';

// Extrahiert Offers für aktuelle Woche
const offers = await fetchLidlOffersPlaywright();

// Oder spezifische Woche
const offers = await fetchLidlOffersPlaywright('2025-W48');
```

### **Test-Skript**

```bash
npm run build
npm run test:lidl:playwright
```

### **API-Endpoint (automatisch)**

```bash
# Führt automatisch alle Fetcher aus (inkl. Lidl)
curl -X POST http://localhost:3000/admin/refresh-offers \
  -H "x-admin-secret: dein-secret"
```

---

## 📁 **Datei-Struktur**

```
server/
├── tools/leaflets/
│   └── fetch_lidl_leaflet.mjs      # Playwright-Script (Hauptextraktion)
├── src/fetchers/
│   ├── lidl.ts                     # Haupt-Fetcher (nutzt Playwright)
│   └── fetcher_lidl_playwright.ts  # TypeScript-Integration
├── data/lidl/
│   └── {year}/
│       └── W{week}/
│           ├── offers.json         # Merged Offers (mehrere Prospekte)
│           └── offers_{id}.json    # Einzelne Prospekt-Offers
└── test/
    └── test_lidl_playwright.mjs    # Test-Skript
```

---

## 🔄 **Wöchentliche Automatisierung**

### **Option 1: Cron-Job (Server)**

```bash
# Crontab: Jeden Sonntag um 8:00 Uhr (empfohlen - gibt Fallback-Zeit)
0 8 * * 0 cd /path/to/roman_app/server && ./scripts/fetch_lidl_cron.sh

# Oder mit Refresh-Endpoint:
0 8 * * 0 cd /path/to/roman_app/server && npm run build && curl -X POST http://localhost:3000/admin/refresh-offers -H "x-admin-secret: dein-secret"
```

### **Option 2: CI/CD (GitHub Actions)**

```yaml
name: Weekly Lidl Offers

on:
  schedule:
    - cron: '0 8 * * 0'  # Sonntag, 8:00 UTC (gibt Fallback-Zeit)
  workflow_dispatch:  # Manuell auslösbar

jobs:
  extract:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: cd server && npm install && npm run build
      - run: cd server && npm run fetch:lidl
      - run: cd server && npm run test:lidl:playwright
```

### **Option 3: Docker Container**

```dockerfile
# Dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install && npx playwright install chromium
COPY . .
CMD ["npm", "start"]
```

---

## ⚙️ **Konfiguration**

### **Umgebungsvariablen**

```bash
# .env
LIDL_LEAFLET_URL=https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1
DEBUG=false  # Aktiviert Debug-Logging
```

### **Flags für fetch_lidl_leaflet.mjs**

```bash
--capture-only    # Nur JSON, kein PDF
--force          # Überschreibe existierende Dateien
--keep-images    # Behalte WebP-Bilder
--help           # Hilfe anzeigen
```

---

## 🐛 **Troubleshooting**

### **Problem: Keine Offers gefunden**

1. **Prüfe ob URL erreichbar ist:**
   ```bash
   curl -I "https://www.lidl.de/l/prospekte/latest-leaflet-..."
   ```

2. **Aktiviere Debug-Logging:**
   ```bash
   DEBUG=true npm run fetch:lidl
   ```

3. **Prüfe Raw JSON-Dateien:**
   ```bash
   ls -la server/data/lidl/{year}/W{week}/
   cat server/media/prospekte/lidl/{year}/W{week}/{id}/__raw_json/payload_001.json
   ```

### **Problem: Timeout**

- Erhöhe `timeout` in `fetch_lidl_leaflet.mjs` (Standard: 90s)
- Prüfe Netzwerkverbindung
- Prüfe ob Lidl-Site blockiert (VPN/Firewall)

### **Problem: Zu wenige Offers**

- Script geht durch alle Seiten (bis zu 35)
- Erfasst API-Responses und DOM-Daten
- Prüfe ob mehrere Prospekte vorhanden (z.B. Weihnachtszeit)
- Nutze `--force` um erneut zu extrahieren

---

## 📊 **Ergebnis-Format**

### **JSON-Datei (`offers.json`)**

```json
{
  "weekKey": "2025-W48",
  "year": 2025,
  "week": 48,
  "totalOffers": 156,
  "offers": [
    {
      "id": "product_12345",
      "title": "Milbona Mini Mozzarella XXL",
      "price": 1.29,
      "originalPrice": null,
      "priceText": "2 x 300 g",
      "unit": "Stück",
      "brand": "Milbona",
      "imageUrl": "https://...",
      "validFrom": "2025-11-24T00:00:00Z",
      "validTo": "2025-11-29T23:59:59Z",
      "page": 3,
      "retailer": "LIDL"
    }
  ]
}
```

### **SQLite (via `adapter.upsertOffers()`)**

- Normalisiertes `Offer`-Format
- Automatische Deduplizierung
- Indizierung für schnelle Abfragen

---

## ✅ **Zusammenfassung**

**Empfohlene Methode**: `fetch_lidl_leaflet.mjs` + `fetcher_lidl_playwright.ts`

**Vorteile**:
- ✅ 100% zuverlässig (Network-Interception)
- ✅ Erfasst jedes einzelne Angebot
- ✅ Mehrere Fallback-Strategien
- ✅ Bereits implementiert & getestet
- ✅ Keine externen Dependencies

**Nächste Schritte**:
1. `npm run test:lidl:playwright` ausführen
2. Wöchentliche Automatisierung einrichten (Cron/CI-CD)
3. Monitoring: Prüfe ob Offers korrekt gespeichert werden

---

## 📝 **Changelog**

- **2025-01-XX**: Playwright-basierte Lösung als Standard empfohlen
- **2025-01-XX**: Integration in TypeScript-Fetcher
- **2025-01-XX**: Wöchentliche Automatisierung hinzugefügt

