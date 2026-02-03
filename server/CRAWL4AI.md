# Crawl4AI Integration

## Übersicht

Crawl4AI ist ein leistungsstarker, KI-gestützter Web-Scraping-Service, der in diesem Projekt zur Extraktion strukturierter Angebotsdaten von Supermarkt-Websites (z.B. Lidl, REWE, EDEKA) verwendet wird.

**Wichtig:** Crawl4AI läuft als separater, externer Service und wird **nicht** im Vercel-Server ausgeführt. Der Service muss separat (z.B. als Docker-Container auf einem eigenen Server) laufen und über HTTP-REST-API erreichbar sein.

## Installation & Setup

### 1. Crawl4AI Service starten

Crawl4AI muss als separater Service laufen. Beispiel-Docker-Compose:

```yaml
version: '3.8'
services:
  crawl4ai:
    image: unclecode/crawl4ai:latest
    ports:
      - "11235:8000"
    environment:
      - CRAWL4AI_API_KEY=your-secret-token-here
    volumes:
      - crawl4ai-data:/data
volumes:
  crawl4ai-data:
```

Oder direkt mit Docker:

```bash
docker run -d \
  --name crawl4ai \
  -p 11235:8000 \
  -e CRAWL4AI_API_KEY=your-secret-token-here \
  unclecode/crawl4ai:latest
```

### 2. Umgebungsvariablen konfigurieren

Ergänze in `.env` (oder `.env.example`):

```env
# Crawl4AI Konfiguration
CRAWL4AI_BASE_URL=http://localhost:11235
CRAWL4AI_TOKEN=your-secret-token-here
```

**Hinweis:** In Produktion sollte `CRAWL4AI_BASE_URL` auf die URL deines Crawl4AI-Servers zeigen (z.B. `https://crawl4ai.yourdomain.com`).

## Verwendung

### Service Layer

Der Crawl4AI-Client befindet sich in `src/services/crawl4ai.js` (reines ES Module).

- `crawlSinglePage(url, { schema, instruction })` – POST `/crawl`
- `pingCrawl4ai()` – GET `/health`

Beispiel:

```javascript
import { crawlSinglePage } from './services/crawl4ai.js';

const { items } = await crawlSinglePage('https://www.lidl.de/l/prospekte', {
  schema: [{ name: 'title', description: 'Produktname', type: 'string' }],
  instruction: 'Give me a list of offers',
});
```

### Fetcher Integration

Der Lidl-Fetcher (`src/fetchers/lidl.ts`) nutzt Crawl4AI automatisch:

```typescript
import { fetchOffers } from './fetchers/lidl.js';

const offers = await fetchOffers('2025-W48');
```

Falls Crawl4AI nicht erreichbar ist, gibt der Fetcher ein leeres Array zurück (graceful degradation).

## API-Endpunkte

Der Crawl4AI-Client nutzt folgende Endpunkte (konfigurierbar via `CRAWL4AI_BASE_URL`):

- `GET /health` - Health-Check
- `POST /crawl` - Crawl- oder Extraktionsauftrag

### Request-Format (Extract)

```json
{
  "url": "https://example.com",
  "schema": [
    {
      "name": "title",
      "description": "Produktname",
      "type": "string"
    }
  ],
  "instruction": "Extrahiere alle Produkte",
  "options": {
    "maxDepth": 0,
    "maxPages": 1
  }
}
```

### Response-Format

```json
{
  "job_id": "abc123",
  "status": "completed",
  "result": {
    "markdown": "...",
    "html": "...",
    "extracted_data": [
      { "title": "Produkt 1", "price": 1.99 }
    ]
  }
}
```

Bei asynchronen Jobs wird automatisch gepollt, bis der Job fertig ist.

## Konfiguration

Die Crawl4AI-Konfiguration befindet sich in `src/config.ts`:

```typescript
export const CRAWL4AI_BASE_URL = process.env.CRAWL4AI_BASE_URL ?? 'http://localhost:11235';
export const CRAWL4AI_TOKEN = process.env.CRAWL4AI_TOKEN ?? '';
```

## Fehlerbehandlung

- **Service nicht erreichbar:** Fetcher geben leere Arrays zurück, Refresh-Prozess wird nicht unterbrochen
- **Timeout:** Standard-Timeout ist 300 Sekunden (5 Minuten), konfigurierbar pro Request
- **Ungültige Responses:** Werden geloggt und führen zu leeren Ergebnissen

## Rechtliche Hinweise

⚠️ **Wichtig:** Beim Web-Scraping müssen die folgenden Punkte beachtet werden:

1. **robots.txt:** Prüfe die `robots.txt` der Zielwebsite und halte dich an die Regeln
2. **Terms of Service:** Lies die AGB der jeweiligen Website
3. **Rate Limiting:** Respektiere Rate Limits und füge angemessene Delays ein
4. **Personenbezogene Daten:** Verarbeite keine personenbezogenen Daten ohne Einwilligung

Dieses Projekt nutzt Scraping ausschließlich für öffentlich zugängliche Angebotsinformationen und sollte in Übereinstimmung mit den jeweiligen Nutzungsbedingungen verwendet werden.

## Weitere Ressourcen

- [Crawl4AI GitHub](https://github.com/unclecode/crawl4ai)
- [Crawl4AI Dokumentation](https://docs.crawl4ai.com/)

## Troubleshooting

### Crawl4AI Service nicht erreichbar

```bash
# Teste Verbindung
curl http://localhost:11235/health
```

### Debug-Logging aktivieren

Setze `DEBUG=1` in `.env` für detaillierte Logs.

### Timeout-Probleme

Erhöhe den `timeoutMs` Parameter in `crawlSinglePage()` für große Seiten:

```typescript
await crawlSinglePage('https://example.com', {
  schema: [...],
  timeoutMs: 600_000, // 10 Minuten
});
```

