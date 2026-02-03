#!/usr/bin/env node
// tools/leaflets/process_lidl_pdf.mjs
// Verarbeitet Lidl-PDFs aus media/prospekte/lidl/ und extrahiert ALLE Angebote

import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve, basename } from 'path';
import { chromium } from 'playwright';
import { PDFDocument } from 'pdf-lib';
import sharp from 'sharp';
import Tesseract from 'tesseract.js';
import dayjs from 'dayjs';
import customParseFormat from 'dayjs/plugin/customParseFormat.js';
import isoWeek from 'dayjs/plugin/isoWeek.js';

dayjs.extend(customParseFormat);
dayjs.extend(isoWeek);

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================================================
// Utility-Funktionen
// ============================================================================

function getYearWeek(date = new Date()) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  const year = d.getUTCFullYear();
  const week = String(weekNo).padStart(2, '0');
  return { year, week, weekKey: `${year}-W${week}` };
}

function parseValidityPeriod(text) {
  const now = dayjs();
  const currentYear = now.year();
  
  // Pattern: "24.11.2025 – 29.11.2025" oder "24.11. - 29.11.2025"
  const rangePattern = /(\d{1,2})\.\s*(\d{1,2})\.\s*(?:(\d{4})\s*)?[-–]\s*(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})?/;
  const rangeMatch = text.match(rangePattern);
  if (rangeMatch) {
    const day1 = parseInt(rangeMatch[1], 10);
    const month1 = parseInt(rangeMatch[2], 10) - 1;
    const year1 = rangeMatch[3] ? parseInt(rangeMatch[3], 10) : currentYear;
    const day2 = parseInt(rangeMatch[4], 10);
    const month2 = parseInt(rangeMatch[5], 10) - 1;
    const year2 = rangeMatch[6] ? parseInt(rangeMatch[6], 10) : (rangeMatch[3] ? parseInt(rangeMatch[3], 10) : currentYear);
    
    const validFrom = dayjs().year(year1).month(month1).date(day1);
    const validTo = dayjs().year(year2).month(month2).date(day2);
    return {
      validFrom: validFrom.format('YYYY-MM-DD'),
      validTo: validTo.format('YYYY-MM-DD')
    };
  }
  
  // Fallback: Aktuelle Woche
  const { weekKey } = getYearWeek();
  const weekStart = dayjs().isoWeek(parseInt(weekKey.split('-W')[1], 10)).startOf('isoWeek');
  return {
    validFrom: weekStart.format('YYYY-MM-DD'),
    validTo: weekStart.add(6, 'days').format('YYYY-MM-DD')
  };
}

function extractPrice(text) {
  const patterns = [
    /(\d+[.,]\d{1,2})\s*€/,
    /€\s*(\d+[.,]\d{1,2})/,
    /(\d+[.,]\d{2})\s*(?:EUR|Euro)/i,
  ];
  
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match) {
      const price = parseFloat(match[1].replace(',', '.'));
      if (price >= 0.01 && price <= 1000) {
        return price;
      }
    }
  }
  return null;
}

function extractUnit(text) {
  const unitPattern = /(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung|pck|pack)/i;
  const match = text.match(unitPattern);
  if (match) {
    return `${match[1]} ${match[2].toLowerCase()}`;
  }
  return null;
}

function extractBrand(text) {
  const brands = [
    'Milbona', 'Bellarom', 'Cien', 'Livarno', 'Parkside', 'Culinea', 'Favorina',
    'Vemondo', 'Next Level', 'Freeway', 'Mister Choc', 'Alesto', 'Rio Mare',
    'Frosta', 'Gut & Günstig', 'Ja!', 'Bella', 'Casa', 'Casa Moda', 'Comfort',
    'Crownfield', 'Deluxe', 'Finessa', 'Freshona', 'Garden Gourmet', 'Gourmet',
    'Hähnchen', 'Kania', 'Silvercrest', 'Wayne', 'lupilu', 'esmara', 'sensiplast',
    'f.a.n.', 'PARKSIDE', 'DELUXE'
  ];
  
  for (const brand of brands) {
    if (text.toLowerCase().includes(brand.toLowerCase())) {
      return brand;
    }
  }
  return null;
}

// ============================================================================
// PDF-Verarbeitung
// ============================================================================

/**
 * Findet die neueste Lidl-PDF
 */
