import type { Offer } from '../types.js';
import { fetchLidlOffersPlaywright } from './fetcher_lidl_playwright.js';
// Fallback: import { fetchProspektangeboteLidlOffers } from './fetcher_prospektangebote_lidl.js';

/**
 * Haupt-Fetcher für Lidl-Offers
 * 
 * Verwendet Playwright-basierte Extraktion (robust und zuverlässig):
 * 1. Nutzt fetch_lidl_leaflet.mjs für Network-Interception & DOM-Scraping
 * 2. Liest generierte JSON-Dateien
 * 3. Speichert in SQLite
 * 
 * Fallback zu Prospektangebote.de wenn Playwright fehlschlägt
 */
export async function fetchOffers(weekKey?: string): Promise<Offer[]> {
  try {
    console.log('[Lidl] Verwende Playwright-basierte Extraktion (robust)');
    return await fetchLidlOffersPlaywright(weekKey);
  } catch (err) {
    console.error('[Lidl] Playwright-Extraktion fehlgeschlagen:', err instanceof Error ? err.message : String(err));
    
    // Fallback: Prospektangebote.de (falls gewünscht)
    // try {
    //   console.log('[Lidl] Fallback: Prospektangebote.de');
    //   return await fetchProspektangeboteLidlOffers();
    // } catch (fallbackErr) {
    //   console.error('[Lidl] Fallback fehlgeschlagen:', fallbackErr);
    // }
    
    return [];
  }
}
