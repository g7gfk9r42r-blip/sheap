/**
 * Local File Processor
 * 
 * Verarbeitet lokal gespeicherte Prospekt-Dateien (PDF oder HTML mit Assets).
 * 
 * ⚠️ WICHTIG: Nutzt nur lokal gespeicherte Dateien - 100% legal!
 * 
 * Workflow:
 * 1. Nutzer speichert Prospekt-Seite als "Webseite, vollständig" (mit allen Assets)
 * 2. Oder lädt PDF direkt herunter
 * 3. Dieses Script verarbeitet die lokalen Dateien
 */

import { promises as fs } from 'fs';
import { join, dirname, extname, basename } from 'path';
import { extractOffersFromPdf } from './pdf_extractor.js';
import { parseKaufdaHtml } from './kaufda_html_parser.js';
import { getCurrentYearWeek } from './date_week.js';
import { saveJsonFile } from './files.js';
import { ensureDirSync } from 'fs-extra';

export type ProcessResult = {
  success: boolean;
  offersCount: number;
  fileType: 'pdf' | 'html' | 'unknown';
  outputPath?: string;
  error?: string;
};

/**
 * Verarbeitet eine lokal gespeicherte Datei (PDF oder HTML)
 * 
 * @param filePath Pfad zur lokal gespeicherten Datei
 * @param retailer Retailer-Name (z.B. "EDEKA", "LIDL", "REWE")
 * @param region Optional: Region-Name (z.B. "Berlin")
 */
export async function processLocalFile(
  filePath: string,
  retailer: string,
  region?: string
): Promise<ProcessResult> {
  console.log(`\n[Local-Processor] Verarbeite Datei: ${filePath}`);
  console.log(`[Local-Processor] Retailer: ${retailer}, Region: ${region || 'N/A'}`);
  
  try {
    // Prüfe ob Datei existiert
    await fs.access(filePath);
    
    const ext = extname(filePath).toLowerCase();
    const { year, week, weekKey } = getCurrentYearWeek();
    
    // Erstelle Ausgabeverzeichnis
    const outputDir = join(dirname(filePath), '..', '..', 'data', retailer.toLowerCase(), String(year), `W${week}`);
    ensureDirSync(outputDir);
    
    let offers: Array<{ name: string; price: number; discount?: number | null; unit?: string | null; sourceRegion?: string; rawText?: string }> = [];
    let fileType: 'pdf' | 'html' | 'unknown' = 'unknown';
    
    if (ext === '.pdf') {
      // PDF verarbeiten
      fileType = 'pdf';
      console.log('[Local-Processor] Erkenne PDF-Datei');
      
      const pdfBuffer = await fs.readFile(filePath);
      const regionName = region || basename(filePath, '.pdf');
      
      offers = await extractOffersFromPdf(pdfBuffer, regionName);
      
    } else if (ext === '.html' || ext === '.htm') {
      // HTML verarbeiten
      fileType = 'html';
      console.log('[Local-Processor] Erkenne HTML-Datei');
      
      const { offers: htmlOffers, pdfLinks } = await parseKaufdaHtml(filePath);
      
      // Nutze direkt extrahierte Angebote
      offers = htmlOffers;
      
      // Falls PDF-Links gefunden wurden, zeige sie an
      if (pdfLinks.length > 0) {
        console.log(`\n[Local-Processor] 💡 ${pdfLinks.length} PDF-Links in HTML gefunden:`);
        pdfLinks.forEach((link, i) => {
          console.log(`   ${i + 1}. ${link.url}`);
        });
        console.log('\n[Local-Processor] 💡 Tipp: Lade die PDFs herunter für bessere Extraktion!');
      }
      
    } else {
      throw new Error(`Unbekannter Dateityp: ${ext}. Unterstützt: .pdf, .html, .htm`);
    }
    
    if (offers.length === 0) {
      console.warn('[Local-Processor] ⚠️  Keine Angebote gefunden');
      return {
        success: false,
        offersCount: 0,
        fileType,
        error: 'Keine Angebote gefunden',
      };
    }
    
    // Speichere JSON
    const fileName = basename(filePath, ext);
    const jsonPath = join(outputDir, `${fileName}.json`);
    
    saveJsonFile(jsonPath, {
      retailer: retailer.toUpperCase(),
      region: region || fileName,
      weekKey,
      year,
      week,
      totalOffers: offers.length,
      processedAt: new Date().toISOString(),
      source: 'local-file',
      fileType,
      sourceFile: basename(filePath),
      offers,
    });
    
    console.log(`[Local-Processor] ✅ ${offers.length} Angebote extrahiert`);
    console.log(`[Local-Processor] ✅ JSON gespeichert: ${jsonPath}`);
    
    return {
      success: true,
      offersCount: offers.length,
      fileType,
      outputPath: jsonPath,
    };
    
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    console.error(`[Local-Processor] ❌ Fehler:`, error);
    
    return {
      success: false,
      offersCount: 0,
      fileType: 'unknown',
      error,
    };
  }
}

/**
 * Verarbeitet alle Dateien in einem Verzeichnis
 */
export async function processDirectory(
  dirPath: string,
  retailer: string
): Promise<ProcessResult[]> {
  console.log(`\n[Local-Processor] Verarbeite Verzeichnis: ${dirPath}`);
  
  const files = await fs.readdir(dirPath);
  const results: ProcessResult[] = [];
  
  for (const file of files) {
    const filePath = join(dirPath, file);
    const stat = await fs.stat(filePath);
    
    if (stat.isFile() && (file.endsWith('.pdf') || file.endsWith('.html') || file.endsWith('.htm'))) {
      const region = file.replace(/\.(pdf|html|htm)$/i, '');
      const result = await processLocalFile(filePath, retailer, region);
      results.push(result);
    }
  }
  
  return results;
}

