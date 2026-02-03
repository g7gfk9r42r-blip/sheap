import type { Offer } from '../types.js';
import { fetchReweOffersPlaywright } from './fetcher_rewe_playwright.js';

/**
 * Haupt-Fetcher für REWE-Offers
 * 
 * Verwendet Playwright-basierte Extraktion (robust und zuverlässig):
 * 1. Nutzt fetch_rewe_offers.mjs für Network-Interception & DOM-Scraping
 * 2. Liest generierte JSON-Dateien
 * 3. Speichert in SQLite
 */
export async function fetchOffers(weekKey?: string): Promise<Offer[]> {
  try {
    console.log('[REWE] Verwende Playwright-basierte Extraktion (robust)');
    return await fetchReweOffersPlaywright(weekKey);
  } catch (err) {
    console.error('[REWE] Playwright-Extraktion fehlgeschlagen:', err instanceof Error ? err.message : String(err));
    return [];
  }
}

