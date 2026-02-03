/**
 * Lidl Fetcher mit Playwright-basierter Extraktion
 * 
 * Nutzt fetch_lidl_leaflet.mjs für robuste Offer-Extraktion
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

interface LidlOfferJson {
  weekKey: string;
  year: number;
  week: number;
  totalOffers: number;
  offers: Array<{
    id: string;
    title: string;
    price: number;
    priceText?: string;
    originalPrice?: number;
    unit?: string;
    brand?: string;
    imageUrl?: string;
    validFrom?: string;
    validTo?: string;
    page?: number;
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
  const dataDir = resolve(__dirname, '../../data/lidl', String(year), weekDir);
  
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
 * Ruft fetch_lidl_leaflet.mjs auf, um Offers zu extrahieren
 */
async function runPlaywrightExtractor(url?: string): Promise<string> {
  const scriptPath = resolve(__dirname, '../../tools/leaflets/fetch_lidl_leaflet.mjs');
  
  const args = ['--capture-only'];
  if (url) {
    args.push(url);
  }
  
  try {
    const { stdout, stderr } = await execFileAsync('node', [scriptPath, ...args], {
      cwd: resolve(__dirname, '../..'),
      maxBuffer: 10 * 1024 * 1024, // 10MB
      timeout: 300_000, // 5 Minuten
    });
    
    if (stderr && !stderr.includes('DEBUG')) {
      console.warn('[Lidl Playwright] Warnings:', stderr);
    }
    
    return stdout;
  } catch (error: unknown) {
    const err = error as { code?: string; signal?: string; message?: string };
    throw new Error(
      `Playwright Extractor failed: ${err.message || 'Unknown error'} (code: ${err.code || 'N/A'})`
    );
  }
}

/**
 * Konvertiert LidlOffer zu Offer-Format
 */
function normalizeOffer(raw: LidlOfferJson['offers'][0], weekKey: string, index: number): Offer {
  const now = new Date();
  
  // Parse validFrom/validTo
  let validFrom = raw.validFrom || now.toISOString();
  let validTo = raw.validTo || new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString();
  
  // Extrahiere Preis aus priceText falls nötig
  let price = raw.price;
  if (!price && raw.priceText) {
    const priceMatch = raw.priceText.match(/(\d+[,.]\d{2})/);
    if (priceMatch) {
      price = parseFloat(priceMatch[1].replace(',', '.'));
    }
  }
  
  // Unit aus priceText extrahieren falls nötig
  let unit = raw.unit || '';
  if (!unit && raw.priceText) {
    const unitMatch = raw.priceText.match(/[\d.,]+\s*€?\s*\/([^€\s]+)/i);
    if (unitMatch) {
      unit = unitMatch[1].trim();
    }
  }
  
  if (!unit) {
    unit = 'Stück';
  }
  
  // ID sicherstellen
  const offerId = raw.id || `lidl-${weekKey}-${index}`;
  
  return {
    id: offerId,
    retailer: 'LIDL',
    title: raw.title || 'Unbekanntes Produkt',
    price: price || 0,
    unit,
    validFrom,
    validTo,
    imageUrl: raw.imageUrl || '',
    updatedAt: now.toISOString(),
    weekKey,
    brand: raw.brand || null,
    originalPrice: raw.originalPrice || null,
    discountPercent: raw.originalPrice && price
      ? Math.round(((raw.originalPrice - price) / raw.originalPrice) * 100)
      : null,
    category: null,
    page: raw.page || null,
    metadata: {
      source: 'playwright-extraction',
      priceText: raw.priceText || null,
    },
  };
}

/**
 * Hauptfunktion: Extrahiert Lidl-Offers
 */