async function findLatestPdf() {
  const pdfDir = resolve(__dirname, '../../media/prospekte/lidl');
  
  try {
    const files = await fs.readdir(pdfDir);
    const pdfFiles = files
      .filter(f => f.endsWith('.pdf') && f.startsWith('lidl_'))
      .map(f => ({
        name: f,
        path: join(pdfDir, f),
        mtime: null
      }));
    
    // Lese mtime für alle PDFs
    for (const pdf of pdfFiles) {
      try {
        const stats = await fs.stat(pdf.path);
        pdf.mtime = stats.mtime;
      } catch {}
    }
    
    // Sortiere nach mtime (neueste zuerst)
    pdfFiles.sort((a, b) => (b.mtime?.getTime() || 0) - (a.mtime?.getTime() || 0));
    
    if (pdfFiles.length === 0) {
      throw new Error(`Keine PDFs gefunden in ${pdfDir}`);
    }
    
    return pdfFiles[0].path;
  } catch (err) {
    throw new Error(`Fehler beim Suchen der PDF: ${err.message}`);
  }
}

/**
 * Konvertiert PDF-Seiten zu PNG-Bildern
 */
async function pdfToImages(pdfPath, outputDir) {
  console.log(`\n📸 Konvertiere PDF zu Bildern...`);
  
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  const fileUrl = `file://${pdfPath}`;
  await page.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(2000);
  
  // Lese PDF-Info
  const pdfBytes = await fs.readFile(pdfPath);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const pageCount = pdfDoc.getPageCount();
  
  console.log(`   ${pageCount} Seiten gefunden`);
  
  const imagePaths = [];
  
  for (let i = 0; i < pageCount; i++) {
    const imagePath = join(outputDir, `page_${String(i + 1).padStart(3, '0')}.png`);
    
    try {
      if (i > 0) {
        await page.goto(`${fileUrl}#page=${i + 1}`, { waitUntil: 'domcontentloaded', timeout: 30000 });
        await page.waitForTimeout(1500);
      }
      
      await page.screenshot({
        path: imagePath,
        fullPage: true,
        type: 'png'
      });
      
      imagePaths.push(imagePath);
      process.stdout.write(`\r   📄 Seite ${i + 1}/${pageCount} konvertiert`);
    } catch (err) {
      console.error(`\n⚠️  Fehler bei Seite ${i + 1}:`, err.message);
    }
  }
  
  await browser.close();
  console.log(`\n✅ ${imagePaths.length} Seiten als PNG gespeichert`);
  
  return imagePaths;
}

/**
 * Extrahiert Text aus Bild mit OCR
 */
async function extractTextFromImage(imagePath) {
  try {
    const { data: { text } } = await Tesseract.recognize(imagePath, 'deu', {
      logger: m => {
        // Silent mode
      }
    });
    return text;
  } catch (err) {
    console.error(`⚠️  OCR-Fehler für ${basename(imagePath)}:`, err.message);
    return '';
  }
}

/**
 * Parst Angebote aus OCR-Text
 */
function parseOffersFromText(text, pageNum, defaultPeriod) {
  const offers = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  // Finde alle Preise
  const pricePatterns = [
    /(\d+[.,]\d{1,2})\s*€/g,
    /€\s*(\d+[.,]\d{1,2})/g,
    /(\d+[.,]\d{2})\s*(?:EUR|Euro)/gi,
  ];
  
  const allPriceMatches = [];
  for (const pattern of pricePatterns) {
    const matches = Array.from(text.matchAll(pattern));
    for (const match of matches) {
      const price = parseFloat(match[1].replace(',', '.'));
      if (price >= 0.01 && price <= 1000) {
        allPriceMatches.push({
          price,
          index: match.index,
          fullMatch: match[0]
        });
      }
    }
  }
  
  // Sortiere nach Position
  allPriceMatches.sort((a, b) => a.index - b.index);
  
  // Dedupliziere
  const uniquePrices = [];
  for (const match of allPriceMatches) {
    const isDuplicate = uniquePrices.some(existing => 
      Math.abs(existing.index - match.index) < 100 && 
      Math.abs(existing.price - match.price) < 0.01
    );
    if (!isDuplicate) {
      uniquePrices.push(match);
    }
  }
  
  // Für jeden Preis: Finde zugehöriges Angebot
  for (const priceMatch of uniquePrices) {
    const priceIndex = priceMatch.index;
    
    // Kontext um den Preis
    const contextStart = Math.max(0, priceIndex - 500);
    const contextEnd = Math.min(text.length, priceIndex + 200);
    const context = text.substring(contextStart, contextEnd);
    const contextLines = context.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    
    let title = '';
    let brand = null;
    let unit = null;
    
    // Finde Titel in Zeilen VOR dem Preis
    for (let i = contextLines.length - 1; i >= 0; i--) {
      const line = contextLines[i];
      
      if (line.includes(priceMatch.fullMatch)) {
        continue; // Überspringe Preis-Zeile selbst
      }
      
      if (line.length < 2 || /^\d+$/.test(line)) continue;
      if (/^(LIDL|Prospekt|Seite|Gültig|ab|von|bis|€)/i.test(line)) continue;
      
      if (line.length >= 3 && line.length < 200) {
        if (!title) {
          title = line;
          brand = extractBrand(line) || brand;
        } else {
          title = `${line} ${title}`.substring(0, 200);
        }
        
        const extractedUnit = extractUnit(line);
        if (extractedUnit) unit = extractedUnit;
      }
    }
    
    // Nur wenn Titel gefunden
    if (title && title.length >= 3) {
      const offer = {
        id: `lidl-pdf-${pageNum}-${offers.length + 1}-${Date.now()}`,
        retailer: 'LIDL',
        title: title.trim(),
        price: priceMatch.price,
        unit: unit || null,
        validFrom: defaultPeriod.validFrom,
        validTo: defaultPeriod.validTo,
        imageUrl: null,
        updatedAt: new Date().toISOString(),
        weekKey: getYearWeek().weekKey,
        brand: brand,
        page: pageNum,
        source: 'pdf-ocr'
      };
      
      offers.push(offer);
    }
  }
  
  return offers;
}

