/**
 * REWE Fetcher mit Playwright-basierter Extraktion
 * 
 * Nutzt fetch_rewe_offers.mjs für robuste Offer-Extraktion
 * Liest generierte JSON-Dateien und speichert in SQLite
 */

import type { Offer } from '../types.js';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { readFile, access, constants } from 'fs/promises';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { adapter } from '../db.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const execFileAsync = promisify(execFile);

interface ReweOfferJson {
  weekKey: string;
  year: number;
  week: number;
  totalOffers: number;
  offers: Array<{
    id: string;
    title: string;
    price: number;
    originalPrice?: number | null;
    discountPercent?: number | string | null;
    unit?: string;
    brand?: string | null;
    category?: string | null;
    imageUrl?: string;
    validFrom?: string;
    validTo?: string;
    weekKey?: string;
    retailer?: string;
    [key: string]: unknown;
  }>;
}

/**
 * Berechnet ISO-Kalenderwoche (Montag = Wochenanfang)
 */
function getYearWeek(date = new Date()): { year: number; week: number; weekKey: string } {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  const year = d.getUTCFullYear();
  const week = String(weekNo).padStart(2, '0');
  return { year, week: weekNo, weekKey: `${year}-W${week}` };
}

/**
 * Findet die neueste Offers-JSON-Datei für die Woche
 */
async function findOffersJson(year: number, week: number): Promise<string | null> {
  const weekDir = `W${week.toString().padStart(2, '0')}`;
  const dataDir = resolve(__dirname, '../../data/rewe', String(year), weekDir);
  
  // Prüfe auf merged offers.json
  const mergedPath = join(dataDir, 'offers.json');
  try {
    await access(mergedPath, constants.F_OK);
    return mergedPath;
  } catch {
    // Fallback: Suche nach einzelnen offers_*.json
    try {
      const fs = await import('fs/promises');
      const files = await fs.readdir(dataDir);
      const offerFiles = files.filter(f => f.startsWith('offers_') && f.endsWith('.json'));
      
      if (offerFiles.length > 0) {
        // Nimm die neueste Datei
        let newestPath = '';
        let newestTime = 0;
        
        for (const file of offerFiles) {
          const filePath = join(dataDir, file);
          const stats = await fs.stat(filePath);
          if (stats.mtimeMs > newestTime) {
            newestTime = stats.mtimeMs;
            newestPath = filePath;
          }
        }
        
        return newestPath || null;
      }
    } catch {
      // Directory existiert nicht
    }
  }
  
  return null;
}

/**
 * Ruft fetch_rewe_offers.mjs auf, um Offers zu extrahieren
 */
async function runReweExtractor(weekKey?: string): Promise<void> {
  const scriptPath = resolve(__dirname, '../../tools/leaflets/fetch_rewe_offers.mjs');
  
  try {
    await execFileAsync('node', [scriptPath], {
      cwd: resolve(__dirname, '../..'),
      maxBuffer: 10 * 1024 * 1024, // 10MB
    });
  } catch (err) {
    const error = err as Error;
    throw new Error(`REWE Extractor failed: ${error.message}`);
  }
}

/**
 * Konvertiert REWE JSON-Format zu unserem Offer-Format
 */
function convertToOffer(reweOffer: ReweOfferJson['offers'][0], weekKey: string): Offer {
  const now = new Date().toISOString();
  
  return {
    id: reweOffer.id || `REWE-${weekKey}-${reweOffer.title.toLowerCase().replace(/\s+/g, '-')}`,
    retailer: 'REWE',
    title: reweOffer.title,
    price: reweOffer.price,
    unit: reweOffer.unit || 'Stück',
    validFrom: reweOffer.validFrom || now,
    validTo: reweOffer.validTo || new Date(Date.now() + 6 * 24 * 3600 * 1000).toISOString(),
    imageUrl: reweOffer.imageUrl || '',
    updatedAt: now,
    weekKey: weekKey,
    brand: reweOffer.brand || null,
    originalPrice: reweOffer.originalPrice || null,
    discountPercent: reweOffer.discountPercent || null,
    category: reweOffer.category || null,
  };
}

/**
 * Haupt-Funktion: Extrahiert REWE-Offers und speichert sie in SQLite
 */
export async function fetchReweOffersPlaywright(weekKey?: string): Promise<Offer[]> {
  const { year, week, weekKey: calculatedWeekKey } = getYearWeek();
  const targetWeekKey = weekKey || calculatedWeekKey;
  
  console.log(`[REWE] Starte Extraktion für ${targetWeekKey}...`);
  
  // Führe den Extractor aus
  await runReweExtractor(targetWeekKey);
  
  // Finde die generierte JSON-Datei
  const jsonPath = await findOffersJson(year, week);
  
  if (!jsonPath) {
    throw new Error(`REWE Offers JSON nicht gefunden für ${targetWeekKey}`);
  }
  
  // Lese JSON
  const jsonContent = await readFile(jsonPath, 'utf-8');
  const data: ReweOfferJson = JSON.parse(jsonContent);
  
  if (!data.offers || data.offers.length === 0) {
    console.warn(`[REWE] Keine Offers gefunden in ${jsonPath}`);
    return [];
  }
  
  // Konvertiere zu unserem Format
  const offers: Offer[] = data.offers.map((offer) => convertToOffer(offer, targetWeekKey));
  
  // Validiere Offers
  const validOffers = offers.filter((offer) => {
    return offer.title && offer.title.length > 0 && offer.price > 0;
  });
  
  if (validOffers.length === 0) {
    throw new Error(`[REWE] Keine gültigen Offers gefunden (${offers.length} total, alle ungültig)`);
  }
  
  console.log(`[REWE] ${validOffers.length} gültige Offers gefunden (${offers.length} total)`);
  
  // Speichere in SQLite
  adapter.upsertOffers('REWE', targetWeekKey, validOffers);
  console.log(`[REWE] Offers in SQLite gespeichert`);
  
  return validOffers;
}

