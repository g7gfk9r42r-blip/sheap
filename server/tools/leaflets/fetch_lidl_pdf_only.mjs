#!/usr/bin/env node
// Einfaches Script: Nur PDF erstellen, keine JSON-Dateien

import { chromium } from 'playwright';
import sharp from 'sharp';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

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
 * Extrahiert Seitennummer aus URL
 */
function extractPageNumber(url) {
  const patterns = [
    /(?:page[_-]?|p[=_-]?)(\d{1,3})/i,
    /\/(\d{1,3})\.webp/i,
    /[_-](\d{1,3})(?:\.[a-z]+)?$/i,
  ];
  
  for (const pattern of patterns) {
    const match = url.match(pattern);
    if (match) {
      const num = parseInt(match[1], 10);
      if (num > 0 && num < 1000) return num;
    }
  }
  return 0;
}

/**
 * Erstellt PDF aus WebP-Bildern
 */
async function createPdfFromImages(imageUrls, pdfPath, lidlUrl) {
  console.log(`\n📄 Erstelle PDF aus ${imageUrls.size} Bildern...`);
  
  // URLs sortieren
  const sortedUrls = Array.from(imageUrls.values())
    .map(item => ({ ...item, pageNum: extractPageNumber(item.url) }))
    .sort((a, b) => {
      if (a.pageNum !== 0 && b.pageNum !== 0) {
        return a.pageNum - b.pageNum;
      }
      if (a.pageNum !== 0) return -1;
      if (b.pageNum !== 0) return 1;
      return a.url.localeCompare(b.url);
    });

  // Browser für Downloads
  const downloadBrowser = await chromium.launch({ headless: true });
  const downloadPage = await downloadBrowser.newPage();
  await downloadPage.setExtraHTTPHeaders({
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    'Referer': lidlUrl
  });

  const imageFiles = [];
  for (let i = 0; i < sortedUrls.length; i++) {
    const item = sortedUrls[i];
    const pageNum = String(i + 1).padStart(2, '0');
    const imagePath = join(dirname(pdfPath), `page_${pageNum}.webp`);

    try {
      const response = await downloadPage.request.get(item.url, {
        headers: { 'Referer': lidlUrl }
      });
      
      if (!response.ok()) {
        throw new Error(`HTTP ${response.status()}`);
      }
      
      const buffer = await response.body();
      
      if (buffer.length < 100) {
        throw new Error('Bild zu klein');
      }
      
      await fs.writeFile(imagePath, buffer);
      imageFiles.push(imagePath);
      
      const sizeKB = (buffer.length / 1024).toFixed(1);
      process.stdout.write(`\r📥 Heruntergeladen: ${i + 1}/${sortedUrls.length} (${sizeKB} KB)`);
    } catch (err) {
      console.error(`\n⚠️  Fehler beim Download von Seite ${pageNum}:`, err.message);
    }
  }

  await downloadBrowser.close();
  console.log(`\n✅ ${imageFiles.length} Bilder gespeichert`);

  if (imageFiles.length === 0) {
    throw new Error('Keine Bilder konnten heruntergeladen werden.');
  }

  // PDF erstellen
  const { PDFDocument } = await import('pdf-lib');
  const pdfDoc = await PDFDocument.create();

  for (let i = 0; i < imageFiles.length; i++) {
    const imagePath = imageFiles[i];
    try {
      const imageBuffer = await fs.readFile(imagePath);
      const pngBuffer = await sharp(imageBuffer).png().toBuffer();
      const image = await pdfDoc.embedPng(pngBuffer);
      const { width, height } = image.scale(1);
      const page = pdfDoc.addPage([width, height]);
      page.drawImage(image, {
        x: 0,
        y: 0,
        width: width,
        height: height,
      });
      
      process.stdout.write(`\r📄 PDF-Seiten erstellt: ${i + 1}/${imageFiles.length}`);
    } catch (err) {
      console.error(`\n⚠️  Fehler beim Hinzufügen von ${imagePath}:`, err.message);
    }
  }

  const pdfBytes = await pdfDoc.save();
  await fs.writeFile(pdfPath, pdfBytes);

  // Cleanup: Lösche temporäre WebP-Dateien
  console.log('\n🧹 Lösche temporäre WebP-Dateien...');
  for (const imagePath of imageFiles) {
    try {
      await fs.unlink(imagePath);
    } catch {}
  }

  const fileSizeMB = (pdfBytes.length / 1024 / 1024).toFixed(2);
  console.log(`\n✅ PDF erfolgreich erstellt!`);
  console.log(`   Pfad: ${pdfPath}`);
  console.log(`   Größe: ${fileSizeMB} MB`);
  console.log(`   Seiten: ${imageFiles.length}`);
}

