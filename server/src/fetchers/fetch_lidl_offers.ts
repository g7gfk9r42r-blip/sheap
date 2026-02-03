/**
 * Lidl Offer Extractor
 * 
 * Extrahiert Angebote aus Lidl-Prospekten durch:
 * 1. Crawl4AI-Aufruf auf Prospektseite
 * 2. Bild-Extraktion (media.images, HTML, Markdown)
 * 3. GPT-Analyse jedes Bildes
 * 4. Speicherung in JSON und SQLite
 */

import { crawlSinglePage } from '../services/crawl4ai.js';
import { extractLidlOfferFromImage } from '../ai/openai.js';
import { upsertOffers } from '../sqlite.js';
import type { Offer, Retailer } from '../types.js';
import { promises as fs } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface LidlOffer {
  title: string;
  price: number;
  unit?: string;
  discount?: string;
  image: string;
}

const LIDL_LEAFLET_URL = 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
const BATCH_SIZE = 5; // GPT-Aufrufe in Batches
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

/**
 * Extrahiert alle Prospektbilder aus der Crawl4AI-Antwort
 */
function extractLeafletImages(result: any, markdownContent?: string | null): string[] {
  const images = new Set<string>();

  // Filter-Funktion für Lidl-Prospektbilder
  const isLidlImage = (url: string): boolean => {
    if (!url || typeof url !== 'string') return false;
    return (url.startsWith('https://lidl.leaflets.schwarz/') || 
            url.startsWith('https://imgproxy.leaflets.schwarz/')) &&
           !url.includes('.svg') &&
           !url.includes('/assets/');
  };

  // 1. Extrahiere aus media.images
  if (result.media?.images && Array.isArray(result.media.images)) {
    result.media.images.forEach((img: any) => {
      if (typeof img === 'string' && isLidlImage(img)) {
        images.add(img);
      } else if (img?.url && isLidlImage(img.url)) {
        images.add(img.url);
      } else if (img?.src && isLidlImage(img.src)) {
        images.add(img.src);
      }
    });
  }

  // 2. Extrahiere aus cleaned_html per Regex
  const cleanedHtml = result.cleaned_html || '';
  if (cleanedHtml) {
    // Suche nach <img src="..."> Tags
    const imgRegex = /<img[^>]+src=["']([^"']+)["'][^>]*>/gi;
    let match;
    while ((match = imgRegex.exec(cleanedHtml)) !== null) {
      const imgUrl = match[1];
      if (isLidlImage(imgUrl)) {
        images.add(imgUrl);
      }
    }

    // Suche auch nach data-src
    const dataSrcRegex = /<img[^>]+data-src=["']([^"']+)["'][^>]*>/gi;
    while ((match = dataSrcRegex.exec(cleanedHtml)) !== null) {
      const imgUrl = match[1];
      if (isLidlImage(imgUrl)) {
        images.add(imgUrl);
      }
    }

    // Suche nach absoluten URLs im HTML
    const urlRegex = /https:\/\/(?:lidl|imgproxy)\.leaflets\.schwarz\/[^\s"'<>)]+/gi;
    let urlMatch;
    while ((urlMatch = urlRegex.exec(cleanedHtml)) !== null) {
      const url = urlMatch[0];
      if (isLidlImage(url)) {
        images.add(url);
      }
    }
  }

  // 3. Extrahiere auch aus Markdown
  const markdown = markdownContent || result.markdown?.raw_markdown || '';
  if (markdown) {
    const markdownUrlRegex = /https:\/\/(?:lidl|imgproxy)\.leaflets\.schwarz\/[^\s"'<>)]+/gi;
    let mdMatch;
    while ((mdMatch = markdownUrlRegex.exec(markdown)) !== null) {
      const url = mdMatch[0];
      if (isLidlImage(url)) {
        images.add(url);
      }
    }
  }

  return Array.from(images).sort();
}

/**
 * Retry-Logik für API-Aufrufe
 */
async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = MAX_RETRIES,
  delayMs: number = RETRY_DELAY_MS
): Promise<T> {
  let lastError: Error | null = null;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      const status = (error as any)?.status || (error as any)?.response?.status;
      
      // Retry nur bei 429 (Rate Limit) oder 500 (Server Error)
      if (status === 429 || status === 500) {
        if (attempt < maxRetries) {
          const waitTime = delayMs * attempt; // Exponential backoff
          console.warn(`[Lidl Fetcher] Retry ${attempt}/${maxRetries} nach ${waitTime}ms (Status: ${status})`);
          await new Promise(resolve => setTimeout(resolve, waitTime));
          continue;
        }
      }
      
      // Bei anderen Fehlern sofort werfen
      throw lastError;
    }
  }
  
  throw lastError || new Error('Max retries exceeded');
}

