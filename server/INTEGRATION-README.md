# Image Proxy & Enrichment Integration

This document describes the image proxy and brand enrichment features integrated into the server.

## Features Implemented

### 1. Brand Enrichment
- Offers are automatically enriched with brand information during refresh
- Brand mapping is configured in `data/brand-map.json`
- Supports per-retailer brand keyword matching
- Non-destructive: preserves existing brand information if present

### 2. Image Proxy & Caching
- All offer images are cached locally during refresh
- Images are served through `/media/*` endpoint
- Stable URLs that don't change even if external sources change
- Automatic caching with file existence check (idempotent)

### 3. ESM-Safe Paths
- All path resolution uses `fileURLToPath` and `dirname` for ESM compatibility
- No reliance on `process.cwd()` which can be unreliable

## File Changes

### Modified Files
- `src/types.ts` - Added `brand?: string` and `gtin?: string` to Offer interface
- `src/enrich.ts` - Fixed ESM-safe paths, implements brand enrichment logic
- `src/route.ts` - Fixed ESM-safe paths, image caching and media serving
- `src/refresh.ts` - Integrated enrichment and caching into refresh pipeline
- `src/index.ts` - Mounted `/media` endpoint
- `src/db.ts` - Ensured media directory exists on initialization

### Renamed Files
- `data/brand_map.json` → `data/brand-map.json` (kebab-case convention)

## Environment Variables

- `PORT` - Server port (default: 3000)
- `DB` - Database type: `sqlite` or `memory` (default: sqlite)
- `ADMIN_SECRET` - Secret for admin endpoints (required)
- `IMAGE_CACHE_DIR` - Custom media directory (default: `server/media`)

## API Endpoints

### Public Endpoints
- `GET /offers?retailer=LIDL&week=2024-W01` - Get offers (with enriched brand, proxied images)
- `GET /media/{hash}.jpg` - Serve cached images

### Admin Endpoints (require x-admin-secret header)
- `POST /admin/refresh-offers` - Refresh offers (runs enrichment + caching)
- `GET /admin/refresh-offers?key={secret}` - Refresh via query param (for Vercel Cron)

## Brand Mapping Configuration

Edit `data/brand-map.json` to add brand mappings:

```json
{
  "LIDL": {
    "Milbona": ["milch", "joghurt", "quark"],
    "Chef Select": ["salat", "fertiggericht"],
    "Sondey": ["keks", "waffel", "keksrolle"]
  },
  "REWE": {
    "Ja!": ["ja!", "budget"],
    "REWE Bio": ["bio", "organic"]
  }
}
```

## Testing

### Quick Test
```bash
# Start server
npm run dev

# Run integration test
./test-integration.sh
```

### Manual Test
```bash
# 1. Health check
curl http://localhost:3000/healthz

# 2. Refresh offers (replace YOUR_SECRET)
curl -X POST http://localhost:3000/admin/refresh-offers \
  -H "x-admin-secret: YOUR_SECRET"

# 3. Get offers
curl "http://localhost:3000/offers?retailer=LIDL"

# 4. Verify brand enrichment
curl "http://localhost:3000/offers?retailer=LIDL" | grep -o '"brand":"[^"]*"'

# 5. Verify image proxy
curl "http://localhost:3000/offers?retailer=LIDL" | grep -o '"/media/[^"]*"'

# 6. Check cached images
ls -lh media/
```

## How It Works

### Refresh Pipeline Flow
1. Fetch offers from retailer sources (`fetchers/*.ts`)
2. Enrich offers with brand information (`enrich.ts`)
3. Cache images and update URLs to `/media/*` (`route.ts`)
4. Save enriched offers to database (`db.ts`)

### Brand Enrichment Logic
- Loads brand mappings from `data/brand-map.json`
- For each offer without a brand:
  - Checks title against keyword lists
  - Assigns first matching brand
  - Preserves original offer if no match

### Image Caching Logic
- Generates stable hash from original URL (base64url)
- Checks if cached file exists
- Downloads image if not cached
- Returns local `/media/{hash}.jpg` URL

## TypeScript Configuration

The project uses:
- `target: ES2022`
- `module: NodeNext`
- `moduleResolution: NodeNext`
- Node.js v20.17.0

All imports use `.js` extension for ESM compatibility.

## Troubleshooting

### Build Fails
```bash
# Clean and rebuild
rm -rf dist
npm run build
```

### Images Not Caching
- Check `IMAGE_CACHE_DIR` environment variable
- Verify `media/` directory permissions
- Check network connectivity for external image URLs

### Brand Not Enriching
- Verify `data/brand-map.json` exists and is valid JSON
- Check retailer name matches exactly (uppercase)
- Add console logs in `enrich.ts` to debug matching

### Media Endpoint Not Working
- Verify `/media` is mounted (check server logs)
- Check `media/` directory exists
- Verify image files have `.jpg` extension

## Future Enhancements

- Add GTIN/EAN enrichment logic
- Support multiple image formats (png, webp)
- Add image optimization/resizing
- Cache invalidation strategy
- Brand confidence scoring
- Fuzzy matching for brand keywords

