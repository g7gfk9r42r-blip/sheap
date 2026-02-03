#!/usr/bin/env node
// Fetch REWE Offers using Playwright
// Scrapes rewe.de/angebote for current offers

import { chromium } from 'playwright';
import fs from 'fs/promises';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Funktion zur Berechnung der ISO-Kalenderwoche
function getYearWeek(date = new Date()) {
  const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  const year = d.getUTCFullYear();
  const week = String(weekNo).padStart(2, '0');
  return { year, week: weekNo, weekKey: `${year}-W${week}` };
}

// REWE Angebots-URL (ohne Markt-Auswahl, zeigt alle Angebote)
const REWE_OFFERS_URL = 'https://www.rewe.de/angebote';

// Network-Interception: Fange API-Responses ab
const capturedPayloads = [];

function shouldCapturePayload(url) {
  // REWE verwendet verschiedene API-Endpunkte für Angebote
  return url.includes('/api/') || 
         url.includes('/offers') || 
         url.includes('/products') ||
         url.includes('/angebote') ||
         url.includes('rewe.de/api');
}

// Extrahiere Offers aus JSON-Payloads
function extractOffersFromPayloads(payloads) {
  const offers = [];
  
  for (const payload of payloads) {
    try {
      const data = typeof payload === 'string' ? JSON.parse(payload) : payload;
      
      // Verschiedene mögliche Strukturen in REWE API-Responses
      const candidates = [
        data.offers,
        data.products,
        data.items,
        data.data?.offers,
        data.data?.products,
        data.data?.items,
        data.results,
        data.content?.offers,
        data.content?.products,
      ];
      
      for (const candidate of candidates) {
        if (Array.isArray(candidate)) {
          for (const item of candidate) {
            if (item && typeof item === 'object') {
              const offer = transformReweToOffer(item);
              if (offer) {
                offers.push(offer);
              }
            }
          }
        }
      }
    } catch (err) {
      // Ignoriere JSON-Parse-Fehler
    }
  }
  
  return offers;
}

// Transformiere REWE-Datenformat zu unserem Offer-Format
function transformReweToOffer(item) {
  try {
    // Verschiedene mögliche Feldnamen in REWE API
    const title = item.name || item.title || item.productName || item.label || '';
    const price = parseFloat(item.price || item.salePrice || item.currentPrice || item.priceValue || 0);
    const originalPrice = item.originalPrice || item.regularPrice || item.oldPrice || null;
    const unit = item.unit || item.quantity || item.packaging || '';
    const brand = item.brand || item.manufacturer || null;
    const imageUrl = item.image || item.imageUrl || item.thumbnail || item.picture || '';
    const discount = item.discount || item.discountPercent || item.savings || null;
    const category = item.category || item.categoryName || null;
    
    if (!title || price <= 0) {
      return null;
    }
    
    const { weekKey } = getYearWeek();
    const now = new Date();
    const validFrom = item.validFrom || item.startDate || now.toISOString();
    const validTo = item.validTo || item.endDate || new Date(now.getTime() + 6 * 24 * 3600 * 1000).toISOString();
    
    // Generiere ID
    const id = item.id || item.productId || item.sku || `rewe-${title.toLowerCase().replace(/\s+/g, '-')}-${price}`;
    
    return {
      id: `REWE-${id}`,
      retailer: 'REWE',
      title: title.trim(),
      price: price,
      originalPrice: originalPrice ? parseFloat(originalPrice) : null,
      discountPercent: discount,
      unit: unit || 'Stück',
      brand: brand,
      category: category,
      imageUrl: imageUrl || '',
      validFrom: validFrom,
      validTo: validTo,
      weekKey: weekKey,
      updatedAt: now.toISOString(),
    };
  } catch (err) {
    return null;
  }
}

// DOM-Scraping: Extrahiere Offers direkt aus dem HTML
async function scrapeOffersFromDOM(page) {
  const offers = [];
  
  try {
    // Warte auf Angebots-Container
    await page.waitForSelector('[data-testid*="offer"], .offer, .product-tile, [class*="offer"], [class*="product"]', { timeout: 10000 }).catch(() => {});
    
    // Extrahiere Angebote aus verschiedenen möglichen Selektoren
    const offerElements = await page.$$eval(
      '[data-testid*="offer"], .offer, .product-tile, [class*="offer"], [class*="product"], article[class*="product"]',
      (elements) => {
        return elements.map((el) => {
          const title = el.querySelector('h2, h3, [class*="title"], [class*="name"], .product-title, .offer-title')?.textContent?.trim() || '';
          const priceText = el.querySelector('[class*="price"], .price, [data-price], [class*="amount"]')?.textContent?.trim() || '';
          const image = el.querySelector('img')?.src || el.querySelector('img')?.getAttribute('data-src') || '';
          const brand = el.querySelector('[class*="brand"], .brand')?.textContent?.trim() || '';
          const unit = el.querySelector('[class*="unit"], .unit, [class*="quantity"]')?.textContent?.trim() || '';
          
          return { title, priceText, image, brand, unit };
        }).filter(item => item.title && item.priceText);
      }
    );
    
    for (const item of offerElements) {
      // Parse Preis
      const priceMatch = item.priceText.match(/[\d,]+/);
      if (priceMatch) {
        const price = parseFloat(priceMatch[0].replace(',', '.'));
        if (price > 0) {
          const { weekKey } = getYearWeek();
          const now = new Date();
          const id = `rewe-dom-${item.title.toLowerCase().replace(/\s+/g, '-')}-${price}`;
          
          offers.push({
            id: `REWE-${id}`,
            retailer: 'REWE',
            title: item.title,
            price: price,
            unit: item.unit || 'Stück',
            brand: item.brand || null,
            imageUrl: item.image || '',
            validFrom: now.toISOString(),
            validTo: new Date(now.getTime() + 6 * 24 * 3600 * 1000).toISOString(),
            weekKey: weekKey,
            updatedAt: now.toISOString(),
          });
        }
      }
    }
  } catch (err) {
    console.error('⚠️  DOM-Scraping Fehler:', err.message);
  }
  
  return offers;
}

