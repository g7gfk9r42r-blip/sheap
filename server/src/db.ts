/**
 * Database abstraction layer with SQLite and in-memory adapters.
 * - ESM-safe paths
 * - JSON-Persistenz für den Memory-Adapter
 * - Einheitliche Node-Imports mit `node:`-Präfix
 */

import type {
  Offer,
  Retailer,
  DBAdapter,
  OffersDB,
} from './types.js';

import { promises as fs } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

import { upsertOffers as sqliteUpsertOffers, getOffers as sqliteGetOffers } from './sqlite.js';

// ---- ESM-safe Pfade ----------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// Persist data on the host via DATA_DIR (recommended absolute path on Render Disk).
// Default: <repo>/roman_app/server/data (when started from roman_app/server)
const DATA_DIR = process.env.DATA_DIR || join(process.cwd(), 'data');
const OFFERS_FILE = join(DATA_DIR, 'offers.json');

// ---- In-memory Store: Map<weekKey, Map<retailer, Map<offerId, Offer>>> -------
const store = new Map<string, Map<Retailer, Map<string, Offer>>>();

/**
 * Vergewissert sich, dass das Datenverzeichnis existiert.
 */
async function ensureDataDir(): Promise<void> {
  try {
    await fs.mkdir(DATA_DIR, { recursive: true });
  } catch (error) {
    console.warn('[db] Could not create data directory:', error);
  }
}

/**
 * Liefert (oder erstellt) die Retailer-Map für eine Woche.
 */
function ensureWeekRetailer(
  weekKey: string,
  retailer: Retailer,
): Map<string, Offer> {
  let weekMap = store.get(weekKey);
  if (!weekMap) {
    weekMap = new Map();
    store.set(weekKey, weekMap);
  }

  let retailerMap = weekMap.get(retailer);
  if (!retailerMap) {
    retailerMap = new Map();
    weekMap.set(retailer, retailerMap);
  }

  return retailerMap;
}

/**
 * Serialisiert den Store als JSON-Plain-Objekte.
 */
function storeToJson(): Record<string, Record<string, Record<string, Offer>>> {
  const result: Record<string, Record<string, Record<string, Offer>>> = {};

  for (const [weekKey, weekMap] of store) {
    result[weekKey] = {};
    for (const [retailer, retailerMap] of weekMap) {
      result[weekKey][retailer] = {};
      for (const [offerId, offer] of retailerMap) {
        result[weekKey][retailer][offerId] = offer;
      }
    }
  }

  return result;
}

/**
 * Lädt serialisierte Daten in den Store.
 */
function loadFromJson(
  data: Record<string, Record<string, Record<string, Offer>>>,
): void {
  store.clear();

  for (const [weekKey, weekMap] of Object.entries(data)) {
    const weekMapObj = new Map<Retailer, Map<string, Offer>>();

    for (const [retailer, retailerMap] of Object.entries(weekMap)) {
      const retailerMapObj = new Map<string, Offer>();

      for (const [offerId, offer] of Object.entries(retailerMap)) {
        retailerMapObj.set(offerId, offer as Offer);
      }

      weekMapObj.set(retailer as Retailer, retailerMapObj);
    }

    store.set(weekKey, weekMapObj);
  }
}

// ---- In-memory Datenbank-Implementierung ------------------------------------
export const db: OffersDB = {
  /**
   * Upsert von Angeboten für Retailer/Woche (idempotent via offer.id).
   */
  upsertOffers(retailer: Retailer, weekKey: string, offers: Offer[]): void {
    const retailerMap = ensureWeekRetailer(weekKey, retailer);
    for (const offer of offers) {
      retailerMap.set(offer.id, offer);
    }
    console.log(
      `[db] Upserted ${offers.length} offers for ${retailer} (${weekKey})`,
    );
  },

  /**
   * Abfrage von Angeboten mit optionalen Filtern.
   */
  getOffers(retailer?: Retailer, weekKey?: string): Offer[] {
    const result: Offer[] = [];
    const weeks = weekKey ? [weekKey] : Array.from(store.keys());

    for (const wk of weeks) {
      const weekMap = store.get(wk);
      if (!weekMap) continue;

      const retailers = retailer
        ? [retailer]
        : (Array.from(weekMap.keys()) as Retailer[]);

      for (const r of retailers) {
        const retailerMap = weekMap.get(r);
        if (!retailerMap) continue;
        result.push(...retailerMap.values());
      }
    }

    // Stabile Sortierung: zuerst Retailer, dann Titel.
    result.sort((a, b) => {
      const byRetailer = a.retailer.localeCompare(b.retailer);
      if (byRetailer !== 0) return byRetailer;
      return a.title.localeCompare(b.title);
    });

    return result;
  },
};

