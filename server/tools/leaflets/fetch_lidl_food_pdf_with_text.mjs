#!/usr/bin/env node
// Lidl Lebensmittel-Prospekt PDF Generator (einfach - nur Bilder)

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
 * Findet die Lebensmittel-Prospekt-URL
 */
async function findFoodLeafletUrl() {
  console.log('🔍 Suche nach Lebensmittel-Prospekt-URL...\n');
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
  });
  const page = await context.newPage();
  
  try {
    // Öffne Lidl-Prospekt-Übersicht
    await page.goto('https://www.lidl.de/c/online-prospekte/s10005610', {
      waitUntil: 'domcontentloaded',
      timeout: 60000,
    });
    
    await page.waitForTimeout(3000);
    
    // Suche nach Lebensmittel-Prospekten
    const foodLeaflets = await page.evaluate(() => {
      const leaflets = [];
      const links = document.querySelectorAll('a[href*="/l/prospekte/"], a[href*="/prospekt/"]');
      
      for (const link of links) {
        const href = link.href;
        const text = (link.textContent || '').toLowerCase();
        const parentText = (link.closest('article, .product, .flyer-card, [class*="prospekt"]')?.textContent || '').toLowerCase();
        
        // Prüfe ob Lebensmittel-bezogen (NICHT Non-Food)
        const foodKeywords = [
          'aktionsprospekt', 'lebensmittel', 'nahrung', 'essen',
          'milch', 'brot', 'käse', 'fleisch', 'obst', 'gemüse',
        ];
        
        const nonFoodKeywords = [
          'non-food', 'nonfood', 'haushalt', 'technik', 'elektronik',
          'textilien', 'bekleidung', 'möbel', 'garten', 'werkzeug'
        ];
        
        const isFood = foodKeywords.some(keyword => 
          text.includes(keyword) || parentText.includes(keyword)
        );
        
        const isNonFood = nonFoodKeywords.some(keyword =>
          text.includes(keyword) || parentText.includes(keyword)
        );
        
        if (isFood && !isNonFood && (href.includes('/l/prospekte/') || href.includes('/prospekt/'))) {
          leaflets.push({
            url: href,
            title: text,
          });
        }
      }
      
      return leaflets;
    });
    
    await browser.close();
    
    if (foodLeaflets.length > 0) {
      console.log('✅ Lebensmittel-Prospekt gefunden:\n');
      console.log(`   ${foodLeaflets[0].title}`);
      console.log(`   ${foodLeaflets[0].url}\n`);
      return foodLeaflets[0].url;
    } else {
      console.log('⚠️  Keine Lebensmittel-Prospekte gefunden, verwende Standard-URL\n');
      return 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
    }
    
  } catch (error) {
    console.error('❌ Fehler beim Suchen:', error.message);
    await browser.close();
    return 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
  }
}


/**
 * Erstellt einfaches PDF aus Bildern (ohne Text-Layer)
 */
