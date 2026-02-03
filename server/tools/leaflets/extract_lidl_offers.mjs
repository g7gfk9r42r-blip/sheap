#!/usr/bin/env node
// tools/leaflets/extract_lidl_offers.mjs
// Extrahiert ALLE Angebote aus Lidl-PDF(s) mit OCR und erstellt strukturiertes JSON

import { PDFDocument } from 'pdf-lib';
import { chromium } from 'playwright';
import sharp from 'sharp';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve, basename } from 'path';
import dayjs from 'dayjs';
import customParseFormat from 'dayjs/plugin/customParseFormat.js';
import isoWeek from 'dayjs/plugin/isoWeek.js';

dayjs.extend(customParseFormat);
dayjs.extend(isoWeek);

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Parse CLI-Argumente
const args = process.argv.slice(2);
const pdfPathOrDir = args[0] || resolve(__dirname, '../../media/prospekte/lidl/2025/W47/leaflet.pdf');
const outJson = args[1] || resolve(__dirname, '../../data/lidl/2025/W47/offers.json');
const shouldEnrichNutrition = args.includes('--enrich-nutrition');

/**
 * Berechnet ISO-Kalenderwoche
 */
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

/**
 * Parst Gültigkeitsdaten aus Text
 */
function parseValidityPeriod(text) {
  const now = dayjs();
  const currentYear = now.year();
  
  // Pattern 1: "ab Donnerstag 20. November"
  const abPattern = /ab\s+(?:Donnerstag|Freitag|Samstag|Sonntag|Montag|Dienstag|Mittwoch)?\s*(\d{1,2})\.\s*(\w+)/i;
  const abMatch = text.match(abPattern);
  if (abMatch) {
    const day = parseInt(abMatch[1], 10);
    const monthName = abMatch[2];
    const monthMap = {
      'januar': 0, 'jan': 0, 'februar': 1, 'feb': 1, 'märz': 2, 'mär': 2, 'marz': 2, 'mar': 2,
      'april': 3, 'apr': 3, 'mai': 4, 'may': 4, 'juni': 5, 'jun': 5, 'juli': 6, 'jul': 6,
      'august': 7, 'aug': 7, 'september': 8, 'sep': 8, 'oktober': 9, 'okt': 9, 'oct': 9,
      'november': 10, 'nov': 10, 'dezember': 11, 'dez': 11, 'dec': 11
    };
    const month = monthMap[monthName.toLowerCase()];
    if (month !== undefined) {
      const validFrom = dayjs().year(currentYear).month(month).date(day);
      const validTo = validFrom.add(6, 'days');
      return {
        validFrom: validFrom.toISOString(),
        validTo: validTo.toISOString()
      };
    }
  }
  
  // Pattern 2: "17.11. - 23.11.2025"
  const rangePattern = /(\d{1,2})\.\s*(\d{1,2})\.\s*[-–]\s*(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})?/;
  const rangeMatch = text.match(rangePattern);
  if (rangeMatch) {
    const day1 = parseInt(rangeMatch[1], 10);
    const month1 = parseInt(rangeMatch[2], 10) - 1;
    const day2 = parseInt(rangeMatch[3], 10);
    const month2 = parseInt(rangeMatch[4], 10) - 1;
    const year = rangeMatch[5] ? parseInt(rangeMatch[5], 10) : currentYear;
    
    const validFrom = dayjs().year(year).month(month1).date(day1);
    const validTo = dayjs().year(year).month(month2).date(day2);
    return {
      validFrom: validFrom.toISOString(),
      validTo: validTo.toISOString()
    };
  }
  
  // Pattern 3: "gültig ab 20.11."
  const simplePattern = /(?:gültig\s+)?ab\s+(\d{1,2})\.\s*(\d{1,2})\./i;
  const simpleMatch = text.match(simplePattern);
  if (simpleMatch) {
    const day = parseInt(simpleMatch[1], 10);
    const month = parseInt(simpleMatch[2], 10) - 1;
    const validFrom = dayjs().year(currentYear).month(month).date(day);
    const validTo = validFrom.add(6, 'days');
    return {
      validFrom: validFrom.toISOString(),
      validTo: validTo.toISOString()
    };
  }
  
  // Fallback: Aktuelle Woche
  const { weekKey } = getYearWeek();
  const weekStart = dayjs().isoWeek(parseInt(weekKey.split('-W')[1], 10)).startOf('isoWeek');
  return {
    validFrom: weekStart.toISOString(),
    validTo: weekStart.add(6, 'days').toISOString()
  };
}

