import Database from 'better-sqlite3';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'url';
import type { Offer, Retailer } from './types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// Persist data on the host via DATA_DIR (recommended absolute path on Render Disk).
// Default: <repo>/roman_app/server/data (when started from roman_app/server)
const DATA_DIR = process.env.DATA_DIR || join(process.cwd(), 'data');
const DB_PATH = join(DATA_DIR, 'grocify.db');

let db: Database.Database;

export function getDatabase(): Database.Database {
  if (!db) {
    db = new Database(DB_PATH);
    migrate();
  }
  return db;
}

function migrate(): void {
  const sql = `
  PRAGMA journal_mode = WAL;
  
    CREATE TABLE IF NOT EXISTS offers (
    id        TEXT PRIMARY KEY,
    retailer  TEXT NOT NULL,
    title     TEXT NOT NULL,
    price     REAL NOT NULL,
    unit      TEXT NOT NULL,
      validFrom TEXT NOT NULL,
    validTo   TEXT NOT NULL,
    imageUrl  TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
    weekKey   TEXT NOT NULL,
    brand     TEXT
  );

  CREATE INDEX IF NOT EXISTS idx_offers_week          ON offers(weekKey);
  CREATE INDEX IF NOT EXISTS idx_offers_retailer_week ON offers(retailer, weekKey);
  `;

  getDatabaseInternal().exec(sql);

  // If the table exists from older schema, ensure brand column exists.
  try {
    const row = getDatabaseInternal().prepare(
      "SELECT name FROM pragma_table_info('offers') WHERE name='brand'"
    ).get();
    if (!row) {
      getDatabaseInternal().exec(`ALTER TABLE offers ADD COLUMN brand TEXT;`);
    }
  } catch {
    // ignore, CREATE TABLE above covers fresh DBs
  }
}

function getDatabaseInternal(): Database.Database {
  if (!db) {
    db = new Database(DB_PATH);
  }
  return db;
}

const UPSERT = `
INSERT INTO offers (
  id, retailer, title, price, unit, validFrom, validTo, imageUrl, updatedAt, weekKey, brand
) VALUES (
  @id, @retailer, @title, @price, @unit, @validFrom, @validTo, @imageUrl, @updatedAt, @weekKey, @brand
)
ON CONFLICT(id) DO UPDATE SET
  retailer  = excluded.retailer,
  title     = excluded.title,
  price     = excluded.price,
  unit      = excluded.unit,
  validFrom = excluded.validFrom,
  validTo   = excluded.validTo,
  imageUrl  = excluded.imageUrl,
  updatedAt = excluded.updatedAt,
  weekKey   = excluded.weekKey,
  brand     = excluded.brand
`;

export function upsertOffers(retailer: Retailer, weekKey: string, offers: Offer[]): void {
  const dbc = getDatabase();
  const stmt = dbc.prepare(UPSERT);
  const tx = dbc.transaction((rows: Offer[]) => {
    for (const offer of rows) {
      stmt.run({ ...offer, weekKey });
    }
  });
  tx(offers);
}

export function getOffers(retailer?: Retailer, weekKey?: string): Offer[] {
  const dbc = getDatabase();
  let sql = `
    SELECT id, retailer, title, price, unit, validFrom, validTo, imageUrl, updatedAt, weekKey, brand
    FROM offers
  `;
  const where: string[] = [];
  const params: Record<string, unknown> = {};
  if (retailer) { where.push('retailer = @retailer'); params.retailer = retailer; }
  if (weekKey)  { where.push('weekKey  = @weekKey');  params.weekKey  = weekKey; }
  if (where.length) sql += ' WHERE ' + where.join(' AND ');
  sql += ' ORDER BY retailer ASC, title ASC';
  return dbc.prepare(sql).all(params) as Offer[];
}