async function createPdfFromImages(imageUrls, pdfPath, lidlUrl) {
  console.log(`\n📄 Erstelle PDF aus ${imageUrls.size} Bildern...`);
  
  // URLs sortieren
  const sortedUrls = Array.from(imageUrls.values())
    .map((item, index) => ({ ...item, pageNum: index + 1 }))
    .sort((a, b) => a.pageNum - b.pageNum);

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

  // Einfaches PDF erstellen (nur Bilder, kein Text-Layer)
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
      
      // Zeichne Bild als Hintergrund
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
 * Schließt Consent-Dialoge (verbessert für Lidl)
 */
async function closeConsentDialogs(page) {
  try {
    console.log('🍪 Prüfe Cookie-Consent-Dialoge...');
    await page.waitForTimeout(2000);
    
    // Erweiterte Selektoren für Lidl Cookie-Dialog
    const consentSelectors = [
      // Standard-Buttons
      'button[aria-label*="akzeptieren" i]',
      'button[aria-label*="zustimmen" i]',
      'button[id*="accept" i]',
      'button:has-text("Akzeptieren")',
      'button:has-text("Alle akzeptieren")',
      'button:has-text("Speichern")',
      // Lidl-spezifische Selektoren
      'button[class*="accept"]',
      'button[class*="consent"]',
      '[data-testid*="accept"]',
      '[data-testid*="consent"]',
      // Modal-Close-Buttons
      '.modal button[aria-label*="schließen" i]',
      'button[aria-label*="schließen" i]',
      '[role="dialog"] button:has-text("Schließen")',
      // Cookie-Banner-Buttons
      '[class*="cookie"] button',
      '[class*="consent"] button',
      '[id*="cookie"] button',
      '[id*="consent"] button',
    ];
    
    let clicked = false;
    for (const sel of consentSelectors) {
      try {
        // Versuche zuerst mit waitForSelector (mit Timeout)
        const btn = await page.$(sel).catch(() => null);
        if (btn) {
          const isVisible = await btn.isVisible().catch(() => false);
          if (isVisible) {
            await btn.scrollIntoViewIfNeeded();
            await page.waitForTimeout(300);
            await btn.click({ delay: 100 });
            clicked = true;
            console.log(`   ✅ Cookie-Dialog geschlossen (Selector: ${sel})`);
            await page.waitForTimeout(1000);
            break;
          }
        }
      } catch (err) {
        // Ignoriere Fehler und versuche nächsten Selector
      }
    }
    
    // Fallback: Versuche mit JavaScript direkt zu klicken
    if (!clicked) {
      try {
        const result = await page.evaluate(() => {
          // Suche nach Buttons mit relevantem Text
          const buttons = Array.from(document.querySelectorAll('button, [role="button"]'));
          for (const btn of buttons) {
            const text = (btn.textContent || btn.innerText || '').toLowerCase();
            const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
            
            if (text.includes('akzeptieren') || 
                text.includes('zustimmen') || 
                text.includes('speichern') ||
                ariaLabel.includes('akzeptieren') ||
                ariaLabel.includes('zustimmen')) {
              btn.click();
              return true;
            }
          }
          return false;
        });
        
        if (result) {
          console.log('   ✅ Cookie-Dialog geschlossen (JavaScript-Fallback)');
          await page.waitForTimeout(1000);
        } else {
          console.log('   ℹ️  Kein Cookie-Dialog gefunden oder bereits geschlossen');
        }
      } catch (err) {
        // Ignoriere Fehler
      }
    }
    
    // Warte noch etwas, damit Dialoge vollständig verschwinden
    await page.waitForTimeout(1000);
    
    // Prüfe ob noch Dialoge sichtbar sind
    const stillVisible = await page.evaluate(() => {
      const dialogs = document.querySelectorAll('[role="dialog"], .modal, [class*="cookie"], [class*="consent"]');
      for (const dialog of dialogs) {
        const style = window.getComputedStyle(dialog);
        if (style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0') {
          return true;
        }
      }
      return false;
    });
    
    if (stillVisible) {
      console.log('   ⚠️  Dialoge könnten noch sichtbar sein, versuche ESC-Taste...');
      await page.keyboard.press('Escape');
      await page.waitForTimeout(500);
    }
    
  } catch (err) {
    console.log(`   ⚠️  Fehler beim Schließen von Cookie-Dialogen: ${err.message}`);
  }
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
 * Klickt durch alle Seiten und sammelt Bilder
 */
async function clickThroughAllPages(page, imageUrls, maxPages = 50) {
  console.log('📖 Durchblättern und Bilder sammeln...');
  
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
 * Hauptfunktion
 */
async function main() {
  const { year, week, weekKey } = getYearWeek();
  
  console.log(`\n📋 Lidl Lebensmittel-Prospekt PDF Generator`);
  console.log(`📅 Kalenderwoche: ${weekKey}\n`);

  // Finde Lebensmittel-Prospekt-URL
  const lidlUrl = await findFoodLeafletUrl();
  
  const lidlMediaDir = resolve(__dirname, '../../media/prospekte/lidl');
  const pdfPath = join(lidlMediaDir, `lidl_food_${weekKey}.pdf`);
  
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

  // Bilder sammeln
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

  // Warte kurz, damit Cookie-Dialoge geladen werden
  await page.waitForTimeout(2000);

  // Consent-Dialoge schließen
  await closeConsentDialogs(page);
  
  // Warte noch etwas, damit Seite nach Dialog-Schließung vollständig geladen ist
  await page.waitForTimeout(1000);

  // Durch Seite scrollen
  await scrollEntirePage(page);
  await page.waitForTimeout(2000);
  
  // Durch alle Seiten blättern und Bilder sammeln
  await clickThroughAllPages(page, imageUrls, 50);
  
  await page.waitForTimeout(2000);
  
  await browser.close();

  // PDF aus Bildern erstellen
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

