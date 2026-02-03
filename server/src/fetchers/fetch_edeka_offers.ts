/**
 * EDEKA Offers Fetcher (Official API)
 * 
 * Lädt Angebote direkt von der offiziellen EDEKA-API für einen spezifischen Markt.
 */

import { fetchMarketOffers } from '../services/edeka_api.js';
import { normalizeEdekaOffer } from '../db/offer_normalizer_edeka.js';
import { getCurrentYearWeek } from '../utils/date_week.js';
import { upsertOffers } from '../sqlite.js';
import { saveJsonFile } from '../utils/files.js';
import { ensureDirSync } from 'fs-extra';
import path from 'path';
import type { Offer } from '../types.js';

/**
 * Lädt alle Angebote für einen EDEKA-Markt und speichert sie
 * 
 * @param marketId EDEKA-Markt-ID
 * @returns Liste von normalisierten Offers
 */
export async function fetchEdekaOffersForMarket(marketId: string): Promise<Offer[]> {
  console.log(`[EDEKA] Fetching offers for market ${marketId}...`);
  
  const { year, week, weekKey } = getCurrentYearWeek();
  
  try {
    // Lade Angebote von der API
    const edekaOffers = await fetchMarketOffers(marketId);
    
    if (edekaOffers.length === 0) {
      console.log(`[EDEKA] Keine Angebote gefunden für Markt ${marketId}`);
      return [];
    }
    
    console.log(`[EDEKA] ${edekaOffers.length} Angebote von API erhalten`);
    
    // Normalisiere alle Offers
    const normalizedOffers: Offer[] = edekaOffers.map(offer =>
      normalizeEdekaOffer(offer, marketId, year, week)
    );
    
    // Speichere JSON-Datei
    const outputDir = path.join('data', 'edeka', String(year), `W${week}`);
    ensureDirSync(outputDir);
    
    const outputPath = path.join(outputDir, `${marketId}_offers.json`);
    saveJsonFile(outputPath, {
      marketId,
      weekKey,
      year,
      week,
      totalOffers: normalizedOffers.length,
      fetchedAt: new Date().toISOString(),
      source: 'edeka-api',
      offers: normalizedOffers,
    });
    
    console.log(`[EDEKA] JSON gespeichert: ${outputPath}`);
    
    // Speichere in SQLite
    upsertOffers('EDEKA', weekKey, normalizedOffers);
    
    console.log(`[EDEKA] ✅ ${normalizedOffers.length} Angebote für Markt ${marketId} gespeichert`);
    
    return normalizedOffers;
  } catch (err) {
    console.error(`[EDEKA] Fehler beim Laden von Angeboten für Markt ${marketId}:`, err);
    throw err;
  }
}