export async function fetchLidlOffersPlaywright(weekKey?: string): Promise<Offer[]> {
  const { year, week, weekKey: calculatedWeekKey } = getYearWeek();
  const targetWeekKey = weekKey || calculatedWeekKey;
  
  console.log(`[Lidl Playwright] Starte Extraktion für Woche ${targetWeekKey}...`);
  
  try {
    // Schritt 1: Prüfe ob JSON bereits existiert
    let jsonPath = await findOffersJson(year, week);
    
    if (!jsonPath) {
      console.log('[Lidl Playwright] Keine existierende JSON gefunden, starte Extraktion...');
      
      // Schritt 2: Führe Playwright-Extraktion aus
      const url = process.env.LIDL_LEAFLET_URL || undefined;
      await runPlaywrightExtractor(url);
      
      // Schritt 3: Suche erneut nach JSON
      jsonPath = await findOffersJson(year, week);
      
      if (!jsonPath) {
        throw new Error(`Offers-JSON nicht gefunden nach Extraktion (Woche ${targetWeekKey})`);
      }
    } else {
      console.log(`[Lidl Playwright] Nutze existierende JSON: ${jsonPath}`);
    }
    
    // Schritt 4: Lade und parse JSON
    const jsonContent = await readFile(jsonPath, 'utf-8');
    const data: LidlOfferJson = JSON.parse(jsonContent);
    
    if (!data.offers || !Array.isArray(data.offers)) {
      throw new Error(`Ungültiges JSON-Format: ${jsonPath}`);
    }
    
    console.log(`[Lidl Playwright] ${data.totalOffers} Offers in JSON gefunden`);
    
    // Schritt 5: Filtere nur Lebensmittel-Angebote (VOR Normalisierung, damit wir categories haben)
    const foodCategories = [
      /lebensmittel/i,
      /food/i,
      /nahrung/i,
      /essen/i,
      /milch/i,
      /brot/i,
      /käse|kaese/i,
      /fleisch/i,
      /obst/i,
      /gemüse|gemuese/i,
      /wasser/i,
      /joghurt/i,
      /wurst/i,
      /eis/i,
      /pizza/i,
      /nudeln/i,
      /reis/i,
      /öl|oel/i,
      /butter/i,
      /saft/i,
      /bier/i,
      /wein/i,
      /kaffee/i,
      /tee/i,
      /schokolade/i,
      /kekse/i,
      /kuchen/i,
    ];
    
    const excludeCategories = [
      /mode/i,
      /fashion/i,
      /bekleidung/i,
      /schuhe/i,
      /hausschuhe/i,
      /pullover/i,
      /cardigan/i,
      /pyjama/i,
      /spielzeug/i,
      /toy/i,
      /elektronik/i,
      /electronics/i,
      /baumarkt/i,
      /hardware/i,
      /garten/i,
      /garden/i,
      /möbel|moebel/i,
      /furniture/i,
      /textilien/i,
      /textiles/i,
      /wein & spirituosen/i,
      /wein & sprit/i,
      /wein & spr/i,
      /spirituosen/i,
      /spirituo/i,
      /weinbrand/i,
      /champagner/i,
      /sek/i,
      /likör|likoer/i,
      /whiskey/i,
      /gin/i,
      /vodka/i,
      /rum/i,
      /cognac/i,
      /brandy/i,
      /rak/i,
    ];
    
    // Filtere nach Kategorien (auf RAW-Daten, bevor Normalisierung)
    const foodOffersRaw = data.offers.filter((raw: any) => {
      // Prüfe Kategorien im RAW-Offer
      const categoryParts: string[] = [];
      if (raw.category) categoryParts.push(raw.category);
      if (raw.categories && Array.isArray(raw.categories)) {
        categoryParts.push(...raw.categories);
      }
      if (raw.title) categoryParts.push(raw.title);
      if (raw.description) categoryParts.push(raw.description);
      if (raw.campaigns && Array.isArray(raw.campaigns)) {
        categoryParts.push(...raw.campaigns);
      }
      
      const categoryStr = categoryParts.join(' ').toLowerCase();
      
      // Exclude: Wenn Mode/Kleidung/etc. enthalten ist, ausschließen
      const isExcluded = excludeCategories.some(pattern => pattern.test(categoryStr));
      if (isExcluded) return false;
      
      // Include: Wenn Lebensmittel-Kategorien vorhanden, einbeziehen
      const isFood = foodCategories.some(pattern => pattern.test(categoryStr));
      if (isFood) return true;
      
      // Fallback: Prüfe Titel auf Lebensmittel-Keywords
      const titleStr = (raw.title || '').toLowerCase();
      const foodKeywords = [
        'milch', 'joghurt', 'quark', 'sahne', 'käse', 'kaese', 'mozzarella', 'parmesan',
        'brot', 'brötchen', 'baguette', 'toast', 'semmel',
        'fleisch', 'huhn', 'rind', 'schwein', 'lachs', 'thunfisch', 'garnelen',
        'obst', 'apfel', 'banane', 'orange', 'erdbeere', 'traube',
        'gemüse', 'gemuese', 'tomate', 'gurke', 'paprika', 'kartoffel', 'zwiebel',
        'nudeln', 'reis', 'pasta', 'spaghetti', 'penne',
        'öl', 'oel', 'butter', 'margarine',
        'kaffee', 'tee', 'wasser', 'saft', 'cola', 'bier', 'wein',
        'schokolade', 'kekse', 'kuchen', 'torte',
        'eis', 'creme', 'pudding',
        'ei', 'eier',
        'salz', 'pfeffer', 'zucker', 'honig',
      ];
      
      const hasFoodKeyword = foodKeywords.some(keyword => titleStr.includes(keyword));
      
      // Exclude: Wenn Mode-Brand im Titel (esmara, lupilu, etc.)
      const modeBrands = ['esmara', 'lupilu', 'sensiplast', 'fan', 'beco', 'bierbaum'];
      const hasModeBrand = modeBrands.some(brand => titleStr.includes(brand));
      if (hasModeBrand) return false;
      
      // Exclude: Wein & Spirituosen (nur echte Lebensmittel)
      const alcoholKeywords = ['wein', 'champagner', 'sek', 'likör', 'likoer', 'whiskey', 'gin', 'vodka', 'rum', 'cognac', 'brandy', 'raki', 'schnaps', 'bitters', 'aperitif', 'portwein', 'sherry'];
      const hasAlcohol = alcoholKeywords.some(keyword => titleStr.includes(keyword));
      if (hasAlcohol) return false;
      
      // Exclude: Bier (falls gewünscht - kann auskommentiert werden)
      // const hasBeer = titleStr.includes('bier') && !titleStr.includes('biergarten') && !titleStr.includes('bierkruste');
      // if (hasBeer) return false;
      
      return hasFoodKeyword;
    });
    
    console.log(`[Lidl Playwright] ${data.offers.length} Offers gesamt, ${foodOffersRaw.length} Lebensmittel-Angebote gefunden`);
    
    // Schritt 6: Normalisiere gefilterte Offers
    const foodOffers = foodOffersRaw.map((raw, index) => 
      normalizeOffer(raw, targetWeekKey, index)
    );
    
    // Schritt 7: Validiere Offers
    const validOffers = foodOffers.filter(o => {
      if (!o.title || o.title === 'Unbekanntes Produkt') return false;
      if (!o.price || o.price <= 0) return false;
      return true;
    });
    
    if (validOffers.length === 0) {
      throw new Error(`Keine gültigen Lebensmittel-Offers gefunden (${data.offers.length} total, ${foodOffersRaw.length} nach Filter)`);
    }
    
    if (validOffers.length < foodOffers.length) {
      console.warn(`[Lidl Playwright] ${foodOffers.length - validOffers.length} ungültige Offers übersprungen`);
    }
    
    console.log(`[Lidl Playwright] ${validOffers.length} gültige Offers extrahiert`);
    
    // Schritt 7: Speichere in SQLite
    adapter.upsertOffers('LIDL', targetWeekKey, validOffers);
    console.log(`[Lidl Playwright] ${validOffers.length} Offers in SQLite gespeichert`);
    
    return validOffers;
    
  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error));
    console.error(`[Lidl Playwright] Fehler:`, err.message);
    throw err;
  }
}

