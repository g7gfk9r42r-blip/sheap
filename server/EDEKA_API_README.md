# EDEKA Official API Integration

Vollständige Integration der offiziellen EDEKA-API für echte Marktdaten.

## 📁 Neue Dateien

### Backend (Node.js/TypeScript)

1. **`src/services/edeka_api.ts`**
   - `fetchMarketsByPLZ(plz: string)` - Sucht Märkte nach PLZ
   - `fetchMarketDetails(marketId: string)` - Lädt Markt-Details
   - `fetchMarketOffers(marketId: string)` - Lädt Angebote für einen Markt
   - Automatische Retry-Logik mit Exponential Backoff
   - Timeout-Handling (30s)

2. **`src/utils/date_week.ts`**
   - `getCurrentYearWeek()` - Berechnet ISO-Kalenderwoche

3. **`src/db/offer_normalizer_edeka.ts`**
   - `normalizeEdekaOffer()` - Konvertiert EDEKA-API-Offers in internes Format

4. **`src/db/markets.ts`**
   - `saveMarket()` - Speichert Markt in SQLite
   - `getAllMarkets()` - Lädt alle gespeicherten Märkte
   - `getMarket()` - Lädt einen spezifischen Markt
   - `deleteMarket()` - Löscht einen Markt

5. **`src/fetchers/fetch_edeka_offers.ts`**
   - `fetchEdekaOffersForMarket(marketId: string)` - Haupt-Fetcher für API-Angebote
   - Speichert JSON unter `data/edeka/{year}/W{week}/{marketId}_offers.json`
   - Upsert in SQLite

6. **`scripts/fetch_edeka_cron.sh`**
   - Cronjob-Script für automatisches Laden
   - Lädt Angebote für alle gespeicherten Märkte
   - Loggt nach `logs/edeka_YYYY-MM-DD.log`

### Frontend (Flutter)

7. **`lib/features/market_selection/edeka_market_select_screen.dart`**
   - PLZ-Eingabe
   - Markt-Suche über API
   - Markt-Auswahl und Speicherung
   - Navigation zurück zum Hauptbildschirm

## 🔧 Geänderte Dateien

1. **`src/index.ts`**
   - Neue Endpoints:
     - `GET /edeka/markets?plz=xxxxx` - Suche Märkte
     - `POST /edeka/markets` - Speichere Markt
     - `GET /edeka/markets/saved` - Lade gespeicherte Märkte
     - `GET /edeka/markets/:marketId/offers` - Lade Angebote für Markt

2. **`src/refresh.ts`**
   - Erweitert um EDEKA-API-Integration
   - Lädt Angebote für alle gespeicherten Märkte
   - Fallback auf Scraping, falls keine Märkte gespeichert

## 🚀 Verwendung

### 1. Markt suchen und speichern (Flutter)

```dart
// Navigiere zum EDEKA-Markt-Auswahl-Screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const EdekaMarketSelectScreen(),
  ),
);
```

### 2. Angebote manuell laden (Backend)

```bash
# Testen
npm run build
node dist/fetchers/fetch_edeka_offers.js <marketId>

# Oder über API
curl "http://localhost:3000/edeka/markets/MARKET_ID/offers"
```

### 3. Cronjob einrichten

```bash
# Crontab bearbeiten
crontab -e

# Füge hinzu (jeden Montag um 6:00 Uhr):
0 6 * * 1 cd /path/to/project/server && ./scripts/fetch_edeka_cron.sh
```

### 4. API-Endpoints testen

```bash
# Märkte suchen
curl "http://localhost:3000/edeka/markets?plz=80331"

# Markt speichern
curl -X POST "http://localhost:3000/edeka/markets" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "market-123",
    "name": "EDEKA München",
    "address": {"street": "Hauptstraße 1", "zipCode": "80331", "city": "München"},
    "coordinates": {"latitude": 48.1351, "longitude": 11.5820}
  }'

# Gespeicherte Märkte laden
curl "http://localhost:3000/edeka/markets/saved"

# Angebote für Markt laden
curl "http://localhost:3000/edeka/markets/MARKET_ID/offers"
```

## 📦 Neue npm Packages

**Keine neuen Packages erforderlich!**

Alle benötigten Packages sind bereits vorhanden:
- `better-sqlite3` - für Market-DB
- `fs-extra` - für Datei-Operationen
- `express` - für API-Endpoints

## 🔍 Datenstruktur

### EDEKA Market (API)
```typescript
{
  id: string;
  name: string;
  address?: { street?: string; zipCode?: string; city?: string };
  coordinates?: { latitude: number; longitude: number };
  distance?: number;
}
```

### EDEKA Offer (API)
```typescript
{
  id: string;
  title: string;
  price: number;
  originalPrice?: number;
  discountPercent?: number;
  unit?: string;
  validFrom: string; // ISO date
  validTo: string; // ISO date
  imageUrl?: string;
  category?: string;
  brand?: string;
}
```

### Gespeicherter Markt (DB)
```typescript
{
  id: string;
  marketType: 'EDEKA';
  name: string;
  address?: string;
  zipCode?: string;
  city?: string;
  latitude?: number;
  longitude?: number;
  createdAt: string;
  updatedAt: string;
}
```

## ⚠️ Wichtige Hinweise

1. **API-Endpunkte**: Die tatsächlichen EDEKA-API-Endpunkte müssen möglicherweise angepasst werden, falls die URLs anders sind.

2. **Error Handling**: Alle API-Calls haben automatische Retry-Logik (3 Versuche mit Exponential Backoff).

3. **Timeout**: Standard-Timeout ist 30 Sekunden pro Request.

4. **Fallback**: Falls keine Märkte gespeichert sind, nutzt `refresh.ts` den normalen Scraping-Fetcher.

5. **Datenbank**: Märkte werden in SQLite-Tabelle `markets` gespeichert.

## 🧪 Testing

```bash
# 1. Build
npm run build

# 2. Test Market-Suche
curl "http://localhost:3000/edeka/markets?plz=80331"

# 3. Test Markt speichern
curl -X POST "http://localhost:3000/edeka/markets" \
  -H "Content-Type: application/json" \
  -d '{"id":"test-123","name":"Test Markt"}'

# 4. Test Angebote laden
curl "http://localhost:3000/edeka/markets/test-123/offers"
```

## 📝 Nächste Schritte

1. **API-Endpunkte verifizieren**: Teste die tatsächlichen EDEKA-API-URLs
2. **Flutter-Integration**: Füge Navigation zum EDEKA-Markt-Screen hinzu
3. **Cronjob aktivieren**: Richte den Cronjob für automatisches Laden ein
4. **Error-Monitoring**: Überwache Logs für API-Fehler

