import { crawlMarkdown } from '../services/crawl4ai.js';
import { upsertOffers, type ProspektOffer } from '../db/offers.js';
import { saveJsonFile } from '../utils/files.js';
import { ensureDirSync } from 'fs-extra';
import path from 'path';
import { getYearWeek } from '../utils/date.js';
import type { Offer } from '../types.js';

/**
 * PROSPEKTANGEBOTE.DE – Lidl Fetcher
 * Works reliably, avoids Lidl internal CDN blocking.
 */

const SOURCE_URL =
  'https://www.prospektangebote.de/anzeigen/angebote/lidl-prospekt';

export async function fetchProspektangeboteLidlOffers(): Promise<Offer[]> {
  const { year, week, weekKey } = getYearWeek();
  const url = SOURCE_URL;

  console.log(`[Lidl-PA] Crawling: ${url}`);

  const crawl = await crawlMarkdown(url, {
    wait_until: 'domcontentloaded',
    simulate_user: true,
    scroll_page: true,
    magic: true,
  });

  if (!crawl || !crawl.markdown) {
    console.error('[Lidl-PA] No markdown extracted');
    return [];
  }

  const md = crawl.markdown.raw_markdown || '';
  console.log(`[Lidl-PA] Extracted MD length: ${md.length}`);

  const offers = extractOffersFromMarkdown(md);
  console.log(`[Lidl-PA] Found ${offers.length} offers`);

  const outDir = path.join('data', 'lidl', `${year}`, weekKey);
  ensureDirSync(outDir);

  const outFile = path.join(outDir, 'offers.json');
  saveJsonFile(outFile, {
    source: url,
    fetched_at: new Date().toISOString(),
    offers,
  });

  const normalizedOffers = await upsertOffers('lidl', offers);

  return normalizedOffers;
}

/**
 * Extract Lidl offers from markdown text
 */
function extractOffersFromMarkdown(md: string): ProspektOffer[] {
  const lines = md.split('\n');

  const offers: ProspektOffer[] = [];

  for (let line of lines) {
    line = line.trim();
    if (!line) continue;

    // Examples:
    // - "Occen Sea Lachsfilet 5 Stück XXL -31% 10.99€"
    // - "Milbona Mini Mozzarella 60% gratis"

    const priceMatch = line.match(/(\d+[.,]\d{2})\s*€?/);
    const percentMatch = line.match(/-?\d{1,3}%/);

    if (priceMatch) {
      const price = parseFloat(priceMatch[1].replace(',', '.'));
      const title = line.replace(priceMatch[0], '').trim();

      offers.push({
        title,
        price,
        discount: percentMatch ? percentMatch[0] : null,
        raw: line,
      });
    }
  }

  return offers;
}