function extractPrice(text) {
  const pricePattern = /(\d+[.,]\d{1,2})\s*€/;
  const match = text.match(pricePattern);
  if (match) {
    return parseFloat(match[1].replace(',', '.'));
  }
  return null;
}

function extractUnit(text) {
  const unitPattern = /(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung|pck)/i;
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
    'Frosta', 'Gut & Günstig', 'Ja!', 'Rewe Beste Wahl', 'Rewe Bio', 'Edeka Bio',
    'Edeka', 'Rewe', 'Lidl', 'Aldi', 'Netto', 'Penny', 'Kaufland', 'Bella',
    'Bellarom', 'Casa', 'Casa Moda', 'Comfort', 'Crownfield', 'Deluxe', 'Favorina',
    'Finessa', 'Freshona', 'Garden Gourmet', 'Gourmet', 'Hähnchen', 'Kania',
    'Mister Choc', 'Next Level', 'Parkside', 'Silvercrest', 'Vemondo', 'Wayne'
  ];
  
  for (const brand of brands) {
    if (text.toLowerCase().includes(brand.toLowerCase())) {
      return brand;
    }
  }
  return null;
}

/**
 * Findet vorhandene WebP-Bilder oder konvertiert PDF-Seiten zu Bildern
 */
async function getPageImages(pdfPath, tempDir) {
  const pdfDir = dirname(pdfPath);
  
  // Schritt 1: Prüfe ob WebP-Bilder bereits vorhanden sind
  const webpFiles = [];
  let pageNum = 1;
  while (true) {
    const webpPath = join(pdfDir, `page_${String(pageNum).padStart(2, '0')}.webp`);
    try {
      await fs.access(webpPath);
      webpFiles.push(webpPath);
      pageNum++;
    } catch {
      break;
    }
  }
  
  if (webpFiles.length > 0) {
    console.log(`✅ ${webpFiles.length} WebP-Bilder gefunden (direkt nutzbar)`);
    return webpFiles;
  }
  
  // Schritt 2: Falls keine WebP-Bilder: Konvertiere PDF mit Playwright
  console.log(`📸 Keine WebP-Bilder gefunden, konvertiere PDF-Seiten...`);
  console.log(`   ⚠️  Dies kann sehr lange dauern!`);
  console.log(`   💡 Tipp: Führe 'npm run fetch:lidl -- --keep-images' aus für schnellere Extraktion`);
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();
  
  // Öffne PDF im Browser
  const fileUrl = `file://${pdfPath}`;
  try {
    await page.goto(fileUrl, { waitUntil: 'domcontentloaded', timeout: 90000 });
  } catch (err) {
    await browser.close();
    throw new Error(`PDF konnte nicht geöffnet werden: ${err.message}`);
  }
  
  await page.waitForTimeout(2000);
  
  // Lese PDF-Info
  const pdfBytes = await fs.readFile(pdfPath);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const pageCount = pdfDoc.getPageCount();
  
  console.log(`   ${pageCount} Seiten gefunden`);
  
  const imagePaths = [];
  
  // Für jede Seite: Screenshot machen
  for (let i = 0; i < pageCount; i++) {
    const imagePath = join(tempDir, `page_${String(i + 1).padStart(3, '0')}.png`);
    
    try {
      // Versuche zur Seite zu navigieren
      if (i > 0) {
        await page.goto(`${fileUrl}#page=${i + 1}`, { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {
          // Fallback: Pfeiltaste
          page.keyboard.press('ArrowRight');
        });
        await page.waitForTimeout(1500);
      }
      
      // Screenshot der gesamten Seite
      await page.screenshot({
        path: imagePath,
        fullPage: true,
        type: 'png'
      });
      
      imagePaths.push(imagePath);
      process.stdout.write(`\r📸 Seite ${i + 1}/${pageCount} konvertiert`);
    } catch (err) {
      console.error(`\n⚠️  Fehler bei Seite ${i + 1}:`, err.message);
    }
  }
  
  await browser.close();
  console.log(`\n✅ ${imagePaths.length} Seiten als Bilder gespeichert`);
  
  return imagePaths;
}

/**
 * Parst Angebote aus OCR-Text (robustere Version)
 */
function parseOffersFromText(text, pageNum, defaultPeriod) {
  const offers = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  // Erweiterte Preis-Patterns (mit und ohne €, verschiedene Formate)
  const pricePatterns = [
    /(\d+[.,]\d{1,2})\s*€/g,           // "1,99 €" oder "1.99€"
    /€\s*(\d+[.,]\d{1,2})/g,           // "€ 1,99"
    /(\d+[.,]\d{2})\s*(?:EUR|Euro)/gi, // "1,99 EUR"
    /(\d+)\s*€/g,                      // "99 €" (ohne Komma)
  ];
  
  const allPriceMatches = [];
  for (const pattern of pricePatterns) {
    const matches = Array.from(text.matchAll(pattern));
    for (const match of matches) {
      const price = parseFloat(match[1].replace(',', '.'));
      // Filtere unrealistische Preise (zu niedrig oder zu hoch)
      if (price >= 0.01 && price <= 1000) {
        allPriceMatches.push({
          price,
          index: match.index,
          fullMatch: match[0]
        });
      }
    }
  }
  
  // Sortiere nach Position im Text
  allPriceMatches.sort((a, b) => a.index - b.index);
  
  // Dedupliziere ähnliche Preise an ähnlichen Positionen
  const uniquePrices = [];
  for (const match of allPriceMatches) {
    const isDuplicate = uniquePrices.some(existing => 
      Math.abs(existing.index - match.index) < 50 && 
      Math.abs(existing.price - match.price) < 0.01
    );
    if (!isDuplicate) {
      uniquePrices.push(match);
    }
  }
  
  for (const priceMatch of uniquePrices) {
    const priceIndex = priceMatch.index;
    
    // Finde Kontext um den Preis (vorherige und nachfolgende Zeilen)
    const contextStart = Math.max(0, priceIndex - 300);
    const contextEnd = Math.min(text.length, priceIndex + 150);
    const context = text.substring(contextStart, contextEnd);
    const contextLines = context.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    
    // Suche nach Titel (meist vor dem Preis)
    let title = '';
    let brand = null;
    let unit = null;
    
    // Finde die Zeile mit dem Preis
    let priceLineIndex = -1;
    for (let i = 0; i < contextLines.length; i++) {
      if (contextLines[i].includes(priceMatch.fullMatch) || 
          contextLines[i].match(/\d+[.,]\d{1,2}/)) {
        priceLineIndex = i;
        break;
      }
    }
    
    // Suche nach Titel in den Zeilen VOR dem Preis
    if (priceLineIndex >= 0) {
      // Gehe rückwärts von der Preis-Zeile
      for (let i = priceLineIndex - 1; i >= 0 && i >= priceLineIndex - 5; i--) {
        const line = contextLines[i];
        
        // Überspringe sehr kurze Zeilen oder reine Zahlen
        if (line.length < 2 || /^\d+$/.test(line)) continue;
        
        // Überspringe bekannte Header/Footer-Text
        if (/^(LIDL|Prospekt|Seite|Gültig|ab|von|bis)/i.test(line)) continue;
        
        // Titel-Kandidat: Zeile mit Text
        if (line.length >= 3 && line.length < 200) {
          if (!title) {
            title = line;
            brand = extractBrand(line);
          } else {
            // Kombiniere mehrere Zeilen für vollständigen Titel
            title = `${line} ${title}`.substring(0, 200);
          }
        }
        
        // Einheit extrahieren
        if (!unit) {
          unit = extractUnit(line);
        }
      }
    }
    
    // Fallback: Suche in der gesamten Kontext-Region
    if (!title || title.length < 3) {
      for (const line of contextLines) {
        if (line.length >= 5 && line.length < 150 && 
            !line.match(/\d+[.,]\d{1,2}\s*€/) &&
            !line.match(/^(LIDL|Prospekt|Seite)/i)) {
          title = line.substring(0, 200);
          brand = extractBrand(line);
          break;
        }
      }
    }
    
    // Nur wenn Titel gefunden (lockere Bedingung)
    if (title && title.length >= 2) {
      // Gültigkeitsdaten aus Kontext
      const period = parseValidityPeriod(context);
      
      const offer = {
        id: `lidl-${pageNum}-${offers.length + 1}`,
        retailer: 'LIDL',
        title: title.trim(),
        price: priceMatch.price,
        unit: unit || null,
        validFrom: period.validFrom,
        validTo: period.validTo,
        imageUrl: '',
        updatedAt: new Date().toISOString(),
        weekKey: getYearWeek().weekKey,
        brand: brand,
        page: pageNum,
        rawText: context.substring(0, 500)
      };
      
      offers.push(offer);
    }
  }
  
  return offers;
}

/**
 * Reichert Nährwerte via Open Food Facts API an
 */
async function enrichNutrition(productName, brand = null) {
  try {
    const searchTerm = brand ? `${brand} ${productName}` : productName;
    const encoded = encodeURIComponent(searchTerm);
    const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encoded}&search_simple=1&action=process&json=1&page_size=1`;
    
    const response = await fetch(url);
    const data = await response.json();
    
    if (data.products && data.products.length > 0) {
      const product = data.products[0];
      return {
        calories: product.nutriments?.['energy-kcal_100g'] || null,
        protein: product.nutriments?.proteins_100g || null,
        carbs: product.nutriments?.carbohydrates_100g || null,
        fat: product.nutriments?.fat_100g || null,
        fiber: product.nutriments?.fiber_100g || null,
        sugar: product.nutriments?.sugars_100g || null,
        salt: product.nutriments?.salt_100g || null,
        source: 'openfoodfacts',
        barcode: product.code || null
      };
    }
  } catch (err) {
    // Silent fail
  }
  
  return null;
}

/**
 * Extrahiert Angebote aus einem PDF
 */
async function extractOffersFromPdf(pdfPath) {
  console.log(`\n📄 Verarbeite PDF: ${basename(pdfPath)}`);
  
  const pdfBytes = await fs.readFile(pdfPath);
  const pdfDoc = await PDFDocument.load(pdfBytes);
  const pageCount = pdfDoc.getPageCount();
  
  console.log(`   ${pageCount} Seiten gefunden`);
  
  const { year, week, weekKey } = getYearWeek();
  const defaultPeriod = parseValidityPeriod('');
  
  // Lade Tesseract.js
  let tesseract = null;
  try {
    const tesseractModule = await import('tesseract.js');
    tesseract = tesseractModule.default;
    console.log('✅ OCR verfügbar (tesseract.js)');
  } catch (err) {
    console.error('❌ OCR nicht verfügbar! Installiere: npm install tesseract.js');
    process.exit(1);
  }
  
  const offers = [];
  const tempDir = join(dirname(pdfPath), '__ocr_temp');
  await fs.mkdir(tempDir, { recursive: true });
  
  try {
    // Schritt 1: Finde vorhandene WebP-Bilder oder konvertiere PDF
    const imagePaths = await getPageImages(pdfPath, tempDir);
    
    if (imagePaths.length === 0) {
      throw new Error('Keine Bilder konnten aus PDF erstellt werden');
    }
    
    // Schritt 2: OCR auf allen Bildern
    console.log(`\n🔍 OCR auf ${imagePaths.length} Seiten...`);
    
    for (let i = 0; i < imagePaths.length; i++) {
      const imagePath = imagePaths[i];
      const pageNum = i + 1;
      
      console.log(`\n📄 Seite ${pageNum}/${imagePaths.length}: ${basename(imagePath)}`);
      
      try {
        // OCR durchführen (WebP oder PNG)
        process.stdout.write(`   🔍 OCR läuft...`);
        
        // Konvertiere WebP zu PNG falls nötig (Tesseract bevorzugt PNG)
        let ocrImagePath = imagePath;
        if (imagePath.endsWith('.webp')) {
          const pngPath = join(tempDir, `page_${String(pageNum).padStart(3, '0')}_ocr.png`);
          const webpBuffer = await fs.readFile(imagePath);
          const pngBuffer = await sharp(webpBuffer).png().toBuffer();
          await fs.writeFile(pngPath, pngBuffer);
          ocrImagePath = pngPath;
        }
        
        const { data: { text } } = await tesseract.recognize(ocrImagePath, 'deu+eng', {
          logger: m => {
            if (m.status === 'recognizing text') {
              process.stdout.write(`\r   🔍 OCR: ${Math.round(m.progress * 100)}%`);
            }
          }
        });
        
        console.log(`\n   ✅ Text extrahiert (${text.length} Zeichen)`);
        
        // Debug: Zeige ersten 500 Zeichen des OCR-Textes (nur bei ersten 3 Seiten)
        if (pageNum <= 3) {
          const preview = text.substring(0, 500).replace(/\n/g, ' | ');
          console.log(`   📝 OCR-Vorschau: ${preview}...`);
        }
        
        // Parse Angebote
        const pageOffers = parseOffersFromText(text, pageNum, defaultPeriod);
        offers.push(...pageOffers);
        
        console.log(`   📦 ${pageOffers.length} Angebote gefunden`);
        
        // Debug: Zeige ersten gefundenen Text
        if (pageOffers.length > 0) {
          console.log(`   Beispiel: "${pageOffers[0].title}" - ${pageOffers[0].price}€`);
        } else if (pageNum <= 3) {
          // Debug: Zeige gefundene Preise wenn keine Angebote
          const priceMatches = text.match(/\d+[.,]\d{1,2}\s*€/g);
          if (priceMatches) {
            console.log(`   💰 Gefundene Preise: ${priceMatches.slice(0, 5).join(', ')}`);
          }
        }
      } catch (err) {
        console.error(`\n   ❌ Fehler bei OCR:`, err.message);
      }
    }
  } finally {
    // Cleanup
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch {}
  }
  
  // Deduplizierung
  const uniqueOffers = [];
  const seen = new Set();
  for (const offer of offers) {
    const key = `${offer.title.toLowerCase()}|${offer.price}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueOffers.push(offer);
    }
  }
  
  return {
    weekKey,
    year,
    week,
    extractedAt: new Date().toISOString(),
    pdfPath: basename(pdfPath),
    pageCount,
    offers: uniqueOffers,
    totalOffers: uniqueOffers.length
  };
}

