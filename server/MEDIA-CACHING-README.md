# Grocify Backend - Media Caching & Brand Enrichment

## 🎯 Implementierte Features

### ✅ 1. Automatisches Bild-Caching
- **Verzeichnis**: `/server/media/`
- **Funktion**: Bilder werden automatisch aus Angebots-URLs heruntergeladen und lokal gecacht
- **Features**:
  - Sichere Dateinamen basierend auf URL-Hash
  - Automatische Dateierweiterung-Erkennung
  - Timeout-Schutz (10 Sekunden)
  - Größenlimit (max 5MB)
  - Content-Type-Validierung
  - In-Memory-Cache für Performance

### ✅ 2. Media-Endpoint
- **URL**: `/media/*`
- **Features**:
  - Statische Dateiauslieferung mit Caching-Headers
  - ETag-Support für Browser-Caching
  - 24h Cache-Control Header
  - Fallback-Schutz

### ✅ 3. Automatische URL-Umschreibung
- **Integration**: Im Refresh-Flow (`POST /admin/refresh-offers`)
- **Funktion**: Bild-URLs werden automatisch auf `/media/...` umgeschrieben
- **Performance**: Parallele Bild-Caching-Operationen
- **Fehlerbehandlung**: Bei Fehlern bleibt die ursprüngliche URL erhalten

### ✅ 4. Brand-Enrichment-Logik
- **Datei**: `/server/data/brand-map.json`
- **Features**:
  - Automatische Markenerkennung basierend auf Keywords
  - Fallback auf Default-Brand-Map
  - Merge von Custom- und Default-Mappings
  - Admin-Endpoint für Brand-Map-Updates

### ✅ 5. Node 20 + ES Modules
- **Engine**: Node.js >= 20
- **Module-System**: ES Modules (`"type": "module"`)
- **Kompatibilität**: Alle Features nutzen moderne Node.js APIs

## 🚀 Neue Admin-Endpoints

### Brand-Map Management
```bash
POST /admin/brand-map
Headers: x-admin-secret: YOUR_SECRET
Body: {
  "retailer": "REWE",
  "brand": "Milka", 
  "keywords": ["milka", "lila", "schokolade"]
}
```

### Media-Cleanup
```bash
POST /admin/cleanup-media
Headers: x-admin-secret: YOUR_SECRET
Body: {
  "maxAgeMs": 604800000  // Optional: 7 Tage default
}
```

## 📁 Dateistruktur

```
server/
├── src/
│   ├── route.ts          # Media-Caching & Static Serving
│   ├── enrich.ts         # Brand-Enrichment-Logik
│   ├── refresh.ts        # Erweiterter Refresh-Flow
│   └── index.ts         # Admin-Endpoints
├── data/
│   └── brand-map.json   # Brand-Mappings
└── media/               # Gecachte Bilder (auto-erstellt)
```

## 🔧 Konfiguration

### Umgebungsvariablen
```bash
IMAGE_CACHE_DIR=/path/to/media  # Optional: Custom Media-Verzeichnis
ADMIN_SECRET=your_secret        # Für Admin-Endpoints
```

### Brand-Map Format
```json
{
  "RETAILER": {
    "BRAND_NAME": ["keyword1", "keyword2", "keyword3"]
  }
}
```

## 🎯 Verwendung

### 1. Automatisches Caching
Beim Refresh werden alle Bild-URLs automatisch gecacht:
```bash
curl -X POST http://localhost:3000/admin/refresh-offers \
  -H "x-admin-secret: YOUR_SECRET"
```

### 2. Media-Zugriff
Gecachte Bilder sind über den Media-Endpoint verfügbar:
```bash
curl http://localhost:3000/media/abc123def456.jpg
```

### 3. Brand-Enrichment
Offers werden automatisch mit Markeninformationen angereichert:
```bash
curl http://localhost:3000/offers?retailer=REWE
```

## 🛡️ Sicherheit & Performance

- **Timeout-Schutz**: 10s Timeout für Bild-Downloads
- **Größenlimit**: Max 5MB pro Bild
- **Content-Type-Validierung**: Nur echte Bilder werden gecacht
- **User-Agent**: Identifizierbarer Bot-Header
- **Fehlerbehandlung**: Graceful Fallback auf Original-URLs
- **Caching**: Browser-Caching für bessere Performance

## 🔄 Workflow

1. **Refresh-Trigger**: `POST /admin/refresh-offers`
2. **Offer-Fetching**: Daten von Retailer-APIs
3. **Brand-Enrichment**: Automatische Markenerkennung
4. **Image-Caching**: Paralleles Herunterladen und Cachen
5. **URL-Rewriting**: Umwandlung zu `/media/...` URLs
6. **Database-Update**: Speicherung der angereicherten Daten

Das System ist vollständig automatisiert und läuft stabil mit Node 20 und ES Modules! 🎉