/**
 * Schließt Consent-Dialoge
 */
async function closeConsentDialogs(page) {
  try {
    await page.waitForTimeout(1000);
    const consentSelectors = [
      'button[aria-label*="akzeptieren" i]',
      'button[aria-label*="zustimmen" i]',
      'button[id*="accept" i]',
      '.modal button[aria-label*="schließen" i]'
    ];
    
    for (const sel of consentSelectors) {
      try {
        const btn = await page.$(sel);
        if (btn && await btn.isVisible()) {
          await btn.click({ delay: 50 });
          await page.waitForTimeout(500);
        }
      } catch {}
    }
  } catch {}
}

/**
 * Scrollt die gesamte Seite durch
 */
async function scrollEntirePage(page) {
  console.log('📜 Scrolle durch die gesamte Seite...');
  
  const scrollInfo = await page.evaluate(() => {
    return {
      totalHeight: Math.max(
        document.body.scrollHeight,
        document.documentElement.scrollHeight,
        document.body.offsetHeight,
        document.documentElement.offsetHeight,
        document.body.clientHeight,
        document.documentElement.clientHeight
      ),
      viewportHeight: window.innerHeight
    };
  });
  
  const totalHeight = scrollInfo.totalHeight;
  const stepSize = Math.ceil(totalHeight / 50);
  
  for (let i = 0; i <= 50; i++) {
    const scrollY = Math.min(i * stepSize, totalHeight);
    await page.evaluate((y) => window.scrollTo(0, y), scrollY);
    await page.waitForTimeout(100);
  }
  
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.waitForTimeout(500);
  console.log('✅ Scrollen abgeschlossen');
}

/**
 * Klickt durch alle Seiten mit Next-Button
 */
async function clickThroughAllPages(page, imageUrls, maxPages = 50) {
  console.log('📖 Durchblättern mit Next-Button...');
  
  const nextSelectors = [
    'button[aria-label*="weiter" i]',
    'button[title*="weiter" i]',
    '.slick-next',
    '.swiper-button-next',
    '[data-testid="next"]',
    'button[aria-label*="nächste" i]',
    'button[aria-label*="next" i]'
  ];

  let consecutiveFailures = 0;
  const maxFailures = 3;
  let noNewImagesCount = 0;
  const maxNoNewImages = 3;
  let lastImageCount = imageUrls.size;
  
  for (let i = 0; i < maxPages; i++) {
    const currentImageCount = imageUrls.size;
    
    if (currentImageCount === lastImageCount) {
      noNewImagesCount++;
      if (noNewImagesCount >= maxNoNewImages) {
        console.log(`\n✅ Keine neuen Bilder mehr (${currentImageCount} Bilder), stoppe Durchblättern`);
        break;
      }
    } else {
      noNewImagesCount = 0;
      lastImageCount = currentImageCount;
    }
    
    let clicked = false;
    for (const selector of nextSelectors) {
      try {
        const btn = await page.$(selector);
        if (btn) {
          const isVisible = await btn.isVisible().catch(() => false);
          const isDisabled = await btn.isDisabled().catch(() => false);
          
          if (isVisible && !isDisabled) {
            await btn.evaluate(el => el.scrollIntoView({ behavior: 'smooth', block: 'center' }));
            await page.waitForTimeout(400);
            await btn.click({ delay: 100 });
            clicked = true;
            consecutiveFailures = 0;
            break;
          }
        }
      } catch {}
    }
    
    if (!clicked) {
      consecutiveFailures++;
    }
    
    await page.waitForTimeout(1500);
    
    if (i % 5 === 0 || i < 10) {
      process.stdout.write(`\r📖 Durchblättert: ${i + 1}... (${currentImageCount} Bilder)`);
    }
    
    if (consecutiveFailures >= maxFailures) {
      console.log(`\n⚠️  Keine weiteren Seiten nach ${i + 1} Versuchen`);
      break;
    }
  }
  console.log(`\n✅ Durchblättern abgeschlossen (${imageUrls.size} Bilder)`);
}

