import { crawlMarkdown } from '../services/crawl4ai.js';
import { upsertOffers, type ProspektOffer } from '../db/offers.js';
import { saveJsonFile } from '../utils/files.js';
import { ensureDirSync } from 'fs-extra';
import path from 'path';
import { getYearWeek } from '../utils/date.js';
import type { Offer } from '../types.js';

/**
 * EDEKA Fetcher – Sammelt Angebote aus mehreren regionalen Prospekten
 * 
 * EDEKA ist in 7 Regionalgesellschaften unterteilt:
 * - EDEKA Nord
 * - EDEKA Minden-Hannover
 * - EDEKA Rhein-Ruhr
 * - EDEKA Hessenring
 * - EDEKA Nordbayern-Sachsen-Thüringen
 * - EDEKA Südwest
 * - EDEKA Südbayern
 * 
 * Prospektangebote.de hat meist einen "Edeka Prospekt" der die wichtigsten Angebote enthält.
 * Wir scrapen diesen und extrahieren alle Angebote.
 */

const BASE_URL = 'https://www.prospektangebote.de';

/**
 * Findet die aktuelle EDEKA-Prospekt-URL auf Prospektangebote.de
 */
async function findEdekaProspektUrl(): Promise<string | null> {
  try {
    const response = await fetch(`${BASE_URL}/geschaefte/edeka/prospekte-angebote`);
    const html = await response.text();
    
    // Suche nach dem neuesten Prospekt-Link
    const match = html.match(/href="([^"]*\/anzeigen\/angebote\/edeka[^"]*prospekt[^"]*)"[^>]*data-flyer-id="(\d+)"/i);
    if (match) {
      const url = match[1].startsWith('http') ? match[1] : `${BASE_URL}${match[1]}`;
      return url;
    }
    
    // Fallback: Versuche direkte URL-Struktur
    return `${BASE_URL}/anzeigen/angebote/edeka-prospekt`;
  } catch (err) {
    console.error('[EDEKA] Fehler beim Finden der Prospekt-URL:', err);
    return null;
  }
}

/**
 * Extrahiert Angebote aus Markdown-Text
 */
function extractOffersFromMarkdown(md: string): ProspektOffer[] {
  const offers: ProspektOffer[] = [];
  const lines = md.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  for (const line of lines) {
    // Suche nach Preisen (verschiedene Formate)
    const pricePatterns = [
      /(\d+[.,]\d{2})\s*€/,
      /€\s*(\d+[.,]\d{2})/,
      /(\d+[.,]\d{2})\s*(?:EUR|Euro)/i,
    ];
    
    let price: number | null = null;
    let priceMatch: RegExpMatchArray | null = null;
    
    for (const pattern of pricePatterns) {
      priceMatch = line.match(pattern);
      if (priceMatch) {
        price = parseFloat(priceMatch[1].replace(',', '.'));
        if (price >= 0.01 && price <= 1000) {
          break;
        }
      }
    }
    
    if (!price || !priceMatch) continue;
    
    // Extrahiere Titel (alles vor dem Preis)
    let title = line.replace(priceMatch[0], '').trim();
    
    // Entferne häufige Präfixe
    title = title.replace(/^(SUPERKNÜLLER|Angebot|Aktion|Rabatt|%|-\d+%)\s*/i, '').trim();
    
    // Entferne Rabatt-Informationen
    title = title.replace(/\s*-\d+%\s*/g, ' ').trim();
    title = title.replace(/\s*Niedrig\.\s*Gesamtpreis:\s*€\s*[\d.,]+\s*/gi, '').trim();
    title = title.replace(/\s*1kg\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
    title = title.replace(/\s*1l\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
    
    if (title.length < 3) continue;
    
    // Extrahiere Rabatt
    const discountMatch = line.match(/-(\d+)%/);
    const discount = discountMatch ? discountMatch[1] : null;
    
    // Extrahiere Einheit
    let unit: string | null = null;
    const unitMatch = line.match(/(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung|pck|pack)/i);
    if (unitMatch) {
      unit = `${unitMatch[1]} ${unitMatch[2].toLowerCase()}`;
    }
    
    offers.push({
      title,
      price,
      discount,
      unit,
      raw: line,
    });
  }
  
  return offers;
}

/**
 * Haupt-Fetcher für EDEKA-Angebote
 */
export async function fetchEdekaOffersProspektangebote(): Promise<Offer[]> {
  const { year, week, weekKey } = getYearWeek();
  
  console.log(`[EDEKA] Suche EDEKA-Prospekt auf Prospektangebote.de...`);
  
  const prospektUrl = await findEdekaProspektUrl();
  if (!prospektUrl) {
    console.error('[EDEKA] Keine Prospekt-URL gefunden');
    return [];
  }
  
  console.log(`[EDEKA] Crawling: ${prospektUrl}`);
  
  try {
    const crawl = await crawlMarkdown(prospektUrl, {
      wait_until: 'domcontentloaded',
      simulate_user: true,
      scroll_page: true,
      magic: true,
    });
    
    if (!crawl || !crawl.markdown) {
      console.error('[EDEKA] Kein Markdown extrahiert');
      return [];
    }
    
    const md = crawl.markdown.raw_markdown || crawl.markdown.markdown_with_citations || '';
    console.log(`[EDEKA] Extrahierter Markdown: ${md.length} Zeichen`);
    
    const offers = extractOffersFromMarkdown(md);
    console.log(`[EDEKA] ${offers.length} Angebote gefunden`);
    
    // Speichere JSON
    const outDir = path.join('data', 'edeka', `${year}`, weekKey);
    ensureDirSync(outDir);
    
    const outFile = path.join(outDir, 'offers.json');
    saveJsonFile(outFile, {
      source: prospektUrl,
      fetched_at: new Date().toISOString(),
      weekKey,
      totalOffers: offers.length,
      offers,
    });
    
    // Normalisiere und speichere in SQLite
    const normalizedOffers = await upsertOffers('edeka', offers);
    
    return normalizedOffers;
  } catch (err) {
    console.error('[EDEKA] Fehler beim Crawlen:', err);
    return [];
  }
}