async function main() {
  const { year, week, weekKey } = getYearWeek();
  const outputDir = resolve(__dirname, '../../data/rewe', String(year), `W${week}`);
  await fs.mkdir(outputDir, { recursive: true });
  const outputPath = join(outputDir, `offers_${weekKey}.json`);
  
  console.log(`\n📋 REWE Angebote für ${weekKey}`);
  console.log(`🔗 URL: ${REWE_OFFERS_URL}\n`);
  
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  });
  const page = await context.newPage();
  
  // Network-Interception: Fange API-Responses ab
  page.on('response', async (response) => {
    const url = response.url();
    if (shouldCapturePayload(url) && response.headers()['content-type']?.includes('json')) {
      try {
        const text = await response.text();
        if (text && text.length > 0) {
          capturedPayloads.push(text);
        }
      } catch (err) {
        // Ignoriere Fehler
      }
    }
  });
  
  try {
    console.log('📥 Lade REWE Angebotsseite...');
    await page.goto(REWE_OFFERS_URL, { waitUntil: 'domcontentloaded', timeout: 90000 });
    
    // Warte auf Content-Load
    await page.waitForTimeout(3000);
    
    // Versuche Cookie-Banner zu akzeptieren
    try {
      const cookieSelectors = [
        'button:has-text("Akzeptieren")',
        'button:has-text("Alle akzeptieren")',
        '[data-testid*="accept"]',
        '[id*="accept"]',
        '.cookie-accept',
        '#cookie-accept',
      ];
      
      for (const selector of cookieSelectors) {
        try {
          const button = await page.locator(selector).first().waitFor({ timeout: 2000 });
          if (button) {
            await button.click();
            console.log('✅ Cookie-Banner akzeptiert');
            await page.waitForTimeout(1000);
            break;
          }
        } catch {
          // Weiter zum nächsten Selector
        }
      }
    } catch {
      // Cookie-Banner nicht gefunden, ist OK
    }
    
    // Scroll durch die Seite, um lazy-loaded Content zu laden
    console.log('📜 Scrolle durch die Seite...');
    await page.evaluate(async () => {
      await new Promise((resolve) => {
        let totalHeight = 0;
        const distance = 100;
        const timer = setInterval(() => {
          const scrollHeight = document.body.scrollHeight;
          window.scrollBy(0, distance);
          totalHeight += distance;
          
          if (totalHeight >= scrollHeight) {
            clearInterval(timer);
            resolve();
          }
        }, 100);
      });
    });
    
    await page.waitForTimeout(2000);
    
    // Extrahiere Offers aus Network-Responses
    console.log('🔍 Extrahiere Offers aus API-Responses...');
    const apiOffers = extractOffersFromPayloads(capturedPayloads);
    console.log(`   ✅ ${apiOffers.length} Offers aus API gefunden`);
    
    // DOM-Scraping als Fallback
    console.log('🔍 Extrahiere Offers aus DOM...');
    const domOffers = await scrapeOffersFromDOM(page);
    console.log(`   ✅ ${domOffers.length} Offers aus DOM gefunden`);
    
    // Kombiniere und dedupliziere
    const allOffers = [...apiOffers, ...domOffers];
    const uniqueOffers = [];
    const seen = new Set();
    
    for (const offer of allOffers) {
      const key = `${offer.title}-${offer.price}`;
      if (!seen.has(key)) {
        seen.add(key);
        uniqueOffers.push(offer);
      }
    }
    
    console.log(`\n✅ Gesamt: ${uniqueOffers.length} eindeutige Offers gefunden\n`);
    
    // Speichere JSON
    const result = {
      weekKey,
      year,
      week,
      totalOffers: uniqueOffers.length,
      offers: uniqueOffers,
      extractedAt: new Date().toISOString(),
    };
    
    await fs.writeFile(outputPath, JSON.stringify(result, null, 2), 'utf-8');
    console.log(`💾 JSON gespeichert: ${outputPath}`);
    
    // Zeige erste 5 Offers
    console.log('\n📊 Erste 5 Offers:\n');
    uniqueOffers.slice(0, 5).forEach((offer, i) => {
      console.log(`${i + 1}. ${offer.title}`);
      console.log(`   💰 ${offer.price}€ / ${offer.unit}`);
      if (offer.brand) console.log(`   🏷️  ${offer.brand}`);
      console.log('');
    });
    
  } catch (err) {
    console.error('❌ Fehler:', err.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

main().catch(console.error);

