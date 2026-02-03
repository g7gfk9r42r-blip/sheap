#!/usr/bin/env node
// tools/edeka/fetch_edeka_offers.mjs
// Scraped EDEKA SUPERKNÜLLER-Angebote direkt von edeka.de

import { chromium } from 'playwright';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const EDEKA_URL = 'https://www.edeka.de/angebote/superknueller';

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
 * Extrahiert Preis aus Text
 */
function extractPrice(text) {
  const patterns = [
    /(\d+[.,]\d{2})\s*€/,
    /€\s*(\d+[.,]\d{2})/,
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

/**
 * Extrahiert Rabatt aus Text
 */
function extractDiscount(text) {
  const match = text.match(/-(\d+)%/);
  return match ? match[1] : null;
}

/**
 * Extrahiert Einheit aus Text
 */
function extractUnit(text) {
  const unitPattern = /(\d+(?:[.,]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung|pck|pack|Ausführung)/i;
  const match = text.match(unitPattern);
  if (match) {
    return `${match[1]} ${match[2].toLowerCase()}`;
  }
  return null;
}

/**
 * Extrahiert Originalpreis (Niedrig. Gesamtpreis)
 */
function extractOriginalPrice(text) {
  const match = text.match(/Niedrig\.\s*Gesamtpreis:\s*€\s*([\d.,]+)/i);
  if (match) {
    return parseFloat(match[1].replace(',', '.'));
  }
  return null;
}

/**
 * Hauptfunktion: Scraped EDEKA-Angebote
 */
async function fetchEdekaOffers() {
  console.log(`\n🛒 EDEKA SUPERKNÜLLER Scraper`);
  console.log(`   URL: ${EDEKA_URL}\n`);
  
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  
  try {
    // Navigiere zur Seite
    console.log('🌐 Öffne EDEKA-Website...');
    await page.goto(EDEKA_URL, { waitUntil: 'domcontentloaded', timeout: 60000 });
    
    // Warte auf Cookie-Banner und akzeptiere
    try {
      await page.waitForSelector('button:has-text("Akzeptieren"), button:has-text("Zustimmen"), [id*="accept"], [class*="accept"]', { timeout: 5000 });
      const acceptButton = await page.$('button:has-text("Akzeptieren"), button:has-text("Zustimmen"), [id*="accept"], [class*="accept"]');
      if (acceptButton) {
        await acceptButton.click();
        await page.waitForTimeout(1000);
      }
    } catch {}
    
    // Warte auf Angebote
    await page.waitForTimeout(2000);
    
    // Extrahiere Angebote aus dem DOM
    console.log('🔍 Extrahiere Angebote...');
    
    const offers = await page.evaluate(() => {
      const results = [];
      
      // Suche nach Produkt-Karten/Containern
      // EDEKA nutzt verschiedene Selektoren, probiere mehrere
      const selectors = [
        '[class*="product"]',
        '[class*="offer"]',
        '[class*="angebot"]',
        '[class*="item"]',
        '[data-testid*="product"]',
        'article',
        '.card',
      ];
      
      let elements = [];
      for (const selector of selectors) {
        elements = Array.from(document.querySelectorAll(selector));
        if (elements.length > 5) break; // Wenn wir genug gefunden haben
      }
      
      // Fallback: Suche nach Elementen mit Preisen
      if (elements.length === 0) {
        const allElements = Array.from(document.querySelectorAll('*'));
        elements = allElements.filter(el => {
          const text = el.textContent || '';
          return /\d+[.,]\d{2}\s*€/.test(text) && text.length < 500;
        });
      }
      
      for (const element of elements) {
        const text = (element.textContent || '').trim();
        
        // Prüfe ob es ein Angebot ist (enthält Preis)
        if (!/\d+[.,]\d{2}\s*€/.test(text)) continue;
        if (text.length < 10 || text.length > 1000) continue;
        
        // Extrahiere Bild-URL
        const img = element.querySelector('img');
        const imageUrl = img ? (img.src || img.getAttribute('data-src') || '') : '';
        
        results.push({
          text,
          imageUrl,
        });
      }
      
      return results;
    });
    
    console.log(`   ${offers.length} potenzielle Angebote gefunden`);
    
    // Parse Angebote
    const parsedOffers = [];
    
    for (const offer of offers) {
      const text = offer.text;
      
      const price = extractPrice(text);
      if (!price) continue;
      
      // Extrahiere Titel (alles vor dem Preis, bereinigt)
      let title = text;
      
      // Entferne Preis
      title = title.replace(/\d+[.,]\d{2}\s*€/g, '').trim();
      
      // Entferne SUPERKNÜLLER-Präfix
      title = title.replace(/^SUPERKNÜLLER\s*/i, '').trim();
      
      // Entferne Rabatt-Informationen
      title = title.replace(/\s*-\d+%\s*/g, ' ').trim();
      
      // Entferne "Niedrig. Gesamtpreis" und ähnliches
      title = title.replace(/\s*Niedrig\.\s*Gesamtpreis:\s*€\s*[\d.,]+\s*/gi, '').trim();
      title = title.replace(/\s*1kg\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
      title = title.replace(/\s*1l\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
      title = title.replace(/\s*versch\.\s*Sorten[^,]*/gi, '').trim();
      title = title.replace(/\s*aus\s+[^,]+/gi, '').trim();
      title = title.replace(/\s*Klasse\s+[IVX]+/gi, '').trim();
      
      // Bereinige mehrfache Leerzeichen
      title = title.replace(/\s+/g, ' ').trim();
      
      if (title.length < 3) continue;
      
      const discount = extractDiscount(text);
      const unit = extractUnit(text);
      const originalPrice = extractOriginalPrice(text);
      
      parsedOffers.push({
        title,
        price,
        discount,
        unit,
        originalPrice,
        imageUrl: offer.imageUrl || null,
        rawText: text.substring(0, 200),
      });
    }
    
    // Deduplizierung
    const uniqueOffers = [];
    const seen = new Set();
    
    for (const offer of parsedOffers) {
      const key = `${offer.title.toLowerCase()}|${offer.price}`;
      if (!seen.has(key)) {
        seen.add(key);
        uniqueOffers.push(offer);
      }
    }
    
    console.log(`✅ ${uniqueOffers.length} eindeutige Angebote extrahiert\n`);
    
    // Speichere JSON
    const { year, week, weekKey } = getYearWeek();
    const outputDir = resolve(__dirname, '../../data/edeka', String(year), `W${week}`);
    await fs.mkdir(outputDir, { recursive: true });
    
    const outputPath = join(outputDir, 'offers.json');
    const result = {
      weekKey,
      year,
      week,
      totalOffers: uniqueOffers.length,
      generatedAt: new Date().toISOString(),
      source: 'edeka.de',
      url: EDEKA_URL,
      offers: uniqueOffers,
    };
    
    await fs.writeFile(outputPath, JSON.stringify(result, null, 2), 'utf-8');
    console.log(`✅ JSON gespeichert: ${outputPath}`);
    
    // Zeige erste Angebote
    console.log('\n📋 Erste 10 Angebote:\n');
    uniqueOffers.slice(0, 10).forEach((offer, i) => {
      console.log(`${i + 1}. ${offer.title}`);
      console.log(`   💰 ${offer.price}€${offer.unit ? ` / ${offer.unit}` : ''}`);
      if (offer.discount) console.log(`   🏷️  Rabatt: -${offer.discount}%`);
      if (offer.originalPrice) console.log(`   📊 Original: ${offer.originalPrice}€`);
      console.log('');
    });
    
    return uniqueOffers;
    
  } catch (err) {
    console.error(`\n❌ Fehler:`, err.message);
    throw err;
  } finally {
    await browser.close();
  }
}

// CLI
if (import.meta.url === `file://${process.argv[1]}`) {
  fetchEdekaOffers().catch(err => {
    console.error(err);
    process.exit(1);
  });
}

export { fetchEdekaOffers };

