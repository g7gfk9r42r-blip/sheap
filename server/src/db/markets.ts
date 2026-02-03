/**
 * Market Database Management
 * 
 * Verwaltet gespeicherte EDEKA-Märkte in SQLite.
 */

import Database from 'better-sqlite3';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'url';
import type { EdekaMarket } from '../services/edeka_api.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
// Persist data on the host via DATA_DIR (recommended absolute path on Render Disk).
// Default: <repo>/roman_app/server/data (when started from roman_app/server)
const DATA_DIR = process.env.DATA_DIR || join(process.cwd(), 'data');
const DB_PATH = join(DATA_DIR, 'grocify.db');

let db: Database.Database | null = null;

function getDatabase(): Database.Database {
  if (!db) {
    db = new Database(DB_PATH);
    migrate();
  }
  return db;
}

function migrate(): void {
  const sql = `
    PRAGMA journal_mode = WAL;
    
    CREATE TABLE IF NOT EXISTS markets (
      id TEXT PRIMARY KEY,
      marketType TEXT NOT NULL,
      name TEXT NOT NULL,
      address TEXT,
      zipCode TEXT,
      city TEXT,
      latitude REAL,
      longitude REAL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    );
    
    CREATE INDEX IF NOT EXISTS idx_markets_type ON markets(marketType);
  `;
  
  getDatabase().exec(sql);
}

export type SavedMarket = {
  id: string;
  marketType: 'EDEKA' | 'REWE' | 'LIDL' | 'ALDI' | 'NETTO';
  name: string;
  address?: string;
  zipCode?: string;
  city?: string;
  latitude?: number;
  longitude?: number;
  createdAt: string;
  updatedAt: string;
};

/**
 * Speichert einen Markt
 */
export function saveMarket(market: EdekaMarket, marketType: 'EDEKA' = 'EDEKA'): void {
  const dbc = getDatabase();
  const now = new Date().toISOString();
  
  const stmt = dbc.prepare(`
    INSERT INTO markets (id, marketType, name, address, zipCode, city, latitude, longitude, createdAt, updatedAt)
    VALUES (@id, @marketType, @name, @address, @zipCode, @city, @latitude, @longitude, @createdAt, @updatedAt)
    ON CONFLICT(id) DO UPDATE SET
      name = excluded.name,
      address = excluded.address,
      zipCode = excluded.zipCode,
      city = excluded.city,
      latitude = excluded.latitude,
      longitude = excluded.longitude,
      updatedAt = excluded.updatedAt
  `);
  
  stmt.run({
    id: market.id,
    marketType,
    name: market.name,
    address: market.address?.street || null,
    zipCode: market.address?.zipCode || null,
    city: market.address?.city || null,
    latitude: market.coordinates?.latitude || null,
    longitude: market.coordinates?.longitude || null,
    createdAt: now,
    updatedAt: now,
  });
  
  console.log(`[Markets] Markt gespeichert: ${market.name} (${market.id})`);
}

/**
 * Lädt alle gespeicherten Märkte
 */
export function getAllMarkets(marketType?: 'EDEKA' | 'REWE' | 'LIDL' | 'ALDI' | 'NETTO'): SavedMarket[] {
  const dbc = getDatabase();
  
  let sql = 'SELECT * FROM markets';
  const params: Record<string, unknown> = {};
  
  if (marketType) {
    sql += ' WHERE marketType = @marketType';
    params.marketType = marketType;
  }
  
  sql += ' ORDER BY name ASC';
  
  return dbc.prepare(sql).all(params) as SavedMarket[];
}

/**
 * Lädt einen spezifischen Markt
 */
export function getMarket(marketId: string): SavedMarket | null {
  const dbc = getDatabase();
  const stmt = dbc.prepare('SELECT * FROM markets WHERE id = ?');
  return (stmt.get(marketId) as SavedMarket) || null;
}

/**
 * Löscht einen Markt
 */
export function deleteMarket(marketId: string): void {
  const dbc = getDatabase();
  const stmt = dbc.prepare('DELETE FROM markets WHERE id = ?');
  stmt.run(marketId);
  console.log(`[Markets] Markt gelöscht: ${marketId}`);
}