// ============================================================================
// Hauptfunktion
// ============================================================================

async function main() {
  const args = process.argv.slice(2);
  const pdfPath = args[0] || await findLatestPdf();
  const force = args.includes('--force');
  
  console.log(`\n📋 Lidl PDF-Verarbeitung`);
  console.log(`   PDF: ${basename(pdfPath)}`);
  
  // Prüfe ob PDF existiert
  try {
    await fs.access(pdfPath);
  } catch {
    console.error(`❌ PDF nicht gefunden: ${pdfPath}`);
    process.exit(1);
  }
  
  // Extrahiere Woche aus PDF-Namen oder verwende aktuelle Woche
  const { year, week, weekKey } = getYearWeek();
  const outputDir = resolve(__dirname, '../../data/lidl', String(year), `W${week}`);
  const outputPath = join(outputDir, 'offers_pdf.json');
  
  await fs.mkdir(outputDir, { recursive: true });
  
  // Prüfe ob bereits verarbeitet
  if (!force) {
    try {
      const existing = await fs.readFile(outputPath, 'utf-8');
      const data = JSON.parse(existing);
      if (data.offers && data.offers.length > 0) {
        console.log(`\n⚠️  Bereits verarbeitet: ${data.offers.length} Angebote gefunden`);
        console.log(`   Verwende --force zum erneuten Verarbeiten`);
        return;
      }
    } catch {}
  }
  
  // Temp-Verzeichnis für Bilder
  const tempDir = join(dirname(pdfPath), '__ocr_temp');
  await fs.mkdir(tempDir, { recursive: true });
  
  try {
    // Schritt 1: PDF zu Bildern
    const imagePaths = await pdfToImages(pdfPath, tempDir);
    
    if (imagePaths.length === 0) {
      throw new Error('Keine Bilder konnten erstellt werden');
    }
    
    // Schritt 2: OCR auf allen Bildern
    console.log(`\n🔍 OCR-Verarbeitung...`);
    const allOffers = [];
    const validityText = ''; // Wird aus erster Seite extrahiert
    
    for (let i = 0; i < imagePaths.length; i++) {
      const imagePath = imagePaths[i];
      process.stdout.write(`\r   📄 Seite ${i + 1}/${imagePaths.length} wird verarbeitet...`);
      
      const text = await extractTextFromImage(imagePath);
      
      // Extrahiere Gültigkeitsdaten aus erster Seite
      let defaultPeriod = parseValidityPeriod('');
      if (i === 0 && text) {
        defaultPeriod = parseValidityPeriod(text);
      }
      
      const offers = parseOffersFromText(text, i + 1, defaultPeriod);
      allOffers.push(...offers);
    }
    
    console.log(`\n✅ ${allOffers.length} Angebote extrahiert`);
    
    // Schritt 3: Speichere JSON
    const result = {
      weekKey,
      year,
      week,
      totalOffers: allOffers.length,
      generatedAt: new Date().toISOString(),
      source: 'pdf-ocr',
      pdfPath: basename(pdfPath),
      offers: allOffers
    };
    
    await fs.writeFile(outputPath, JSON.stringify(result, null, 2), 'utf-8');
    console.log(`\n✅ JSON gespeichert: ${outputPath}`);
    
    // Cleanup
    console.log(`\n🧹 Lösche temporäre Dateien...`);
    for (const imagePath of imagePaths) {
      try {
        await fs.unlink(imagePath);
      } catch {}
    }
    try {
      await fs.rmdir(tempDir);
    } catch {}
    
    console.log(`\n📊 Zusammenfassung:`);
    console.log(`   Angebote: ${allOffers.length}`);
    console.log(`   Seiten: ${imagePaths.length}`);
    console.log(`   Mit Marke: ${allOffers.filter(o => o.brand).length}`);
    console.log(`   Mit Einheit: ${allOffers.filter(o => o.unit).length}`);
    
  } catch (err) {
    console.error(`\n❌ Fehler:`, err.message);
    process.exit(1);
  }
}

main().catch(console.error);