/**
 * Verarbeitet Bilder in Batches mit GPT
 */
async function processImagesInBatches(
  imageUrls: string[],
  batchSize: number = BATCH_SIZE
): Promise<LidlOffer[]> {
  const offers: LidlOffer[] = [];
  
  for (let i = 0; i < imageUrls.length; i += batchSize) {
    const batch = imageUrls.slice(i, i + batchSize);
    console.log(`[Lidl Fetcher] Verarbeite Batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(imageUrls.length / batchSize)} (${batch.length} Bilder)`);
    
    const batchPromises = batch.map(async (imageUrl) => {
      try {
        const offer = await withRetry(() => extractLidlOfferFromImage(imageUrl));
        if (offer) {
          return offer;
        }
        return null;
      } catch (error) {
        console.warn(`[Lidl Fetcher] Fehler bei Bild ${imageUrl}:`, error instanceof Error ? error.message : String(error));
        return null;
      }
    });
    
    const batchResults = await Promise.all(batchPromises);
    const validOffers = batchResults.filter((offer): offer is LidlOffer => offer !== null);
    offers.push(...validOffers);
    
    // Kurze Pause zwischen Batches
    if (i + batchSize < imageUrls.length) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }
  
  return offers;
}

/**
 * Generiert ISO-Woche-Key (z.B. "2025-W48")
 */
function getWeekKey(): string {
  const now = new Date();
  const year = now.getFullYear();
  
  // Einfache ISO-Woche-Berechnung
  const startOfYear = new Date(year, 0, 1);
  const days = Math.floor((now.getTime() - startOfYear.getTime()) / (24 * 60 * 60 * 1000));
  const week = Math.ceil((days + startOfYear.getDay() + 1) / 7);
  
  return `${year}-W${week.toString().padStart(2, '0')}`;
}

/**
 * Speichert Offers in JSON-Datei
 */
async function saveOffersToJson(
  offers: LidlOffer[],
  weekKey: string
): Promise<void> {
  const dataDir = join(__dirname, '..', '..', 'data', 'offers', 'lidl');
  const year = weekKey.split('-')[0];
  const week = weekKey.split('-W')[1];
  const outputDir = join(dataDir, year, week);
  const outputFile = join(outputDir, 'offers.json');
  
  // Ordner erstellen
  await fs.mkdir(outputDir, { recursive: true });
  
  const data = {
    generated_at: new Date().toISOString(),
    market: 'lidl',
    count: offers.length,
    offers: offers
  };
  
  await fs.writeFile(outputFile, JSON.stringify(data, null, 2), 'utf-8');
  console.log(`[Lidl Fetcher] ${offers.length} Offers gespeichert in ${outputFile}`);
}

/**
 * Konvertiert LidlOffer zu Offer (für SQLite)
 */
function convertToOffer(lidlOffer: LidlOffer, weekKey: string, index: number): Offer {
  const now = new Date();
  const validFrom = now.toISOString();
  const validTo = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000).toISOString(); // +7 Tage
  
  // Generiere ID aus Titel, Preis und Index
  const idBase = `${lidlOffer.title}-${lidlOffer.price}-${index}`.toLowerCase()
    .replace(/[^a-z0-9-]/g, '-')
    .substring(0, 50);
  const id = `lidl-${weekKey}-${idBase}`;
  
  return {
    id,
    retailer: 'LIDL' as Retailer,
    title: lidlOffer.title,
    price: lidlOffer.price,
    unit: lidlOffer.unit || '',
    validFrom,
    validTo,
    imageUrl: lidlOffer.image,
    updatedAt: now.toISOString(),
    weekKey,
    discountPercent: typeof lidlOffer.discount === 'string' ? parseFloat(lidlOffer.discount.replace(/[^\d.-]/g, '')) || null : null,
    metadata: {
      discount: lidlOffer.discount,
    }
  };
}

/**
 * Hauptfunktion: Extrahiert Lidl-Angebote
 */
