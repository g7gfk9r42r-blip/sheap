/**
 * EDEKA PDF Fetcher
 * 
 * Lädt öffentlich verfügbare EDEKA-Prospekte als PDF herunter
 * und extrahiert alle Angebote.
 * 
 * ⚠️ LEGAL: Nutzt nur öffentliche PDF-Download-Links, kein Scraping!
 */

import { promises as fs } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { EDEKA_REGIONS, type EdekaRegion, getRegionsWithPdfUrls } from '../constants/edeka_regions.js';
import { extractOffersFromPdf } from '../utils/pdf_extractor.js';
import { getCurrentYearWeek } from '../utils/date_week.js';
import { saveJsonFile } from '../utils/files.js';
import { ensureDirSync } from 'fs-extra';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 2000;
const DOWNLOAD_TIMEOUT_MS = 30000;

export type FetchResult = {
  region: string;
  success: boolean;
  offersCount: number;
  pdfPath?: string;
  jsonPath?: string;
  error?: string;
};

/**
 * Lädt eine PDF-Datei herunter (mit Retry)
 */
async function downloadPdf(url: string, maxRetries: number = MAX_RETRIES): Promise<Buffer> {
  let lastError: Error | null = null;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      console.log(`[EDEKA-PDF] Download-Versuch ${attempt + 1}/${maxRetries}: ${url}`);
      
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), DOWNLOAD_TIMEOUT_MS);
      
      const response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'application/pdf,application/octet-stream,*/*',
        },
      });
      
      clearTimeout(timeout);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const contentType = response.headers.get('content-type') || '';
      if (!contentType.includes('pdf') && !contentType.includes('octet-stream')) {
        console.warn(`[EDEKA-PDF] Unerwarteter Content-Type: ${contentType}`);
      }
      
      const buffer = Buffer.from(await response.arrayBuffer());
      
      if (buffer.length < 1000) {
        throw new Error(`PDF zu klein (${buffer.length} bytes) - möglicherweise Fehler-HTML`);
      }
      
      console.log(`[EDEKA-PDF] ✅ PDF erfolgreich heruntergeladen: ${buffer.length} bytes`);
      return buffer;
      
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      
      if (attempt < maxRetries - 1) {
        const waitTime = RETRY_DELAY_MS * (attempt + 1);
        console.log(`[EDEKA-PDF] ⚠️  Fehler, warte ${waitTime}ms vor Retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
  
  throw lastError || new Error('Download fehlgeschlagen nach allen Retries');
}

/**
 * Verarbeitet eine einzelne Region
 */
async function processRegion(region: EdekaRegion): Promise<FetchResult> {
  const { year, week, weekKey } = getCurrentYearWeek();
  
  console.log(`\n[EDEKA-PDF] Verarbeite Region: ${region.region}`);
  console.log(`[EDEKA-PDF] PDF-URL: ${region.pdfUrl}`);
  
  try {
    // Validiere URL
    if (!region.pdfUrl || !region.pdfUrl.startsWith('http')) {
      throw new Error('Ungültige PDF-URL');
    }
    
    // Lade PDF herunter
    const pdfBuffer = await downloadPdf(region.pdfUrl);
    
    // Erstelle Ausgabeverzeichnis
    const outputDir = join(__dirname, '..', '..', 'data', 'edeka', String(year), `W${week}`);
    ensureDirSync(outputDir);
    
    // Speichere PDF
    const pdfPath = join(outputDir, `${region.region}.pdf`);
    await fs.writeFile(pdfPath, pdfBuffer);
    console.log(`[EDEKA-PDF] ✅ PDF gespeichert: ${pdfPath}`);
    
    // Extrahiere Angebote
    const offers = await extractOffersFromPdf(pdfBuffer, region.region);
    
    // Speichere JSON
    const jsonPath = join(outputDir, `${region.region}.json`);
    saveJsonFile(jsonPath, {
      region: region.region,
      weekKey,
      year,
      week,
      totalOffers: offers.length,
      fetchedAt: new Date().toISOString(),
      source: 'kaufda-pdf',
      pdfUrl: region.pdfUrl,
      offers,
    });
    
    console.log(`[EDEKA-PDF] ✅ JSON gespeichert: ${jsonPath}`);
    console.log(`[EDEKA-PDF] ✅ ${offers.length} Angebote extrahiert`);
    
    return {
      region: region.region,
      success: true,
      offersCount: offers.length,
      pdfPath,
      jsonPath,
    };
    
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    console.error(`[EDEKA-PDF] ❌ Fehler bei Region ${region.region}:`, error);
    
    return {
      region: region.region,
      success: false,
      offersCount: 0,
      error,
    };
  }
}

/**
 * Haupt-Funktion: Lädt alle EDEKA-Prospekte herunter und extrahiert Angebote
 */
export async function fetchAllEdekaPdfs(): Promise<FetchResult[]> {
  console.log('\n🛒 EDEKA PDF Fetcher');
  console.log('='.repeat(50));
  
  const regionsWithUrls = getRegionsWithPdfUrls();
  
  if (regionsWithUrls.length === 0) {
    console.warn('[EDEKA-PDF] ⚠️  Keine Regionen mit gültigen PDF-URLs gefunden!');
    console.warn('[EDEKA-PDF] Bitte trage die PDF-URLs in src/constants/edeka_regions.ts ein.');
    return [];
  }
  
  console.log(`[EDEKA-PDF] ${regionsWithUrls.length} Regionen mit PDF-URLs gefunden\n`);
  
  const results: FetchResult[] = [];
  
  // Verarbeite alle Regionen
  for (const region of regionsWithUrls) {
    const result = await processRegion(region);
    results.push(result);
    
    // Kurze Pause zwischen Downloads (höfliches Crawling)
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  // Zusammenfassung
  console.log('\n' + '='.repeat(50));
  console.log('📊 Zusammenfassung:');
  const successful = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  const totalOffers = results.reduce((sum, r) => sum + r.offersCount, 0);
  
  console.log(`   ✅ Erfolgreich: ${successful.length}/${results.length}`);
  console.log(`   ❌ Fehlgeschlagen: ${failed.length}/${results.length}`);
  console.log(`   📦 Gesamt-Angebote: ${totalOffers}`);
  
  if (failed.length > 0) {
    console.log('\n   Fehlgeschlagene Regionen:');
    failed.forEach(r => {
      console.log(`     - ${r.region}: ${r.error}`);
    });
  }
  
  return results;
}

/**
 * Lädt Prospekte für eine spezifische Region
 */
export async function fetchEdekaPdfForRegion(regionName: string): Promise<FetchResult | null> {
  const region = EDEKA_REGIONS.find(r => r.region === regionName);
  
  if (!region) {
    console.error(`[EDEKA-PDF] Region nicht gefunden: ${regionName}`);
    return null;
  }
  
  if (!region.pdfUrl || !region.pdfUrl.startsWith('http')) {
    console.error(`[EDEKA-PDF] Keine gültige PDF-URL für Region: ${regionName}`);
    return null;
  }
  
  return await processRegion(region);
}

// CLI-Entry-Point
if (import.meta.url === `file://${process.argv[1]}` || process.argv[1]?.endsWith('edeka_pdf_fetcher.js')) {
  fetchAllEdekaPdfs().catch(err => {
    console.error('❌ Fehler:', err);
    process.exit(1);
  });
}