async function main() {
  console.log('🔍 Lidl-Angebote Extraktion (Vollständig)\n');
  console.log('⚠️  Dieser Prozess kann 1+ Stunde dauern für vollständige Extraktion!\n');
  
  // Prüfe ob Eingabe ein Verzeichnis oder eine Datei ist
  let pdfFiles = [];
  try {
    const stat = await fs.stat(pdfPathOrDir);
    if (stat.isDirectory()) {
      // Verzeichnis: Suche alle PDFs
      const files = await fs.readdir(pdfPathOrDir);
      pdfFiles = files
        .filter(f => f.toLowerCase().endsWith('.pdf'))
        .map(f => join(pdfPathOrDir, f));
      console.log(`📁 Verzeichnis gefunden: ${pdfFiles.length} PDF(s)`);
    } else {
      // Einzelne Datei
      pdfFiles = [pdfPathOrDir];
    }
  } catch {
    console.error(`❌ Pfad nicht gefunden: ${pdfPathOrDir}`);
    process.exit(1);
  }
  
  if (pdfFiles.length === 0) {
    console.error(`❌ Keine PDF-Dateien gefunden`);
    process.exit(1);
  }
  
  // Verarbeite alle PDFs
  const allOffers = [];
  for (const pdfPath of pdfFiles) {
    try {
      const result = await extractOffersFromPdf(pdfPath);
      allOffers.push(...result.offers);
      console.log(`\n✅ ${basename(pdfPath)}: ${result.offers.length} Angebote`);
    } catch (err) {
      console.error(`\n❌ Fehler bei ${basename(pdfPath)}:`, err.message);
    }
  }
  
  // Finale Deduplizierung über alle PDFs
  const finalOffers = [];
  const seen = new Set();
  for (const offer of allOffers) {
    const key = `${offer.title.toLowerCase()}|${offer.price}`;
    if (!seen.has(key)) {
      seen.add(key);
      finalOffers.push(offer);
    }
  }
  
  // Nährwerte anreichern (optional)
  if (shouldEnrichNutrition && finalOffers.length > 0) {
    console.log(`\n🍎 Reichere Nährwerte an (${finalOffers.length} Produkte)...`);
    for (let i = 0; i < finalOffers.length; i++) {
      const offer = finalOffers[i];
      process.stdout.write(`\r   ${i + 1}/${finalOffers.length}: ${offer.title.substring(0, 40)}...`);
      const nutrition = await enrichNutrition(offer.title, offer.brand);
      if (nutrition) {
        offer.nutrition = nutrition;
      }
      await new Promise(r => setTimeout(r, 1000)); // Rate limiting
    }
    console.log('');
  }
  
  // Erstelle Ausgabeverzeichnis
  const outDir = dirname(outJson);
  await fs.mkdir(outDir, { recursive: true });
  
  // Finales Ergebnis
  const result = {
    weekKey: getYearWeek().weekKey,
    extractedAt: new Date().toISOString(),
    pdfs: pdfFiles.map(f => basename(f)),
    totalOffers: finalOffers.length,
    offers: finalOffers
  };
  
  // Speichere JSON
  await fs.writeFile(outJson, JSON.stringify(result, null, 2));
  
  console.log(`\n✅ FERTIG!`);
  console.log(`   JSON gespeichert: ${outJson}`);
  console.log(`   Gesamt-Angebote: ${finalOffers.length}`);
  console.log(`   Verarbeitete PDFs: ${pdfFiles.length}`);
}

main().catch(err => {
  console.error('\n❌ Fehler:', err);
  if (process.env.DEBUG) {
    console.error(err.stack);
  }
  process.exit(1);
});
