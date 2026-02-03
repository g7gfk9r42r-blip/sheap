import type { Offer } from '../types.js';
import { execFile } from 'child_process';
import { promisify } from 'util';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import fs from 'fs/promises';
import { getYearWeek } from '../utils/date.js';
import { adapter } from '../db.js';

const execFileAsync = promisify(execFile);

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * EDEKA Playwright Fetcher
 * 
 * Nutzt fetch_edeka_offers.mjs, um Angebote direkt von edeka.de zu scrapen.
 * Extrahiert SUPERKNÜLLER-Angebote von der offiziellen Website.
 */
export async function fetchEdekaOffersPlaywright(weekKey?: string): Promise<Offer[]> {
  const { year, week, weekKey: currentWeekKey } = getYearWeek();
  const targetWeekKey = weekKey || currentWeekKey;
  
  console.log(`[EDEKA] Scrape Angebote von edeka.de (${targetWeekKey})...`);
  
  try {
    // Führe Playwright-Script aus
    const scriptPath = resolve(__dirname, '../../tools/edeka/fetch_edeka_offers.mjs');
    
    const { stdout, stderr } = await execFileAsync('node', [scriptPath], {
      cwd: resolve(__dirname, '../..'),
      maxBuffer: 10 * 1024 * 1024, // 10MB
    });
    
    if (stderr) {
      console.warn('[EDEKA] Stderr:', stderr);
    }
    
    // Lese generierte JSON-Datei
    const jsonPath = resolve(__dirname, '../../data/edeka', String(year), `W${week}`, 'offers.json');
    
    let rawOffers: any[] = [];
    try {
      const content = await fs.readFile(jsonPath, 'utf-8');
      const data = JSON.parse(content);
      rawOffers = data.offers || [];
    } catch (err) {
      console.error('[EDEKA] Fehler beim Lesen der JSON-Datei:', err);
      return [];
    }
    
    if (rawOffers.length === 0) {
      console.warn('[EDEKA] Keine Angebote gefunden');
      return [];
    }
    
    // Normalisiere zu Offer-Format
    const now = new Date();
    const validFrom = now.toISOString();
    const validTo = new Date(now.getTime() + 6 * 24 * 60 * 60 * 1000).toISOString();
    
    const offers: Offer[] = rawOffers.map((raw, index) => ({
      id: `edeka-${targetWeekKey}-${index + 1}-${Date.now()}`,
      retailer: 'EDEKA',
      title: raw.title,
      price: raw.price,
      unit: raw.unit || null,
      validFrom,
      validTo,
      imageUrl: raw.imageUrl || null,
      updatedAt: now.toISOString(),
      weekKey: targetWeekKey,
      brand: null,
      originalPrice: raw.originalPrice || null,
      discountPercent: raw.discount || null,
      category: null,
      page: null,
      metadata: {
        source: 'edeka.de',
        rawText: raw.rawText || null,
      },
    }));
    
    // Speichere in SQLite
    adapter.upsertOffers('EDEKA', targetWeekKey, offers);
    
    console.log(`[EDEKA] ✅ ${offers.length} Angebote gespeichert`);
    
    return offers;
  } catch (err) {
    console.error('[EDEKA] Fehler beim Scrapen:', err);
    return [];
  }
}

