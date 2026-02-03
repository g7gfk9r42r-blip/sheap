import type { Offer } from '../types.js';
import { fetchEdekaOffersPlaywright } from './fetcher_edeka_playwright.js';
// Fallback: import { fetchEdekaOffersProspektangebote } from './fetcher_edeka_prospektangebote.js';

/**
 * Haupt-Fetcher für EDEKA-Angebote
 * 
 * EDEKA ist regional strukturiert (7 Regionalgesellschaften).
 * Wir scrapen direkt von edeka.de/angebote/superknueller für die wichtigsten Angebote.
 * 
 * Fallback: Prospektangebote.de (falls direkter Scraper fehlschlägt)
 */
export async function fetchOffers(weekKey?: string): Promise<Offer[]> {
  try {
    console.log('[EDEKA] Scrape direkt von edeka.de (SUPERKNÜLLER)');
    return await fetchEdekaOffersPlaywright(weekKey);
  } catch (err) {
    console.error('[EDEKA] Direkter Scraper fehlgeschlagen:', err);
    // Fallback: Prospektangebote.de (optional)
    // console.log('[EDEKA] Fallback: Prospektangebote.de');
    // return await fetchEdekaOffersProspektangebote();
    return [];
  }
}