// ---- Persistenz für den Memory-Adapter --------------------------------------
/**
 * Speichert den In-Memory-Store als JSON.
 */
export async function saveOffers(): Promise<void> {
  try {
    await ensureDataDir();
    const data = storeToJson();
    await fs.writeFile(OFFERS_FILE, JSON.stringify(data, null, 2), 'utf8');
    console.log(`[db] Saved offers to ${OFFERS_FILE}`);
  } catch (error) {
    console.error('[db] Failed to save offers:', error);
    throw error;
  }
}

/**
 * Lädt JSON-Daten in den In-Memory-Store.
 */
export async function loadOffers(): Promise<void> {
  try {
    await ensureDataDir();
    const raw = await fs.readFile(OFFERS_FILE, 'utf8');
    const data = JSON.parse(raw);
    loadFromJson(data);
    console.log(`[db] Loaded offers from ${OFFERS_FILE}`);
  } catch (error) {
    console.warn('[db] Could not load offers (file may not exist):', error);
    // Beim ersten Start ist das erwartbar – kein Throw.
  }
}

// ---- Memory-Adapter (Backwards Compatibility) --------------------------------
export const memoryAdapter: DBAdapter = {
  upsertOffers(retailer: Retailer, weekKey: string, offers: Offer[]): void {
    db.upsertOffers(retailer, weekKey, offers);
  },

  getOffers(retailer?: Retailer, weekKey?: string): Offer[] {
    return db.getOffers(retailer, weekKey);
  },

  upsertRecipes(_recipes: any[]): void {
    console.warn('[db] Memory adapter does not support recipes - use SQLite adapter');
  },

  getRecipes(_retailer?: Retailer, _weekKey?: string): any[] {
    console.warn('[db] Memory adapter does not support recipes - use SQLite adapter');
    return [];
  },

  async load(): Promise<void> {
    await loadOffers();
  },

  async save(): Promise<void> {
    await saveOffers();
  },
};

// ---- SQLite Adapter ------------------------------------------------------------
export const sqliteAdapter: DBAdapter = {
  upsertOffers(retailer: Retailer, weekKey: string, offers: Offer[]): void {
    sqliteUpsertOffers(retailer, weekKey, offers);
  },

  getOffers(retailer?: Retailer, weekKey?: string): Offer[] {
    return sqliteGetOffers(retailer, weekKey);
  },

  upsertRecipes(_recipes: any[]): void {
    console.warn('[db] SQLite adapter does not support recipes yet');
  },

  getRecipes(_retailer?: Retailer, _weekKey?: string): any[] {
    console.warn('[db] SQLite adapter does not support recipes yet');
    return [];
  },

  async load(): Promise<void> {
    // No-op for SQLite
  },

  async save(): Promise<void> {
    // No-op for SQLite
  },
};

// ---- Adapter-Auswahl ---------------------------------------------------------
/**
 * DB-Adapter Auswahl per ENV:
 *   - DB=sqlite  -> SQLite-Adapter
 *   - sonst      -> Memory-Adapter
 *
 * Hinweis: Für deine aktuelle lokale Entwicklung (Probleme mit better-sqlite3)
 * kannst du temporär `DB=memory` setzen, um ohne native Builds zu starten.
 */
const DB_TYPE = process.env.DB || 'sqlite';
export const adapter: DBAdapter =
  DB_TYPE === 'sqlite' ? sqliteAdapter : memoryAdapter;

// ---- Utils -------------------------------------------------------------------
export function getDatabaseStats(): {
  totalWeeks: number;
  totalRetailers: number;
  totalOffers: number;
  adapterType: string;
} {
  let totalOffers = 0;
  let totalRetailers = 0;

  for (const weekMap of store.values()) {
    totalRetailers += weekMap.size;
    for (const retailerMap of weekMap.values()) {
      totalOffers += retailerMap.size;
    }
  }

  return {
    totalWeeks: store.size,
    totalRetailers,
    totalOffers,
    adapterType: DB_TYPE,
  };
}

export function clearStore(): void {
  store.clear();
  console.log('[db] Cleared in-memory store');
}

export async function initializeDatabase(): Promise<void> {
  console.log(`[db] Initializing database with ${DB_TYPE} adapter`);

  // Ensure media directory exists
  const { ensureMediaDir } = await import('./route.js');
  await ensureMediaDir();

  if (DB_TYPE === 'memory') {
    await loadOffers();
  }

  const stats = getDatabaseStats();
  console.log('[db] Database initialized:', stats);
}