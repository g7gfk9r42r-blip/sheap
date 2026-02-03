import 'dotenv/config';
import express, { Request, Response } from 'express';
import cors from 'cors';
import morgan from 'morgan';
import { promises as fs } from 'node:fs';
import { join } from 'node:path';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { refreshAll } from './refresh.js';
import { getISOWeek } from './iso_week.js';
import { adapter, initializeDatabase } from './db.js';
import { Recipe, Retailer } from './types.js';
import { generateRecipes } from './ai/openai.js';
import { mountMedia, ensureMediaDir, MEDIA_DIR } from './route.js';
import { updateBrandMap } from './enrich.js';
import { fetchMarketsByPLZ } from './services/edeka_api.js';
import { saveMarket, getAllMarkets, getMarket, deleteMarket } from './db/markets.js';
import { fetchEdekaOffersForMarket } from './fetchers/fetch_edeka_offers.js';

const ADMIN_SECRET = process.env.ADMIN_SECRET || '';
const app = express();
const execFileAsync = promisify(execFile);

// -----------------------------------------------------------------------------
// CORS (production-ready)
// -----------------------------------------------------------------------------
// - For mobile apps, CORS is irrelevant (not enforced).
// - For Flutter Web, allow your hosted web origin(s).
// Configure:
//   CORS_ORIGINS="https://your-site.com,https://staging.your-site.com"
//   CORS_ORIGINS="*"  (dev only)
function parseCorsOrigins(): string[] | '*' {
  const raw = (process.env.CORS_ORIGINS || '').trim();
  if (!raw) return [];
  if (raw === '*') return '*';
  return raw
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

const corsOrigins = parseCorsOrigins();
const corsOptions: cors.CorsOptions = {
  origin: (origin, cb) => {
    if (!origin) return cb(null, true); // same-origin / non-browser clients
    // Always allow localhost in dev
    if (/^http:\/\/(localhost|127\.0\.0\.1|0\.0\.0\.0)(:\d+)?$/i.test(origin)) {
      return cb(null, true);
    }
    if (corsOrigins === '*') return cb(null, true);
    if (Array.isArray(corsOrigins) && corsOrigins.length > 0) {
      return cb(null, corsOrigins.includes(origin));
    }
    // Default: deny unknown origins (safer for prod)
    return cb(null, false);
  },
  methods: ['GET', 'POST', 'PUT', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-secret'],
  credentials: false,
  maxAge: 86400,
};
app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

app.use(express.json({ limit: '2mb' }));

// Logging: keep it useful, avoid spam from media 200s.
app.use(
  morgan('tiny', {
    skip: (req, res) =>
      req.path === '/health' ||
      req.path === '/healthz' ||
      (req.path.startsWith('/media/') && res.statusCode < 400),
  }),
);

// Mount media proxy endpoint
mountMedia(app);

// -----------------------------------------------------------------------------
// Meta endpoint for weekly sync (helps apps detect new week/media without guessing)
// -----------------------------------------------------------------------------
async function computeMediaMeta(): Promise<{
  ok: true;
  week_key: string;
  updated_at: string;
  markets: string[];
}> {
  const prospekteDir = join(MEDIA_DIR, 'prospekte');
  let markets: string[] = [];
  let updatedAtMs = 0;
  let weekKey = getISOWeek();

  try {
    const entries = await fs.readdir(prospekteDir, { withFileTypes: true });
    markets = entries.filter((e) => e.isDirectory()).map((e) => e.name).sort();

    // Find candidate recipe json files and compute a max mtime across them.
    const candidates: string[] = [];
    for (const m of markets) {
      const p = join(prospekteDir, m, `${m}_recipes.json`);
      candidates.push(p);
    }

    for (const p of candidates) {
      try {
        const st = await fs.stat(p);
        updatedAtMs = Math.max(updatedAtMs, st.mtimeMs);
      } catch (_) {
        // ignore missing markets
      }
    }

    // Try to extract week_key from the first available market file (cheap parse).
    for (const p of candidates) {
      try {
        const raw = await fs.readFile(p, 'utf-8');
        const json = JSON.parse(raw);
        // Accept either:
        //  - List<recipe>
        //  - { recipes: List<recipe>, week_key/weekKey }
        let maybe: any = null;
        if (Array.isArray(json) && json.length > 0) {
          maybe = json[0];
        } else if (json && typeof json === 'object') {
          if (typeof json.week_key === 'string') weekKey = json.week_key;
          if (typeof json.weekKey === 'string') weekKey = json.weekKey;
          if (Array.isArray(json.recipes) && json.recipes.length > 0) maybe = json.recipes[0];
        }
        if (maybe && typeof maybe === 'object') {
          const wk = (maybe.week_key || maybe.weekKey || '').toString().trim();
          if (wk) weekKey = wk;
        }
        break;
      } catch (_) {
        // ignore parse errors
      }
    }
  } catch (_) {
    // ignore
  }

  return {
    ok: true,
    week_key: weekKey,
    updated_at: new Date(updatedAtMs > 0 ? updatedAtMs : Date.now()).toISOString(),
    markets,
  };
}

app.get('/meta', async (_req: Request, res: Response) => {
  res.setHeader('Cache-Control', 'no-cache');
  const meta = await computeMediaMeta();
  res.json(meta);
});
// Convenience alias under /media (so the client can fetch from the same origin/path family)
app.get('/media/meta.json', async (_req: Request, res: Response) => {
  res.setHeader('Cache-Control', 'no-cache');
  const meta = await computeMediaMeta();
  res.json(meta);
});

// Healthcheck (Render + general)
app.get('/health', (_req: Request, res: Response) =>
  res.status(200).json({
    ok: true,
    service: 'roman_app-server',
    uptime_s: Math.round(process.uptime()),
    mediaDir: MEDIA_DIR,
    time: new Date().toISOString(),
  }),
);
// Backwards-compatible
app.get('/healthz', (_req: Request, res: Response) => res.redirect(307, '/health'));

// -----------------------------------------------------------------------------
// Admin: Upload weekly generated media (no SSH needed)
// -----------------------------------------------------------------------------
// Upload a tar.gz that contains:
//   prospekte/<market>/<market>_recipes.json
//   recipe_images/<market>/R###.png
//
// Example:
//   tar -czf media_bundle.tar.gz -C roman_app/server/media prospekte recipe_images
//   curl -X POST "$BASE/admin/upload-media-tar" \
//     -H "x-admin-secret: $ADMIN_SECRET" \
//     -H "Content-Type: application/gzip" \
//     --data-binary @media_bundle.tar.gz
//
// The server extracts into MEDIA_DIR.
app.post(
  '/admin/upload-media-tar',
  express.raw({ type: ['application/gzip', 'application/x-gzip', 'application/octet-stream'], limit: '800mb' }),
  async (req: Request, res: Response) => {
    const header = (req.headers['x-admin-secret'] as string) || '';
    if (!ADMIN_SECRET || header !== ADMIN_SECRET) {
      return res.status(401).json({ error: 'unauthorized' });
    }
    if (!req.body || !(req.body instanceof Buffer) || req.body.length === 0) {
      return res.status(400).json({ error: 'missing_body' });
    }

    await ensureMediaDir();
    const tmpPath = join(process.cwd(), 'tmp_upload_media.tar.gz');
    try {
      await fs.writeFile(tmpPath, req.body);
      // Extract into MEDIA_DIR (expects prospekte/ + recipe_images/ at archive root)
      await execFileAsync('tar', ['-xzf', tmpPath, '-C', MEDIA_DIR]);
      return res.json({ ok: true });
    } catch (e: any) {
      console.error('[admin] upload-media-tar failed:', e);
      return res.status(500).json({ error: 'upload_failed', message: String(e?.message ?? e) });
    } finally {
      try {
        await fs.unlink(tmpPath);
      } catch (_) {}
    }
  },
);

// Offers (öffentlich)
app.get('/offers', (req: Request, res: Response) => {
  const retailer = (req.query.retailer as string | undefined)?.toUpperCase();
  const week = (req.query.week as string | undefined) || getISOWeek();
  const offers = adapter.getOffers(retailer as any, week);
  res.json({ weekKey: week, offers });
});

// Recipes (öffentlich)
app.get('/recipes', (req: Request, res: Response) => {
  const retailer = (req.query.retailer as string | undefined)?.toUpperCase();
  const week = (req.query.week as string | undefined) || getISOWeek();
  const recipes = adapter.getRecipes(retailer as any, week);
  res.json({ weekKey: week, recipes });
});

// Admin refresh (POST, Secret im Header)
app.post('/admin/refresh-offers', async (req: Request, res: Response) => {
  const header = (req.headers['x-admin-secret'] as string) || '';
  if (!ADMIN_SECRET || header !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  const weekKey = (req.body?.weekKey as string | undefined) || getISOWeek();
  const summary = await refreshAll(weekKey);
  res.json(summary);
});

// Admin refresh (GET, für Vercel Cron via ?key=...)
app.get('/admin/refresh-offers', async (req: Request, res: Response) => {
  const key = (req.query.key as string) || '';
  if (!ADMIN_SECRET || key !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  const weekKey = (req.query.weekKey as string | undefined) || getISOWeek();
  const summary = await refreshAll(weekKey);
  res.json(summary);
});

// Admin refresh recipes (POST, Secret im Header)
app.post('/admin/refresh-recipes', async (req: Request, res: Response) => {
  const header = (req.headers['x-admin-secret'] as string) || '';
  if (!ADMIN_SECRET || header !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  const startTime = Date.now();
  const weekKey = (req.body?.weekKey as string | undefined) || getISOWeek();
  const retailers: Retailer[] = ['REWE', 'EDEKA', 'LIDL', 'ALDI', 'NETTO'];
  
  const totals: Record<string, number> = {};
  const allRecipes: Recipe[] = [];
  
  for (const retailer of retailers) {
    try {
      // Get offers for this retailer and week
      const offers = adapter.getOffers(retailer, weekKey);
      
      if (offers.length === 0) {
        console.log(`[recipes] No offers found for ${retailer} (${weekKey}), skipping`);
        totals[retailer] = 0;
        continue;
      }
      
      // Generate recipes using AI
      const recipes = await generateRecipes({ retailer, weekKey, offers });
      allRecipes.push(...recipes);
      totals[retailer] = recipes.length;
      
      console.log(`[recipes] Generated ${recipes.length} recipes for ${retailer}`);
    } catch (error) {
      console.error(`[recipes] Failed to generate recipes for ${retailer}:`, error);
      totals[retailer] = 0;
    }
  }
  
  // Save all recipes to database
  if (allRecipes.length > 0) {
    adapter.upsertRecipes(allRecipes);
  }
  
  const duration = Date.now() - startTime;
  res.json({
    weekKey,
    totals,
    durationMs: duration,
    totalRecipes: allRecipes.length
  });
});

// Admin refresh recipes (GET, für Vercel Cron via ?key=...)
app.get('/admin/refresh-recipes', async (req: Request, res: Response) => {
  const key = (req.query.key as string) || '';
  if (!ADMIN_SECRET || key !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  const startTime = Date.now();
  const weekKey = (req.query.weekKey as string | undefined) || getISOWeek();
  const retailers: Retailer[] = ['REWE', 'EDEKA', 'LIDL', 'ALDI', 'NETTO'];
  
  const totals: Record<string, number> = {};
  const allRecipes: Recipe[] = [];
  
  for (const retailer of retailers) {
    try {
      // Get offers for this retailer and week
      const offers = adapter.getOffers(retailer, weekKey);
      
      if (offers.length === 0) {
        console.log(`[recipes] No offers found for ${retailer} (${weekKey}), skipping`);
        totals[retailer] = 0;
        continue;
      }
      
      // Generate recipes using AI
      const recipes = await generateRecipes({ retailer, weekKey, offers });
      allRecipes.push(...recipes);
      totals[retailer] = recipes.length;
      
      console.log(`[recipes] Generated ${recipes.length} recipes for ${retailer}`);
    } catch (error) {
      console.error(`[recipes] Failed to generate recipes for ${retailer}:`, error);
      totals[retailer] = 0;
    }
  }
  
  // Save all recipes to database
  if (allRecipes.length > 0) {
    adapter.upsertRecipes(allRecipes);
  }
  
  const duration = Date.now() - startTime;
  res.json({
    weekKey,
    totals,
    durationMs: duration,
    totalRecipes: allRecipes.length
  });
});

// Admin endpoint für Brand-Map Management
app.post('/admin/brand-map', async (req: Request, res: Response) => {
  const header = (req.headers['x-admin-secret'] as string) || '';
  if (!ADMIN_SECRET || header !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  const { retailer, brand, keywords } = req.body;
  
  if (!retailer || !brand || !Array.isArray(keywords)) {
    return res.status(400).json({ 
      error: 'Invalid request body. Expected: { retailer: string, brand: string, keywords: string[] }' 
    });
  }
  
  try {
    updateBrandMap([{ brand, keywords }]);
    res.json({ success: true, message: `Updated brand map for ${retailer}: ${brand}` });
  } catch (error) {
    console.error('[admin] Failed to update brand map:', error);
    res.status(500).json({ error: 'Failed to update brand map' });
  }
});

// Admin endpoint für Media-Cleanup
app.post('/admin/cleanup-media', async (req: Request, res: Response) => {
  const header = (req.headers['x-admin-secret'] as string) || '';
  if (!ADMIN_SECRET || header !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  
  const { cleanupOldImages } = await import('./route.js');
  const maxAgeMs = req.body?.maxAgeMs || 7 * 24 * 60 * 60 * 1000; // 7 Tage default
  
  try {
    await cleanupOldImages(maxAgeMs);
    res.json({ success: true, message: 'Media cleanup completed' });
  } catch (error) {
    console.error('[admin] Failed to cleanup media:', error);
    res.status(500).json({ error: 'Failed to cleanup media' });
  }
});

// ==========================================
// EDEKA Market Endpoints
// ==========================================

// Suche EDEKA-Märkte nach PLZ (öffentlich)
app.get('/edeka/markets', async (req: Request, res: Response) => {
  const plz = req.query.plz as string | undefined;
  
  if (!plz || !/^\d{5}$/.test(plz)) {
    return res.status(400).json({ error: 'Invalid PLZ. Expected 5 digits.' });
  }
  
  try {
    const markets = await fetchMarketsByPLZ(plz);
    res.json({ markets });
  } catch (error) {
    console.error('[EDEKA] Market search failed:', error);
    res.status(500).json({ 
      error: 'Market search failed', 
      message: error instanceof Error ? error.message : String(error) 
    });
  }
});

// Speichere Markt (öffentlich - für Flutter-App)
app.post('/edeka/markets', async (req: Request, res: Response) => {
  const { id, name, address, zipCode, city, coordinates } = req.body;
  
  if (!id || !name) {
    return res.status(400).json({ error: 'Missing required fields: id, name' });
  }
  
  try {
    saveMarket({
      id,
      name,
      address: address
        ? {
            street: address.street || undefined,
            zipCode: zipCode || undefined,
            city: city || undefined,
          }
        : {},
      coordinates: coordinates ? { latitude: coordinates.latitude, longitude: coordinates.longitude } : undefined,
    });
    
    res.json({ success: true, message: 'Market saved' });
  } catch (error) {
    console.error('[EDEKA] Failed to save market:', error);
    res.status(500).json({ error: 'Failed to save market' });
  }
});

// Lade alle gespeicherten Märkte (öffentlich)
app.get('/edeka/markets/saved', (req: Request, res: Response) => {
  try {
    const markets = getAllMarkets('EDEKA');
    res.json({ markets });
  } catch (error) {
    console.error('[EDEKA] Failed to load markets:', error);
    res.status(500).json({ error: 'Failed to load markets' });
  }
});

// Lade Angebote für einen Markt (öffentlich)
app.get('/edeka/markets/:marketId/offers', async (req: Request, res: Response) => {
  const { marketId } = req.params;
  
  try {
    const offers = await fetchEdekaOffersForMarket(marketId);
    res.json({ marketId, offers, count: offers.length });
  } catch (error) {
    console.error(`[EDEKA] Failed to fetch offers for market ${marketId}:`, error);
    res.status(500).json({ 
      error: 'Failed to fetch offers', 
      message: error instanceof Error ? error.message : String(error) 
    });
  }
});

const port = Number(process.env.PORT || 3000);

// Start server
app.listen(port, async () => {
  // eslint-disable-next-line no-console
  console.log(`[server] listening on 0.0.0.0:${port}`);
  console.log(`[server] DB=${process.env.DB || 'sqlite'} DATA_DIR=${process.env.DATA_DIR || join(process.cwd(), 'data')}`);
  console.log(`[server] MEDIA_DIR=${MEDIA_DIR}`);
  
  // Initialize database
  await ensureMediaDir();
  await initializeDatabase();
});

export default app;