/**
 * Hauptfunktion: Erstellt nur PDF, keine JSON
 */
async function main() {
  const { year, week, weekKey } = getYearWeek();
  const lidlUrl = process.env.LIDL_LEAFLET_URL || 
    'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
  
  console.log(`\n📋 Lidl PDF Generator (Nur PDF, keine JSON)`);
  console.log(`📅 Kalenderwoche: ${weekKey}`);
  console.log(`🔗 URL: ${lidlUrl}\n`);

  const lidlMediaDir = resolve(__dirname, '../../media/prospekte/lidl');
  const pdfPath = join(lidlMediaDir, `lidl_${weekKey}.pdf`);
  
  await fs.mkdir(lidlMediaDir, { recursive: true });

  // Prüfe ob PDF bereits existiert
  try {
    await fs.access(pdfPath);
    console.log(`ℹ️  PDF bereits vorhanden: ${pdfPath}`);
    console.log(`   Lösche altes PDF und erstelle neues...`);
    await fs.unlink(pdfPath);
  } catch {}

  console.log(`📥 Öffne Lidl-Viewer...`);

  // Browser starten
  const browser = await chromium.launch({ 
    headless: true,
    args: [
      '--no-sandbox', 
      '--disable-setuid-sandbox',
      '--disable-blink-features=AutomationControlled',
      '--disable-dev-shm-usage'
    ]
  });
  
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    extraHTTPHeaders: {
      'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
    }
  });
  
  const page = await context.newPage();

  // Nur Bilder sammeln
  const imageUrls = new Map();

  page.on('response', async (response) => {
    try {
      const url = response.url();
      const contentType = response.headers()['content-type'] || '';
      const contentLength = parseInt(response.headers()['content-length'] || '0', 10);

      // Sammle nur Bilder
      if (url.includes('imgproxy.leaflets.schwarz') && 
          (contentType.includes('image/') || url.match(/\.(webp|jpg|jpeg|png)(\?|$)/i))) {
        if (!imageUrls.has(url)) {
          imageUrls.set(url, { contentType, url, size: contentLength });
          process.stdout.write(`\r📥 Bilder gefunden: ${imageUrls.size}`);
        }
      }
    } catch {}
  });

  // Seite laden
  try {
    await page.goto(lidlUrl, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {});
  } catch (err) {
    try {
      await page.goto(lidlUrl, { waitUntil: 'domcontentloaded', timeout: 60000 });
    } catch (err2) {
      throw new Error(`Fehler beim Laden: ${err.message}`);
    }
  }

  // Consent-Dialoge schließen
  await closeConsentDialogs(page);

  // Durch Seite scrollen
  await scrollEntirePage(page);
  await page.waitForTimeout(2000);
  
  // Durch alle Seiten blättern
  await clickThroughAllPages(page, imageUrls, 50);
  
  await page.waitForTimeout(2000);
  
  await browser.close();

  // PDF erstellen
  if (imageUrls.size > 0) {
    await createPdfFromImages(imageUrls, pdfPath, lidlUrl);
    console.log(`\n✅ Fertig! PDF erstellt: ${pdfPath}`);
  } else {
    console.log('\n⚠️  Keine Bilder gefunden, PDF kann nicht erstellt werden.');
    process.exit(1);
  }
}

main().catch(err => {
  console.error('\n❌ Fehler:', err.message);
  process.exit(1);
});

