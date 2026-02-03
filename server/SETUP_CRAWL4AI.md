# Crawl4AI Setup - Schritt für Schritt

## 🚀 Schnellstart (Empfohlen: Docker)

### Option 1: Docker (am einfachsten)

```bash
# 1. Starte Crawl4AI als Docker-Container
docker run -d \
  --name crawl4ai \
  -p 11235:8000 \
  -e CRAWL4AI_API_KEY=my-secret-token-123 \
  --restart unless-stopped \
  unclecode/crawl4ai:latest

# 2. Prüfe ob der Service läuft
curl http://localhost:11235/health

# 3. Füge Umgebungsvariablen in .env hinzu
echo "CRAWL4AI_BASE_URL=http://localhost:11235" >> .env
echo "CRAWL4AI_TOKEN=my-secret-token-123" >> .env
```

### Option 2: Docker Compose (für Entwicklung)

Erstelle `docker-compose.yml` im `server/` Verzeichnis:

```yaml
version: '3.8'
services:
  crawl4ai:
    image: unclecode/crawl4ai:latest
    container_name: crawl4ai
    ports:
      - "11235:8000"
    environment:
      - CRAWL4AI_API_KEY=my-secret-token-123
    restart: unless-stopped
    volumes:
      - crawl4ai-data:/data

volumes:
  crawl4ai-data:
```

Dann starten:

```bash
docker-compose up -d
```

## ⚙️ Konfiguration

### .env Datei erstellen/anpassen

Im `server/` Verzeichnis:

```bash
# Erstelle .env falls nicht vorhanden
touch .env
```

Füge folgende Zeilen hinzu:

```env
# Crawl4AI Konfiguration
CRAWL4AI_BASE_URL=http://localhost:11235
CRAWL4AI_TOKEN=my-secret-token-123
```

**Wichtig:** Verwende den gleichen Token wie beim Starten von Crawl4AI!

## ✅ Testen

### 1. Health-Check

```bash
curl http://localhost:11235/health
```

Sollte `{"status":"ok"}` oder ähnliches zurückgeben.

### 2. Test mit Node.js Script

`test_crawl4ai.mjs` ist bereits im Repo vorhanden und ruft:

- `/health` zum Ping
- `/crawl` auf `https://www.lidl.de/l/prospekte`

```bash
node test_crawl4ai.mjs
```

Die Ausgabe zeigt die ersten extrahierten Items als JSON.

### 3. Test mit Lidl-Fetcher

```bash
npm run dev
```

In einem anderen Terminal:

```bash
curl -X POST http://localhost:3000/admin/refresh-offers \
  -H "x-admin-secret: your-admin-secret" \
  -H "Content-Type: application/json"
```

## 🔧 Troubleshooting

### Problem: Docker Container startet nicht

```bash
# Logs anschauen
docker logs crawl4ai

# Container neu starten
docker restart crawl4ai
```

### Problem: Port 11235 bereits belegt

```bash
# Prüfe was auf Port 11235 läuft
lsof -i :11235  # macOS/Linux
netstat -ano | findstr :11235  # Windows

# Nutze anderen Port (z.B. 11236)
docker run -d --name crawl4ai -p 11236:8000 ...
# Dann in .env: CRAWL4AI_BASE_URL=http://localhost:11236
```

### Problem: "Connection refused"

1. Prüfe ob Crawl4AI läuft: `curl http://localhost:11235/health`
2. Prüfe Firewall-Einstellungen
3. Bei Docker: Prüfe ob Port korrekt gemappt ist: `docker ps`

### Problem: "Unauthorized" oder 401 Fehler

- Stelle sicher, dass `CRAWL4AI_TOKEN` in `.env` mit dem beim Start verwendeten Token übereinstimmt

## 📚 Weitere Infos

- [Crawl4AI GitHub](https://github.com/unclecode/crawl4ai)
- [Crawl4AI Dokumentation](https://docs.crawl4ai.com/)
- Siehe auch: `CRAWL4AI.md` für API-Details

