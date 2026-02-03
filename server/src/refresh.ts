// server/src/refresh.ts
import type { Retailer, Offer } from './types.js';
import * as ReweMod  from './fetchers/rewe.js';
import * as EdekaMod from './fetchers/edeka.js';
import * as LidlMod  from './fetchers/lidl.js';
import * as AldiMod  from './fetchers/aldi.js';
import * as NettoMod from './fetchers/netto.js';
import { upsertOffers } from './sqlite.js';
import { enrichOffers } from './enrich.js';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import { getAllMarkets } from './db/markets.js';
import { fetchEdekaOffersForMarket } from './fetchers/fetch_edeka_offers.js';

const execFileAsync = promisify(execFile);

/** holt die Fetch-Funktion aus einem Modul, egal ob named oder default */
function pickFetcher(mod: Record<string, unknown>): ((weekKey: string) => Promise<Offer[]>) {
  const cand =
    (mod as { fetchOffers?: (weekKey: string) => Promise<Offer[]> }).fetchOffers ??
    (typeof (mod as { default?: unknown }).default === 'function'
      ? ((mod as { default: (weekKey: string) => Promise<Offer[]> }).default)
      : undefined);

  if (typeof cand !== 'function') {
    // Hilfreiche Fehlermeldung, falls ein Modul falsch exportiert
    const keys = Object.keys(mod).join(', ');
    throw new Error(`Fetcher nicht gefunden. Export-Keys: [${keys}]`);
  }
  return cand;
}

const fetchRewe  = pickFetcher(ReweMod);
const fetchEdeka = pickFetcher(EdekaMod);
const fetchLidl  = pickFetcher(LidlMod);
const fetchAldi  = pickFetcher(AldiMod);
const fetchNetto = pickFetcher(NettoMod);

/** feste Reihenfolge vermeidet TS-Ärger mit Object.keys */
const RETAILERS: Retailer[] = ['REWE', 'EDEKA', 'LIDL', 'ALDI', 'NETTO'];

const SOURCES: Record<Retailer, (weekKey: string) => Promise<Offer[]>> = {
  REWE:  fetchRewe,
  EDEKA: fetchEdeka,
  LIDL:  fetchLidl,
  ALDI:  fetchAldi,
  NETTO: fetchNetto,
};

/**
 * Generiert automatisch das Lidl-PDF für die angegebene Woche.
 * Wird vor dem Offer-Fetch aufgerufen, damit das PDF verfügbar ist.
 * Fehler werden geloggt, aber brechen den Refresh-Prozess nicht ab.
 */
async function fetchLidlPdf(weekKey: string): Promise<void> {
  const __filename = fileURLToPath(import.meta.url);
  const __dirname = dirname(__filename);
  const scriptPath = resolve(__dirname, '../tools/leaflets/fetch_lidl_weekly.mjs');

  try {
    console.log(`[refresh] Starte Lidl-PDF-Generierung für ${weekKey}...`);
    await execFileAsync('node', [scriptPath], {
      cwd: resolve(__dirname, '..')
    });
    console.log(`[refresh] Lidl-PDF erfolgreich generiert für ${weekKey}`);
  } catch (err: unknown) {
    const error = err as { code?: number; message?: string };
    if (error.code !== undefined) {
      console.warn(`[refresh] Lidl-PDF-Generierung fehlgeschlagen (Code ${error.code}), fahre mit Offer-Fetch fort`);
    } else {
      console.warn(`[refresh] Fehler beim Starten der Lidl-PDF-Generierung:`, error.message || String(err));
    }
  }
}

export async function refreshAll(weekKey: string): Promise<Record<Retailer, number>> {
  // PDF-Generierung für Lidl vor dem Offer-Fetch
  await fetchLidlPdf(weekKey).catch((err) => {
    console.warn(`[refresh] Lidl-PDF-Generierung fehlgeschlagen:`, err.message);
  });

  const totals: Record<Retailer, number> = { REWE: 0, EDEKA: 0, LIDL: 0, ALDI: 0, NETTO: 0 };

  // EDEKA: Lade Angebote für alle gespeicherten Märkte über die API
  try {
    const savedEdekaMarkets = getAllMarkets('EDEKA');
    if (savedEdekaMarkets.length > 0) {
      console.log(`[refresh] Found ${savedEdekaMarkets.length} saved EDEKA markets, fetching offers via API...`);
      let edekaTotal = 0;
      for (const market of savedEdekaMarkets) {
        try {
          const offers = await fetchEdekaOffersForMarket(market.id);
          edekaTotal += offers.length;
        } catch (err) {
          console.error(`[refresh] Failed to fetch offers for EDEKA market ${market.id}:`, err instanceof Error ? err.message : String(err));
        }
      }
      totals.EDEKA = edekaTotal;
    } else {
      // Fallback: Nutze den normalen Fetcher (Scraping)
      try {
        const list = await SOURCES.EDEKA(weekKey);
        const enriched = enrichOffers(list);
        upsertOffers('EDEKA', weekKey, enriched);
        totals.EDEKA = enriched.length;
      } catch (err) {
        console.error(`[refreshAll] Failed to refresh EDEKA offers:`, err instanceof Error ? err.message : String(err));
      }
    }
  } catch (err) {
    console.error(`[refresh] EDEKA market fetch failed:`, err instanceof Error ? err.message : String(err));
  }

  // Andere Retailer (REWE, LIDL, ALDI, NETTO)
  for (const retailer of RETAILERS) {
    if (retailer === 'EDEKA') continue; // Already handled above
    
    try {
      const list = await SOURCES[retailer](weekKey);  // Angebote holen
      const enriched = enrichOffers(list);          // Brand synchron anreichern
      upsertOffers(retailer, weekKey, enriched);    // in SQLite inkl. brand speichern
      totals[retailer] = enriched.length;
    } catch (err) {
      console.error(`[refreshAll] Failed to refresh ${retailer} offers:`, err instanceof Error ? err.message : String(err));
      if (process.env.DEBUG) {
        console.error(err);
      }
      // Fehler nicht fatal - weiter mit nächstem Retailer
    }
  }

  return totals;
}