export async function fetchLidlOffers(weekKey?: string): Promise<Offer[]> {
  const targetWeekKey = weekKey || getWeekKey();
  
  console.log(`[Lidl Fetcher] Starte Extraktion für Woche ${targetWeekKey}...`);
  
  const crawlerConfig = {
    type: 'CrawlerRunConfig',
    params: {
      scan_full_page: false,
      wait_until: 'load',
      simulate_user: false,
      magic: true,
      page_timeout: 60_000,
    },
  };

  try {
    // 1. Crawl4AI-Aufruf
    console.log(`[Lidl Fetcher] Crawle Prospektseite: ${LIDL_LEAFLET_URL}`);
    const crawlResult = await withRetry(async () => {
      return await crawlSinglePage(LIDL_LEAFLET_URL, {
        timeoutMs: 120_000,
        crawlerConfig,
      });
    });
    
    // Crawl4AI gibt { items, markdown, html, raw } zurück
    // raw enthält die vollständige Antwort mit results[0]
    const firstResult =
      crawlResult.raw?.firstResult ||
      crawlResult.raw?.results?.[0] ||
      crawlResult.raw ||
      {};
    
    const combinedResult = {
      cleaned_html: firstResult.cleaned_html || '',
      media: {
        images:
          firstResult.media?.images ||
          crawlResult.raw?.media?.images ||
          [],
      },
      markdown:
        typeof firstResult.markdown === 'string'
          ? { raw_markdown: firstResult.markdown }
          : firstResult.markdown ||
            (crawlResult.markdown ? { raw_markdown: crawlResult.markdown } : null),
      links: firstResult.links || crawlResult.raw?.links || [],
    };
    
    // 2. Bild-Extraktion
    console.log(`[Lidl Fetcher] Extrahiere Bilder...`);
    const imageUrls = extractLeafletImages(
      combinedResult,
      typeof combinedResult.markdown === 'string'
        ? combinedResult.markdown
        : combinedResult.markdown?.raw_markdown ?? null
    );
    console.log(`[Lidl Fetcher] ${imageUrls.length} Prospektbilder gefunden`);
    
    if (imageUrls.length === 0) {
      console.warn(`[Lidl Fetcher] Keine Bilder gefunden, beende Extraktion`);
      if (process.env.DEBUG) {
        console.warn(
          '[Lidl Fetcher][DEBUG] media.images length:',
          Array.isArray(combinedResult.media?.images) ? combinedResult.media.images.length : 'n/a',
        );
        console.warn(
          '[Lidl Fetcher][DEBUG] cleaned_html length:',
          combinedResult.cleaned_html ? combinedResult.cleaned_html.length : 0,
        );
        const markdownLength =
          typeof combinedResult.markdown === 'string'
            ? combinedResult.markdown.length
            : combinedResult.markdown?.raw_markdown?.length ?? 0;
        console.warn('[Lidl Fetcher][DEBUG] markdown length:', markdownLength);
        console.warn(
          '[Lidl Fetcher][DEBUG] links length:',
          Array.isArray(combinedResult.links) ? combinedResult.links.length : 0,
        );
      }
      return [];
    }
    
    // 3. GPT-Analyse in Batches
    console.log(`[Lidl Fetcher] Starte GPT-Analyse von ${imageUrls.length} Bildern...`);
    const lidlOffers = await processImagesInBatches(imageUrls);
    console.log(`[Lidl Fetcher] ${lidlOffers.length} Angebote erfolgreich extrahiert`);
    
    if (lidlOffers.length === 0) {
      console.warn(`[Lidl Fetcher] Keine Angebote aus Bildern extrahiert`);
      return [];
    }
    
    // 4. Konvertiere zu Offer-Format
    const offers = lidlOffers.map((lidOffer, index) => 
      convertToOffer(lidOffer, targetWeekKey, index)
    );
    
    // 5. Speichere in JSON
    await saveOffersToJson(lidlOffers, targetWeekKey);
    
    // 6. Speichere in SQLite
    upsertOffers('LIDL', targetWeekKey, offers);
    console.log(`[Lidl Fetcher] ${offers.length} Offers in SQLite gespeichert`);
    
    return offers;
    
  } catch (error) {
    console.error(`[Lidl Fetcher] Fehler bei der Extraktion:`, error instanceof Error ? error.message : String(error));
    if (process.env.DEBUG) {
      console.error(error);
    }
    throw error;
  }
}

