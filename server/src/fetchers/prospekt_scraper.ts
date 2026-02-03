/**
 * Universal Prospekt Scraper
 * 
 * Verarbeitet alle Prospekt-Dateien in media/prospekte/ rekursiv.
 * Unterstützt: PDF, HTML, JSON, TXT
 * 
 * Features:
 * - Rekursive Ordner-Durchsuchung
 * - Automatische Format-Erkennung
 * - Robuste Fehlerbehandlung
 * - Metadaten-Tracking
 * - Klare Kennzeichnung verarbeiteter Dateien
 */

import { promises as fs } from 'node:fs';
import { join, dirname, extname, basename, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { extractOffersFromPdf } from '../utils/pdf_extractor.js';
import { parseKaufdaHtml } from '../utils/kaufda_html_parser.js';
import { getCurrentYearWeek } from '../utils/date_week.js';
import { ensureDirSync } from 'fs-extra';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROSPEKT_DIR = join(__dirname, '..', '..', 'media', 'prospekte');

export type ProcessedFile = {
  path: string;
  type: 'pdf' | 'html' | 'json' | 'txt' | 'unknown';
  success: boolean;
  offersCount: number;
  error?: string;
  processedAt: string;
};

export type ScraperResult = {
  retailer: string;
  region?: string;
  totalFiles: number;
  successfulFiles: number;
  failedFiles: number;
  totalOffers: number;
  files: ProcessedFile[];
  outputPath: string;
  processedAt: string;
};

/**
 * Liest eine JSON-Datei und extrahiert Angebote
 */
async function extractOffersFromJson(filePath: string): Promise<Array<{ name: string; price: number; price_old?: number; savings?: number }>> {
  const content = await fs.readFile(filePath, 'utf-8');
  const data = JSON.parse(content);
  
  // Unterstütze verschiedene JSON-Formate
  let offers: any[] = [];
  
  if (Array.isArray(data)) {
    offers = data;
  } else if (data.offers && Array.isArray(data.offers)) {
    offers = data.offers;
  } else if (data.raw && Array.isArray(data.raw)) {
    // Format: { "raw": [...] }
    offers = [data];
  }
  
  // Normalisiere Angebote
  return offers.map((offer: any) => {
    if (offer.raw && Array.isArray(offer.raw)) {
      // Parse raw format
      const raw = offer.raw;
      const name = raw[0] || '';
      let priceCurrent = null;
      let priceOld = null;
      
      for (let i = 1; i < raw.length; i++) {
        const text = raw[i];
        if (text && typeof text === 'string' && text.includes('€')) {
          const priceMatch = text.match(/(\d+),(\d+)\s*€/);
          if (priceMatch) {
            const price = parseFloat(priceMatch[1] + '.' + priceMatch[2]);
            if (priceCurrent === null) {
              priceCurrent = price;
            } else if (priceOld === null && price !== priceCurrent) {
              priceOld = price;
            }
          }
        }
      }
      
      if (priceOld !== null && priceOld < priceCurrent!) {
        [priceCurrent, priceOld] = [priceOld, priceCurrent];
      }
      
      const result: any = { name };
      if (priceCurrent !== null) result.price = priceCurrent;
      if (priceOld !== null) result.price_old = priceOld;
      if (priceOld !== null && priceCurrent !== null) {
        result.savings = parseFloat((priceOld - priceCurrent).toFixed(2));
      }
      
      return result;
    } else {
      // Standard format
      return {
        name: offer.name || offer.title || '',
        price: offer.price || offer.price_current || 0,
        price_old: offer.price_old || offer.originalPrice || undefined,
        savings: offer.savings || (offer.price_old && offer.price ? offer.price_old - offer.price : undefined),
      };
    }
  }).filter((offer: any) => offer.name && offer.price > 0);
}

/**
 * Liest eine TXT-Datei und extrahiert Angebote
 */
async function extractOffersFromTxt(filePath: string): Promise<Array<{ name: string; price: number; price_old?: number; savings?: number }>> {
  const content = await fs.readFile(filePath, 'utf-8');
  const lines = content.split('\n').filter(line => line.trim());
  
  const offers: Array<{ name: string; price: number; price_old?: number; savings?: number }> = [];
  let currentOffer: any = null;
  
  for (const line of lines) {
    // Suche nach Preisen (Format: X,XX €)
    const priceMatch = line.match(/(\d+),(\d+)\s*€/);
    if (priceMatch) {
      const price = parseFloat(priceMatch[1] + '.' + priceMatch[2]);
      
      if (currentOffer && currentOffer.price === null) {
        currentOffer.price = price;
      } else if (currentOffer && currentOffer.price !== null && !currentOffer.price_old) {
        currentOffer.price_old = price;
        if (currentOffer.price_old > currentOffer.price) {
          [currentOffer.price, currentOffer.price_old] = [currentOffer.price_old, currentOffer.price];
        }
        currentOffer.savings = parseFloat((currentOffer.price_old - currentOffer.price).toFixed(2));
      } else if (!currentOffer) {
        // Neues Angebot starten
        const nameMatch = line.match(/^(.+?)(?:\s+\d+,\d+\s*€)/);
        currentOffer = {
          name: nameMatch ? nameMatch[1].trim() : line.trim(),
          price,
          price_old: null,
        };
      }
    } else if (line.trim() && !line.match(/€/)) {
      // Produktname ohne Preis
      if (currentOffer && currentOffer.name) {
        offers.push(currentOffer);
      }
      currentOffer = { name: line.trim(), price: null };
    }
  }
  
  if (currentOffer && currentOffer.name) {
    offers.push(currentOffer);
  }
  
  return offers.filter(offer => offer.name && offer.price !== null && offer.price > 0);
}

/**
 * Verarbeitet eine einzelne Datei
 */
async function processFile(
  filePath: string,
  retailer: string,
  region?: string
): Promise<ProcessedFile> {
  const ext = extname(filePath).toLowerCase();
  const fileName = basename(filePath);
  const fileType = ext === '.pdf' ? 'pdf' : 
                   ext === '.html' || ext === '.htm' ? 'html' :
                   ext === '.json' ? 'json' :
                   ext === '.txt' ? 'txt' : 'unknown';
  
  console.log(`  📄 ${fileName} (${fileType})`);
  
  try {
    let offers: Array<{ name: string; price: number; price_old?: number; savings?: number; unit?: string; sourceRegion?: string }> = [];
    
    if (fileType === 'pdf') {
      const pdfBuffer = await fs.readFile(filePath);
      const regionName = region || basename(filePath, '.pdf');
      const extracted = await extractOffersFromPdf(pdfBuffer, regionName);
      offers = extracted.map(o => ({
        name: o.name,
        price: o.price,
        price_old: o.discount ? o.price + o.discount : undefined,
        savings: o.discount || undefined,
        unit: o.unit || undefined,
        sourceRegion: o.sourceRegion,
      }));
      
    } else if (fileType === 'html') {
      const { offers: htmlOffers } = await parseKaufdaHtml(filePath);
      offers = htmlOffers.map(o => ({
        name: o.name,
        price: o.price,
        price_old: undefined,
        savings: o.discount || undefined,
        unit: o.unit || undefined,
      }));
      
    } else if (fileType === 'json') {
      offers = await extractOffersFromJson(filePath);
      
    } else if (fileType === 'txt') {
      offers = await extractOffersFromTxt(filePath);
      
    } else {
      throw new Error(`Unbekannter Dateityp: ${ext}`);
    }
    
    return {
      path: filePath,
      type: fileType,
      success: true,
      offersCount: offers.length,
      processedAt: new Date().toISOString(),
    };
    
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    console.error(`    ❌ Fehler: ${error}`);
    
    return {
      path: filePath,
      type: fileType,
      success: false,
      offersCount: 0,
      error,
      processedAt: new Date().toISOString(),
    };
  }
}

/**
 * Verarbeitet einen Ordner rekursiv
 */
async function processDirectory(
  dirPath: string,
  retailer: string,
  region?: string,
  depth: number = 0
): Promise<ScraperResult> {
  const indent = '  '.repeat(depth);
  console.log(`${indent}📁 ${basename(dirPath)}${region ? ` (${region})` : ''}`);
  
  const files: ProcessedFile[] = [];
  const entries = await fs.readdir(dirPath, { withFileTypes: true });
  
  // Sortiere: zuerst Dateien, dann Ordner
  const fileEntries = entries.filter(e => e.isFile());
  const dirEntries = entries.filter(e => e.isDirectory());
  
  // Verarbeite Dateien
  for (const entry of fileEntries) {
    const filePath = join(dirPath, entry.name);
    const ext = extname(entry.name).toLowerCase();
    
    // Überspringe bereits verarbeitete JSON-Dateien (die mit _processed oder _final)
    if (ext === '.json' && (entry.name.includes('_processed') || entry.name.includes('_final'))) {
      console.log(`${indent}  ⏭️  ${entry.name} (bereits verarbeitet)`);
      continue;
    }
    
    // Überspringe _files Ordner-Inhalte
    if (entry.name.includes('_files') || entry.name === 'jsondateivoll') {
      continue;
    }
    
    // Unterstützte Formate
    if (['.pdf', '.html', '.htm', '.json', '.txt'].includes(ext)) {
      const result = await processFile(filePath, retailer, region);
      files.push(result);
    }
  }
  
  // Verarbeite Unterordner rekursiv
  for (const entry of dirEntries) {
    // Überspringe _files Ordner
    if (entry.name.includes('_files') || entry.name === 'jsondateivoll') {
      continue;
    }
    
    const subDirPath = join(dirPath, entry.name);
    const subRegion = region || entry.name;
    const subResult = await processDirectory(subDirPath, retailer, subRegion, depth + 1);
    
    // Füge Dateien hinzu
    files.push(...subResult.files);
  }
  
  // Sammle alle Angebote
  const allOffers: Array<{ name: string; price: number; price_old?: number; savings?: number; unit?: string; sourceRegion?: string }> = [];
  const processedFiles = new Set<string>();
  
  for (const file of files) {
    if (file.success && file.offersCount > 0) {
      try {
        const ext = extname(file.path).toLowerCase();
        
        if (ext === '.pdf') {
          const pdfBuffer = await fs.readFile(file.path);
          const regionName = region || basename(file.path, '.pdf');
          const extracted = await extractOffersFromPdf(pdfBuffer, regionName);
          extracted.forEach(o => {
            allOffers.push({
              name: o.name,
              price: o.price,
              price_old: o.discount ? o.price + o.discount : undefined,
              savings: o.discount || undefined,
              unit: o.unit || undefined,
              sourceRegion: o.sourceRegion,
            });
          });
          
        } else if (ext === '.html' || ext === '.htm') {
          // .htm wird als 'html' behandelt
          const { offers: htmlOffers } = await parseKaufdaHtml(file.path);
          htmlOffers.forEach(o => {
            allOffers.push({
              name: o.name,
              price: o.price,
              price_old: undefined,
              savings: o.discount || undefined,
              unit: o.unit || undefined,
            });
          });
          
        } else if (ext === '.json') {
          const jsonOffers = await extractOffersFromJson(file.path);
          jsonOffers.forEach(o => {
            allOffers.push({
              name: o.name,
              price: o.price,
              price_old: o.price_old,
              savings: o.savings,
            });
          });
          
        } else if (ext === '.txt') {
          const txtOffers = await extractOffersFromTxt(file.path);
          txtOffers.forEach(o => {
            allOffers.push({
              name: o.name,
              price: o.price,
              price_old: o.price_old,
              savings: o.savings,
            });
          });
        }
        
        processedFiles.add(file.path);
        
      } catch (err) {
        console.error(`    ⚠️  Fehler beim Lesen von ${file.path}:`, err);
      }
    }
  }
  
  // Dedupliziere Angebote (gleicher Name + ähnlicher Preis)
  const uniqueOffers = new Map<string, typeof allOffers[0]>();
  for (const offer of allOffers) {
    const key = `${offer.name.toLowerCase().trim()}_${Math.round(offer.price * 100)}`;
    if (!uniqueOffers.has(key)) {
      uniqueOffers.set(key, offer);
    }
  }
  
  const finalOffers = Array.from(uniqueOffers.values());
  
  // Erstelle Ausgabe-JSON
  const { year, week, weekKey } = getCurrentYearWeek();
  const outputFileName = region 
    ? `${retailer.toLowerCase()}_${region.toLowerCase().replace(/\s+/g, '_')}_processed_${weekKey}.json`
    : `${retailer.toLowerCase()}_processed_${weekKey}.json`;
  const outputPath = join(dirPath, outputFileName);
  
  const result: ScraperResult = {
    retailer,
    region,
    totalFiles: files.length,
    successfulFiles: files.filter(f => f.success).length,
    failedFiles: files.filter(f => !f.success).length,
    totalOffers: finalOffers.length,
    files: files,
    outputPath,
    processedAt: new Date().toISOString(),
  };
  
  // Speichere Ergebnis
  const outputData = {
    // Metadaten
    metadata: {
      retailer: retailer.toUpperCase(),
      region: region || 'N/A',
      weekKey,
      year,
      week,
      processedAt: result.processedAt,
      source: 'prospekt-scraper',
      version: '1.0.0',
      totalFilesProcessed: result.totalFiles,
      successfulFiles: result.successfulFiles,
      failedFiles: result.failedFiles,
    },
    // Verarbeitete Dateien
    processedFiles: files.map(f => ({
      path: relative(PROSPEKT_DIR, f.path),
      type: f.type,
      success: f.success,
      offersCount: f.offersCount,
      error: f.error,
      processedAt: f.processedAt,
    })),
    // Extrahierten Angebote
    offers: finalOffers,
  };
  
  await fs.writeFile(outputPath, JSON.stringify(outputData, null, 2) + '\n', 'utf-8');
  
  console.log(`${indent}✅ ${finalOffers.length} Angebote extrahiert, ${result.successfulFiles}/${result.totalFiles} Dateien erfolgreich`);
  console.log(`${indent}📋 Gespeichert: ${outputFileName}`);
  
  return result;
}

/**
 * Hauptfunktion: Verarbeitet alle Prospekt-Ordner
 */
export async function scrapeAllProspekte(): Promise<ScraperResult[]> {
  console.log('🚀 Universal Prospekt Scraper\n');
  console.log(`📂 Prospekt-Verzeichnis: ${PROSPEKT_DIR}\n`);
  
  const results: ScraperResult[] = [];
  const entries = await fs.readdir(PROSPEKT_DIR, { withFileTypes: true });
  
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    
    const retailerPath = join(PROSPEKT_DIR, entry.name);
    const retailer = entry.name.toUpperCase().replace(/[^A-Z]/g, '') || entry.name;
    
    console.log(`\n🏪 ${retailer}`);
    console.log('═'.repeat(50));
    
    try {
      const result = await processDirectory(retailerPath, retailer);
      results.push(result);
    } catch (err) {
      console.error(`❌ Fehler beim Verarbeiten von ${retailer}:`, err);
    }
  }
  
  // Zusammenfassung
  console.log('\n\n' + '═'.repeat(50));
  console.log('📊 ZUSAMMENFASSUNG');
  console.log('═'.repeat(50));
  
  const totalFiles = results.reduce((sum, r) => sum + r.totalFiles, 0);
  const totalSuccessful = results.reduce((sum, r) => sum + r.successfulFiles, 0);
  const totalFailed = results.reduce((sum, r) => sum + r.failedFiles, 0);
  const totalOffers = results.reduce((sum, r) => sum + r.totalOffers, 0);
  
  console.log(`\n📁 Verarbeitete Ordner: ${results.length}`);
  console.log(`📄 Gesamt Dateien: ${totalFiles}`);
  console.log(`✅ Erfolgreich: ${totalSuccessful}`);
  console.log(`❌ Fehlgeschlagen: ${totalFailed}`);
  console.log(`📦 Gesamt Angebote: ${totalOffers}`);
  
  console.log('\n📋 Ergebnisse:');
  results.forEach(r => {
    console.log(`  ${r.retailer}${r.region ? ` (${r.region})` : ''}: ${r.totalOffers} Angebote, ${r.successfulFiles}/${r.totalFiles} Dateien`);
  });
  
  return results;
}

