#!/usr/bin/env node
// tools/leaflets/fetch_lidl_leaflet.mjs
// Sammelt Angebote von Lidl-Prospekten via API-Interception und DOM-Scraping

import { chromium } from 'playwright';
import sharp from 'sharp';
import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';
import { decode as decodeHtml } from 'html-entities';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ============================================================================
// CLI-Argumente & Flags
// ============================================================================

const args = process.argv.slice(2);
const flags = {
  keepImages: args.includes('--keep-images'),
  force: args.includes('--force'),
  captureOnly: args.includes('--capture-only'),
  help: args.includes('--help') || args.includes('-h')
};

if (flags.help) {
  console.log(`
Usage: node fetch_lidl_leaflet.mjs [URL...] [OPTIONS]

Beispiele:
  # Einzelner Prospekt (Standard)
  node fetch_lidl_leaflet.mjs

  # Einzelner Prospekt mit URL
  node fetch_lidl_leaflet.mjs https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1

  # Mehrere Prospekte gleichzeitig
  node fetch_lidl_leaflet.mjs \\
    https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-724fe3/view/flyer/page/1 \\
    https://www.lidl.de/l/prospekte/aktionsprospekt-24-11-2025-29-11-2025-f231da/view/flyer/page/1 \\
    --capture-only

Options:
  --keep-images    Behalte temporäre WebP-Dateien nach PDF-Erstellung
  --force          Überschreibe existierendes PDF
  --capture-only   Nur JSON-Payloads sammeln (keine PDF-Erstellung)
  --help, -h       Zeige diese Hilfe

Environment:
  LIDL_LEAFLET_URL  Lidl Viewer URL (optional, wird ignoriert wenn URLs als Argumente übergeben)
`);
  process.exit(0);
}

// ============================================================================
// Utility-Funktionen
// ============================================================================

/**
 * Berechnet ISO-Kalenderwoche (Montag = Wochenanfang)
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
 * Extrahiert Datum und Woche aus Lidl-URL
 */
function extractWeekFromUrl(url) {
  try {
    const datePattern = /(\d{1,2})-(\d{1,2})-(\d{4})/g;
    const matches = Array.from(url.matchAll(datePattern));
    
    if (matches.length >= 1) {
      const firstMatch = matches[0];
      const day = parseInt(firstMatch[1], 10);
      const month = parseInt(firstMatch[2], 10) - 1;
      const year = parseInt(firstMatch[3], 10);
      
      const date = new Date(Date.UTC(year, month, day));
      return getYearWeek(date);
    }
  } catch (err) {
    // Fallback zu aktueller Woche
  }
  
  return getYearWeek();
}

/**
 * Extrahiert Prospekt-ID aus URL
 */
function extractLeafletId(url) {
  try {
    const match = url.match(/aktionsprospekt-[^/]+-([a-f0-9]+)/);
    if (match && match[1]) {
      return match[1];
    }
    const parts = url.split('/');
    const lastPart = parts[parts.length - 1];
    return lastPart.split('?')[0].replace(/[^a-z0-9]/gi, '_').substring(0, 20);
  } catch {
    return 'unknown';
  }
}

/**
 * Dekodiert HTML-Entities
 */
function decodeHtmlEntities(text = '') {
  if (!text) return '';
  return decodeHtml(text);
}

/**
 * Entfernt HTML-Tags und normalisiert Text
 */
function stripHtml(text = '') {
  if (!text) return '';
  const withoutStyle = text
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, ' ');
  const stripped = withoutStyle.replace(/<[^>]*>/g, ' ');
  const decoded = decodeHtmlEntities(stripped);
  return decoded.replace(/\s+/g, ' ').trim();
}

/**
 * Konvertiert Wert zu Array
 */
function toArray(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === 'object') return Object.values(value).filter(Boolean);
  return [value];
}

/**
 * Parst Preis aus verschiedenen Formaten
 */
function parsePrice(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return value;
  if (typeof value === 'string') {
    const normalized = value.replace(/[^\d.,-]/g, '').replace(',', '.');
    const parsed = parseFloat(normalized);
    return Number.isFinite(parsed) ? parsed : null;
  }
  if (typeof value === 'object' && value.value !== undefined) {
    return parsePrice(value.value);
  }
  return null;
}

/**
 * Extrahiert Produkt-ID aus URL
 */
function extractProductIdFromUrl(url = '') {
  if (!url) return null;
  const directMatch = url.match(/p(\d{6,})/i);
  if (directMatch) return directMatch[1];
  try {
    const u = new URL(url);
    if (u.searchParams.has('productId')) {
      return u.searchParams.get('productId');
    }
  } catch {}
  return null;
}

/**
 * Extrahiert Seitennummer aus URL
 */
function extractPageNumber(url) {
  const patterns = [
    /(?:page[_-]?|p[=_-]?)(\d{1,3})/i,
    /\/(\d{1,3})\.webp/i,
    /[_-](\d{1,3})(?:\.[a-z]+)?$/i,
    /(\d{1,3})(?:\.[a-z]+)?$/i
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

// ============================================================================
// Network-Interception & Filter
// ============================================================================

/**
 * Prüft ob eine URL ein Lidl-Prospektbild ist
 */
function isLeafletImage(url, contentType = '') {
  if (!url) return false;
  try {
    const urlObj = new URL(url);
    const isSchwarzDomain = urlObj.hostname.includes('leaflets.schwarz');
    if (!isSchwarzDomain) return false;
    
    const isImagePath = urlObj.pathname.includes('/assets/images/') || 
                        urlObj.pathname.includes('/images/') ||
                        urlObj.pathname.match(/\.(webp|jpg|jpeg|png)(\?|$)/i);
    
    const isWebP = contentType.includes('image/webp') || 
                   contentType.includes('image/') ||
                   urlObj.pathname.match(/\.(webp|jpg|jpeg|png)(\?|$)/i);
    
    return isImagePath && isWebP;
  } catch {
    return false;
  }
}

/**
 * Prüft ob eine Response als Offer-Payload erfasst werden soll
 */
function shouldCaptureOfferPayload(url, contentType = '') {
  if (!contentType.includes('application/json')) {
    return false;
  }
  
  const lowerUrl = url.toLowerCase();
  
  // Alle Lidl-API-Endpoints erfassen (auch seitenweise Calls)
  if (lowerUrl.includes('endpoints.leaflets.schwarz')) {
    // Haupt-Flyer-Endpoint
    if (lowerUrl.includes('/v4/flyer')) {
      return true;
    }
    // Seitenweise Endpoints
    if (lowerUrl.includes('/pages/') || lowerUrl.includes('/page/')) {
      return true;
    }
    // Produkt-Endpoints
    if (lowerUrl.includes('/products') || lowerUrl.includes('/offers')) {
      return true;
    }
    // Weitere mögliche Endpoints
    if (lowerUrl.includes('/api/') || lowerUrl.includes('/v4/')) {
      return true;
    }
  }
  
  return false;
}

// ============================================================================
// DOM-Scraping
// ============================================================================

/**
 * Scraped Produkte direkt aus dem DOM
 */
async function scrapeOffersFromDOM(page) {
  if (process.env.DEBUG) {
    console.log('\n🔍 Scrape Produkte direkt aus dem DOM...');
  }
  
  try {
    const offers = await page.evaluate(() => {
      const scrapedOffers = [];
      const seen = new Set();
      
      // Lidl verwendet Canvas/SVG-basierte Viewer
      // Suche nach interaktiven Hotspot-Elementen
      const selectors = [
        '[data-testid*="product"]',
        '[data-testid*="offer"]',
        '[data-testid*="hotspot"]',
        '[data-product]',
        'a[href*="/p/"]',
        '.product-hotspot',
        '.offer-hotspot',
        '[role="button"][aria-label*="produkt" i]'
      ];
      
      for (const selector of selectors) {
        try {
          const elements = document.querySelectorAll(selector);
          
          for (const el of elements) {
            try {
              const dataProduct = el.getAttribute('data-product');
              const dataOffer = el.getAttribute('data-offer');
              
              let productData = null;
              if (dataProduct) {
                try {
                  productData = JSON.parse(dataProduct);
                } catch {}
              }
              if (!productData && dataOffer) {
                try {
                  productData = JSON.parse(dataOffer);
                } catch {}
              }
              
              if (productData && productData.id) {
                if (seen.has(productData.id)) continue;
                seen.add(productData.id);
                
                scrapedOffers.push({
                  id: productData.id,
                  title: productData.title || productData.name || '',
                  price: productData.price || null,
                  originalPrice: productData.originalPrice || productData.strokePrice || null,
                  brand: productData.brand || '',
                  url: productData.url || null,
                  imageUrl: productData.image || productData.imageUrl || null,
                  description: productData.description || '',
                  source: 'dom-scraping-data-attributes'
                });
              }
            } catch {}
          }
        } catch {}
      }
      
      return scrapedOffers;
    });
    
    if (process.env.DEBUG && offers.length > 0) {
      console.log(`   ✅ ${offers.length} Produkte aus DOM gescraped`);
    }
    return offers;
  } catch (err) {
    if (process.env.DEBUG) {
      console.error(`   ⚠️  Fehler beim DOM-Scraping:`, err.message);
    }
    return [];
  }
}

// ============================================================================
// JSON-Payload-Verarbeitung
// ============================================================================

/**
 * Baut Map von Produkt-ID zu Seitennummer
 */
function buildPageProductMap(pages = []) {
  const map = new Map();
  for (const page of pages) {
    const pageNumber = page?.number ?? null;
    const links = page?.links || [];
    for (const link of links) {
      const productId = extractProductIdFromUrl(link?.url);
      if (productId && pageNumber !== null && !map.has(productId)) {
        map.set(productId, pageNumber);
      }
    }
  }
  return map;
}

/**
 * Extrahiert Angebote aus JSON-Payloads
 */
function extractOffersFromJsonPayloads(payloads = [], meta = {}) {
  const allFlyers = [];
  const allProducts = {};
  const allPages = [];
  const allArticles = [];
  
  console.log(`\n🔍 Analysiere ${payloads.length} JSON-Payloads...`);
  
  for (let i = 0; i < payloads.length; i++) {
    const payload = payloads[i];
    try {
      const data = JSON.parse(payload.body);
      
      // Struktur 1: flyer.products (Standard)
      if (data?.flyer) {
        allFlyers.push(data.flyer);
        
        if (data.flyer.products) {
          const productCount = Object.keys(data.flyer.products).length;
          Object.assign(allProducts, data.flyer.products);
          if (productCount > 0) {
            console.log(`   📦 Payload ${i + 1}: ${productCount} Produkte gefunden (flyer.products)`);
          }
        }
        
        if (data.flyer.pages && Array.isArray(data.flyer.pages)) {
          allPages.push(...data.flyer.pages);
        }
      }
      
      // Struktur 2: articles
      if (data?.articles && Array.isArray(data.articles)) {
        allArticles.push(...data.articles);
        if (data.articles.length > 0) {
          console.log(`   📦 Payload ${i + 1}: ${data.articles.length} Artikel gefunden`);
        }
      }
      
      // Struktur 3: data.products (direkt)
      if (data?.products && typeof data.products === 'object') {
        Object.assign(allProducts, data.products);
        const productCount = Object.keys(data.products).length;
        if (productCount > 0) {
          console.log(`   📦 Payload ${i + 1}: ${productCount} Produkte (direkt) gefunden`);
        }
      }
      
      // Struktur 4: data.items
      if (data?.items && Array.isArray(data.items)) {
        for (const item of data.items) {
          if (item?.id || item?.productId) {
            const id = item.id || item.productId;
            allProducts[id] = item;
          }
        }
        if (data.items.length > 0) {
          console.log(`   📦 Payload ${i + 1}: ${data.items.length} Items gefunden`);
        }
      }
      
    } catch (err) {
      // Ignoriere Parse-Fehler (HTML-Responses etc.)
    }
  }
  
  // Konvertiere articles zu products-Format
  if (allArticles.length > 0 && Object.keys(allProducts).length === 0) {
    console.log(`   🔄 Konvertiere ${allArticles.length} Artikel zu Produkten...`);
    for (const article of allArticles) {
      const id = article.id || article.productId || `article_${allArticles.indexOf(article)}`;
      allProducts[id] = article;
    }
  }
  
  const totalProducts = Object.keys(allProducts).length;
  const totalPages = allPages.length > 0 ? allPages.length : (allFlyers[0]?.pages?.length || 0);
  
  console.log(`   ✅ Gesamt: ${totalProducts} Produkte, ${totalPages} Seiten`);
  
  if (totalProducts > 0 || totalPages > 0) {
    const baseFlyer = allFlyers[0] || {};
    const combinedFlyer = {
      ...baseFlyer,
      products: allProducts,
      pages: allPages.length > 0 ? allPages : baseFlyer.pages || []
    };
    
    return transformFlyerToOffers(combinedFlyer, meta);
  }
  
  console.log('   ⚠️  Keine Produkte in Payloads gefunden');
  return null;
}

/**
 * Transformiert Flyer-Daten zu strukturierten Offers
 * Extrahiert auch Produkte aus Seiten-Links, die nicht in der products Map sind
 */
function transformFlyerToOffers(flyer, meta = {}) {
  const { year, week, weekKey } = meta;
  const products = flyer?.products || {};
  const pages = flyer?.pages || [];
  const pageMap = buildPageProductMap(pages);
  const defaultValidFrom = flyer?.offerStartDate || flyer?.startDate || flyer?.validFromDate || null;
  const defaultValidTo = flyer?.offerEndDate || flyer?.endDate || flyer?.validToDate || null;

  const offers = [];
  const seen = new Set();

  // Schritt 1: Produkte aus products Map extrahieren
  for (const value of Object.values(products)) {
    const productId = value?.productId || value?.id;
    if (!productId || seen.has(productId)) continue;
    seen.add(productId);

    const price = parsePrice(value?.price);
    const originalPrice = parsePrice(value?.strokePrice);

    const offer = {
      id: productId,
      retailer: 'LIDL',
      title: stripHtml(value?.title || value?.name || ''),
      description: stripHtml(value?.description || ''),
      price,
      priceText: value?.priceText || null,
      originalPrice,
      discountText: value?.discountText || null,
      url: value?.url || null,
      imageUrl: value?.image || null,
      brand: stripHtml(value?.brand || ''),
      categories: toArray(value?.categoryPrimary || value?.category || value?.wonCategoryPrimary).map(stripHtml),
      campaigns: toArray(value?.campaigns).map(stripHtml),
      validFrom: value?.validFromDate || defaultValidFrom,
      validTo: value?.validToDate || defaultValidTo,
      currency: value?.currencySymbol || value?.currencyText || '€',
      basicPrice: value?.basicPrice || null,
      unit: value?.priceText || null,
      erpNumber: value?.erpNumber || null,
      page: pageMap.get(productId) || null,
      raw: {
        key: value?.key || null
      }
    };

    offers.push(offer);
  }

  // Schritt 2: Produkte aus Seiten-Links extrahieren (die nicht in products Map sind)
  const linkOffers = [];
  const productUrlsFromLinks = new Set();
  
  for (const page of pages) {
    const pageNumber = page?.number ?? null;
    const links = page?.links || [];
    
    for (const link of links) {
      const linkUrl = link?.url || '';
      const linkDisplayType = link?.displayType || '';
      
      // Nur echte Produkt-Links (nicht Rezepte, externe Links, etc.)
      if (linkDisplayType === 'recipe' || linkDisplayType === 'external' || linkUrl.includes('lidl-kochen.de')) {
        continue;
      }
      
      // Sammle alle Produkt-URLs (auch die ohne /p/ - könnten andere Formate sein)
      if (linkUrl.includes('lidl.de/p/') || linkUrl.includes('/p/')) {
        productUrlsFromLinks.add(linkUrl);
      }
      
      // Extrahiere Produkt-ID aus URL
      const productId = extractProductIdFromUrl(linkUrl);
      if (!productId) continue;
      
      // Prüfe ob Produkt bereits in products Map ist
      if (seen.has(productId)) continue;
      
      // Prüfe ob Produkt in products Map existiert (auch wenn nicht in seen)
      const existingProduct = Object.values(products).find(p => 
        (p.productId || p.id) === productId
      );
      
      if (existingProduct) {
        // Produkt existiert bereits, überspringe
        continue;
      }
      
      // Neues Produkt aus Link erstellen
      const linkTitle = stripHtml(link?.title || '');
      
      linkOffers.push({
        id: productId,
        retailer: 'LIDL',
        title: linkTitle || `Produkt ${productId}`,
        description: '',
        price: null, // Preis nicht in Link verfügbar
        priceText: null,
        originalPrice: null,
        discountText: null,
        url: linkUrl,
        imageUrl: null,
        brand: '',
        categories: [],
        campaigns: [],
        validFrom: defaultValidFrom,
        validTo: defaultValidTo,
        currency: '€',
        basicPrice: null,
        unit: null,
        erpNumber: productId.replace(/[^0-9]/g, '') || null,
        page: pageNumber,
        raw: {
          source: 'page-link',
          linkId: link?.id || null,
          displayType: linkDisplayType
        }
      });
      
      seen.add(productId);
    }
  }
  
  if (linkOffers.length > 0) {
    console.log(`   📦 ${linkOffers.length} zusätzliche Produkte aus Seiten-Links extrahiert`);
    offers.push(...linkOffers);
  }
  
  if (productUrlsFromLinks.size > 0) {
    console.log(`   🔗 ${productUrlsFromLinks.size} eindeutige Produkt-URLs in Links gefunden`);
  }

  return {
    weekKey,
    year,
    week,
    flyerId: flyer?.id || null,
    title: flyer?.title || flyer?.name || null,
    startDate: defaultValidFrom,
    endDate: defaultValidTo,
    totalOffers: offers.length,
    generatedAt: new Date().toISOString(),
    source: 'flyer-api',
    offers
  };
}

// ============================================================================
// Browser-Interaktion
// ============================================================================

/**
 * Scrollt die gesamte Seite durch (triggert Lazy-Loading)
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
    
    // Prüfe ob neue Bilder geladen wurden
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
    
    // Versuche Next-Button zu finden und zu klicken
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
    
    // Progress-Anzeige
    if (i % 5 === 0 || i < 10) {
      process.stdout.write(`\r📖 Durchblättert: ${i + 1}... (${currentImageCount} Bilder)`);
    }
    
    // Stoppe wenn mehrere Versuche fehlschlagen
    if (consecutiveFailures >= maxFailures) {
      console.log(`\n⚠️  Keine weiteren Seiten nach ${i + 1} Versuchen`);
      break;
    }
  }
  console.log(`\n✅ Durchblättern abgeschlossen (${imageUrls.size} Bilder)`);
}

/**
 * Schließt Consent/Overlay-Dialoge
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

// ============================================================================
// Daten-Kombination & Validierung
// ============================================================================

/**
 * Kombiniert API- und DOM-gescraped Offers
 */
function combineOffers(apiOffers = [], domOffers = [], meta = {}) {
  console.log(`\n🔗 Kombiniere API- und DOM-Daten...`);
  
  const allOffersMap = new Map();
  
  // Füge API-Offers hinzu
  for (const offer of apiOffers) {
    const key = offer.id || `${offer.title}_${offer.price}`;
    if (!allOffersMap.has(key)) {
      allOffersMap.set(key, {
        ...offer,
        sources: ['api']
      });
    } else {
      const existing = allOffersMap.get(key);
      if (!existing.sources.includes('api')) {
        existing.sources.push('api');
      }
    }
  }
  
  // Füge DOM-gescraped Offers hinzu
  for (const domOffer of domOffers) {
    const key = domOffer.id || `${domOffer.title}_${domOffer.price}`;
    
    // Versuche Match mit API-Offer
    let matched = false;
    for (const [existingKey, existingOffer] of allOffersMap.entries()) {
      // Match nach ID
      if (domOffer.id && existingOffer.id === domOffer.id) {
        if (!existingOffer.sources.includes('dom')) {
          existingOffer.sources.push('dom');
        }
        // Ergänze fehlende Daten aus DOM
        if (!existingOffer.url && domOffer.url) existingOffer.url = domOffer.url;
        if (!existingOffer.imageUrl && domOffer.imageUrl) existingOffer.imageUrl = domOffer.imageUrl;
        matched = true;
        break;
      }
      // Match nach Titel und Preis (fuzzy)
      if (domOffer.title && existingOffer.title && 
          domOffer.title.toLowerCase().includes(existingOffer.title.toLowerCase().substring(0, 20)) &&
          Math.abs((domOffer.price || 0) - (existingOffer.price || 0)) < 0.01) {
        if (!existingOffer.sources.includes('dom')) {
          existingOffer.sources.push('dom');
        }
        matched = true;
        break;
      }
    }
    
    // Neues Offer hinzufügen wenn nicht gematcht
    if (!matched) {
      allOffersMap.set(key, {
        id: domOffer.id,
        retailer: 'LIDL',
        title: domOffer.title,
        description: domOffer.description || '',
        price: domOffer.price,
        priceText: null,
        originalPrice: domOffer.originalPrice,
        discountText: null,
        url: domOffer.url,
        imageUrl: domOffer.imageUrl,
        brand: domOffer.brand || '',
        categories: [],
        campaigns: [],
        validFrom: meta.startDate || null,
        validTo: meta.endDate || null,
        currency: '€',
        basicPrice: null,
        unit: null,
        erpNumber: domOffer.id?.replace(/[^0-9]/g, '') || null,
        page: null,
        raw: { source: 'dom-scraping' },
        sources: ['dom']
      });
    }
  }
  
  const combinedOffers = Array.from(allOffersMap.values());
  
  console.log(`   📊 API-Offers: ${apiOffers.length}`);
  console.log(`   📊 DOM-Offers: ${domOffers.length}`);
  console.log(`   📊 Kombiniert (dedupliziert): ${combinedOffers.length}`);
  
  return combinedOffers;
}

/**
 * Validiert die Anzahl gefundener Offers
 */
function validateOffers(foundOffers, imageCount) {
  const expectedMinOffers = Math.max(1, Math.floor(imageCount * 0.3));
  
  console.log(`\n📊 Validierung:`);
  console.log(`   📄 Seiten (Bilder): ${imageCount}`);
  console.log(`   📦 Gefundene Angebote: ${foundOffers}`);
  console.log(`   📈 Erwartete Mindestanzahl: ~${expectedMinOffers}`);
  
  if (foundOffers < expectedMinOffers && imageCount > 10) {
    console.log(`\n⚠️  Warnung: Nur ${foundOffers} Angebote gefunden, erwartet wurden mindestens ~${expectedMinOffers}`);
    console.log(`   💡 Mögliche Ursachen:`);
    console.log(`      - Nicht alle Seiten wurden durchgeblättert`);
    console.log(`      - API liefert nicht alle Produkte`);
    console.log(`      - Produkte sind in anderen Payload-Strukturen`);
    return false;
  } else {
    console.log(`   ✅ Anzahl der Angebote erscheint plausibel`);
    return true;
  }
}

// ============================================================================
// PDF-Erstellung
// ============================================================================

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
        throw new Error('Bild zu klein (möglicherweise Fehler-HTML)');
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

  // Cleanup
  if (!flags.keepImages) {
    console.log('\n🧹 Lösche temporäre WebP-Dateien...');
    for (const imagePath of imageFiles) {
      try {
        await fs.unlink(imagePath);
      } catch {}
    }
  }

  const fileSizeMB = (pdfBytes.length / 1024 / 1024).toFixed(2);
  console.log(`\n✅ PDF erfolgreich erstellt!`);
  console.log(`   Pfad: ${pdfPath}`);
  console.log(`   Größe: ${fileSizeMB} MB`);
  console.log(`   Seiten: ${imageFiles.length}`);
  
  if (flags.keepImages) {
    console.log(`   ℹ️  WebP-Dateien beibehalten (--keep-images)`);
  }
}

// ============================================================================
// Haupt-Funktion: Prospekt verarbeiten
// ============================================================================

/**
 * Verarbeitet eine einzelne Lidl-Viewer-URL
 */
async function processLeafletUrl(lidlUrl, options = {}) {
  const startTime = Date.now();
  const { leafletId = null } = options;
  
  const { year, week, weekKey } = extractWeekFromUrl(lidlUrl);
  const id = leafletId || extractLeafletId(lidlUrl);
  
  console.log(`\n📋 Prospekt: ${id}`);
  console.log(`📅 Kalenderwoche: ${weekKey}`);
  console.log(`🔗 URL: ${lidlUrl}\n`);

  const baseDir = resolve(__dirname, '../../media/prospekte/lidl', String(year), `W${week}`, id);
  const dataDir = resolve(__dirname, '../../data/lidl', String(year), `W${week}`);
  // PDF direkt in media/prospekte/lidl/ speichern
  const lidlMediaDir = resolve(__dirname, '../../media/prospekte/lidl');
  const pdfPath = join(lidlMediaDir, `lidl_${weekKey}.pdf`);
  const rawJsonDir = join(baseDir, '__raw_json');
  const offersOutputPath = join(dataDir, `offers_${id}.json`);
  const offersDebugPath = join(baseDir, 'offers.network.json');

  // Prüfe ob PDF bereits existiert
  if (!flags.captureOnly && !flags.force) {
    try {
      await fs.access(pdfPath);
      console.log(`ℹ️  PDF bereits vorhanden: ${pdfPath}`);
      console.log(`   Verwende --force zum Überschreiben`);
      return { skipped: true, pdfPath };
    } catch {}
  }

  await fs.mkdir(baseDir, { recursive: true });
  await fs.mkdir(dataDir, { recursive: true });
  await fs.mkdir(lidlMediaDir, { recursive: true });

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
  await fs.mkdir(rawJsonDir, { recursive: true });

  // Daten-Sammlung
  const imageUrls = new Map();
  const jsonPayloads = [];

  // Network-Interception
  page.on('response', async (response) => {
    try {
      const url = response.url();
      const contentType = response.headers()['content-type'] || '';
      const contentLength = parseInt(response.headers()['content-length'] || '0', 10);

      if (process.env.DEBUG && url.includes('leaflets.schwarz')) {
        console.log(`\n🔍 Debug: ${url} (${contentType})`);
      }

      // Sammle Bilder
      if (url.includes('imgproxy.leaflets.schwarz') && 
          (contentType.includes('image/') || url.match(/\.(webp|jpg|jpeg|png)(\?|$)/i))) {
        if (!imageUrls.has(url)) {
          imageUrls.set(url, { contentType, url, size: contentLength });
          process.stdout.write(`\r📥 Bilder gefunden: ${imageUrls.size}`);
        }
      }

      // Sammle JSON-Payloads
      if (shouldCaptureOfferPayload(url, contentType)) {
        try {
          const textBody = await response.text();
          if (textBody && textBody.length > 20) {
            jsonPayloads.push({
              url,
              capturedAt: new Date().toISOString(),
              body: textBody
            });
            process.stdout.write(`\r🗂️  JSON-Payloads: ${jsonPayloads.length}`);
          }
        } catch (jsonErr) {
          if (process.env.DEBUG) {
            console.error('\n⚠️  Fehler beim JSON-Capture:', jsonErr.message);
          }
        }
      }
    } catch {}
  });

  // Seite laden
  try {
    await page.goto(lidlUrl, { waitUntil: 'domcontentloaded', timeout: 90000 });
    await page.waitForLoadState('networkidle', { timeout: 30000 }).catch(() => {
      if (process.env.DEBUG) {
        console.log('⚠️  Network-Idle nicht erreicht, fahre fort...');
      }
    });
  } catch (err) {
    try {
      console.log('⚠️  Erster Ladeversuch fehlgeschlagen, versuche erneut...');
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
  
  // Durch alle Seiten blättern (erfasst alle API-Calls)
  await clickThroughAllPages(page, imageUrls, 50);
  
  await page.waitForTimeout(2000);
  
  // Zusätzlich: Explizit jede Seite aufrufen, um seitenweise API-Calls zu triggern
  console.log('\n🔄 Rufe jede Seite explizit auf, um alle API-Calls zu erfassen...');
  const initialPayloadCount = jsonPayloads.length;
  
  // Versuche zur ersten Seite zurückzugehen
  try {
    await page.goto(lidlUrl, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForTimeout(2000);
    await closeConsentDialogs(page);
  } catch {}
  
  // Durch alle Seiten gehen und warten, damit API-Calls geladen werden
  for (let pageNum = 1; pageNum <= 35; pageNum++) {
    // Versuche zur nächsten Seite zu gehen
    let clicked = false;
    const nextSelectors = [
      'button[aria-label*="weiter" i]',
      'button[title*="weiter" i]',
      '.slick-next',
      '.swiper-button-next'
    ];
    
    for (const selector of nextSelectors) {
      try {
        const btn = await page.$(selector);
        if (btn && await btn.isVisible().catch(() => false)) {
          await btn.click({ delay: 100 });
          clicked = true;
          break;
        }
      } catch {}
    }
    
    if (!clicked) break;
    
    // Warte auf API-Calls (länger als normal)
    await page.waitForTimeout(2500);
    
    // Scrollen um Lazy-Loading zu triggern
    await page.evaluate(() => {
      window.scrollTo(0, document.body.scrollHeight);
    });
    await page.waitForTimeout(500);
    await page.evaluate(() => {
      window.scrollTo(0, 0);
    });
    await page.waitForTimeout(500);
    
    if (pageNum % 5 === 0) {
      const newPayloads = jsonPayloads.length - initialPayloadCount;
      process.stdout.write(`\r   Seite ${pageNum}... (+${newPayloads} Payloads)`);
    }
  }
  
  const newPayloads = jsonPayloads.length - initialPayloadCount;
  if (newPayloads > 0) {
    console.log(`\n   ✅ ${newPayloads} zusätzliche Payloads durch explizites Durchblättern erfasst`);
  }

  // DOM-Scraping
  const domScrapedOffers = await scrapeOffersFromDOM(page);

  await browser.close();

  // JSON-Payloads speichern
  if (jsonPayloads.length > 0) {
    console.log(`\n🗂️  Speichere ${jsonPayloads.length} JSON-Payloads...`);
    for (let i = 0; i < jsonPayloads.length; i++) {
      const payload = jsonPayloads[i];
      const fileName = `payload_${String(i + 1).padStart(3, '0')}.json`;
      const targetPath = join(rawJsonDir, fileName);
      await fs.writeFile(targetPath, payload.body);
    }
    console.log(`   Raw JSON gespeichert in ${rawJsonDir}`);
  } else {
    console.log('\n⚠️  Keine JSON-Payloads gefunden.');
  }

  // Offers extrahieren
  let extractedOffers = null;
  if (jsonPayloads.length > 0) {
    extractedOffers = extractOffersFromJsonPayloads(jsonPayloads, { year, week, weekKey });
    
    if (extractedOffers && extractedOffers.totalOffers > 0) {
      // Validierung
      validateOffers(extractedOffers.totalOffers, imageUrls.size);
      
      // Kombiniere API- und DOM-Daten
      const apiOffers = extractedOffers.offers || [];
      const combinedOffers = combineOffers(apiOffers, domScrapedOffers, {
        startDate: extractedOffers.startDate,
        endDate: extractedOffers.endDate
      });
      
      // Aktualisiere extractedOffers
      extractedOffers.offers = combinedOffers;
      extractedOffers.totalOffers = combinedOffers.length;
      extractedOffers.sources = {
        api: apiOffers.length,
        dom: domScrapedOffers.length,
        combined: combinedOffers.length
      };
      
      // Speichern
      await fs.writeFile(offersOutputPath, JSON.stringify(extractedOffers, null, 2));
      await fs.writeFile(offersDebugPath, JSON.stringify(extractedOffers, null, 2));
      console.log(`\n📦 ${extractedOffers.totalOffers} Angebote gespeichert: ${offersOutputPath}`);
    } else {
      console.log('\n⚠️  Konnte keine Angebote aus den JSON-Payloads extrahieren.');
      console.log(`   🔍 Prüfe die Raw JSON-Dateien in: ${rawJsonDir}`);
      
      // Fallback: Nur DOM-Offers
      if (domScrapedOffers.length > 0) {
        console.log(`\n💡 Nutze ${domScrapedOffers.length} DOM-gescraped Offers als Fallback...`);
        extractedOffers = {
          weekKey,
          year,
          week,
          flyerId: null,
          title: null,
          startDate: null,
          endDate: null,
          totalOffers: domScrapedOffers.length,
          generatedAt: new Date().toISOString(),
          source: 'dom-scraping-only',
          offers: domScrapedOffers.map(offer => ({
            ...offer,
            retailer: 'LIDL',
            sources: ['dom']
          }))
        };
        await fs.writeFile(offersOutputPath, JSON.stringify(extractedOffers, null, 2));
        console.log(`📦 ${extractedOffers.totalOffers} DOM-gescraped Offers gespeichert`);
      } else {
        extractedOffers = { offers: [], totalOffers: 0 };
      }
    }
  } else {
    console.log('\n⚠️  Keine JSON-Payloads gefunden!');
    
    // Fallback: Nur DOM-Offers
    if (domScrapedOffers.length > 0) {
      console.log(`\n💡 Nutze ${domScrapedOffers.length} DOM-gescraped Offers als Fallback...`);
      extractedOffers = {
        weekKey,
        year,
        week,
        flyerId: null,
        title: null,
        startDate: null,
        endDate: null,
        totalOffers: domScrapedOffers.length,
        generatedAt: new Date().toISOString(),
        source: 'dom-scraping-only',
        offers: domScrapedOffers.map(offer => ({
          ...offer,
          retailer: 'LIDL',
          sources: ['dom']
        }))
      };
      await fs.writeFile(offersOutputPath, JSON.stringify(extractedOffers, null, 2));
      console.log(`📦 ${extractedOffers.totalOffers} DOM-gescraped Offers gespeichert`);
    } else {
      extractedOffers = { offers: [], totalOffers: 0 };
    }
  }

  const offers = extractedOffers?.offers || [];

  // PDF-Erstellung (wenn nicht capture-only)
  if (flags.captureOnly) {
    console.log('\n⏹️  Capture-Only Mode aktiv: PDF-Erstellung übersprungen.');
    return {
      success: true,
      leafletId: id,
      weekKey,
      offersPath: offersOutputPath,
      pdfPath: null,
      offersCount: offers.length
    };
  }

  // PDF erstellen
  if (imageUrls.size > 0) {
    await createPdfFromImages(imageUrls, pdfPath, lidlUrl);
  } else {
    console.log('\n⚠️  Keine Bilder gefunden, PDF kann nicht erstellt werden.');
  }

  const duration = ((Date.now() - startTime) / 1000).toFixed(1);
  console.log(`\n✅ Fertig! Dauer: ${duration}s`);
  console.log(`   📦 ${offers.length} Angebote`);
  if (!flags.captureOnly) {
    console.log(`   📄 PDF: ${pdfPath}`);
  }
  
  return {
    success: true,
    leafletId: id,
    weekKey,
    offersPath: offersOutputPath,
    pdfPath: flags.captureOnly ? null : pdfPath,
    offersCount: offers.length
  };
}

// ============================================================================
// Main-Funktion
// ============================================================================

/**
 * Hauptfunktion: Verarbeitet eine oder mehrere URLs
 */
async function main() {
  const startTime = Date.now();
  
  // URLs sammeln
  const urlsFromArgs = args.filter(arg => 
    !arg.startsWith('--') && arg.startsWith('http')
  );
  
  let urls = [];
  if (urlsFromArgs.length > 0) {
    urls = urlsFromArgs;
  } else if (process.env.LIDL_LEAFLET_URL) {
    urls = [process.env.LIDL_LEAFLET_URL];
  } else {
    urls = ['https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1'];
  }
  
  console.log(`🚀 Verarbeite ${urls.length} Prospekt(e)...\n`);
  
  const results = [];
  const allOffers = [];
  
  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    console.log(`\n${'='.repeat(60)}`);
    console.log(`📦 Prospekt ${i + 1}/${urls.length}`);
    console.log(`${'='.repeat(60)}`);
    
    try {
      const result = await processLeafletUrl(url, {
        leafletId: null
      });
      
      if (!result.skipped) {
        results.push(result);
        
        // Lade Offers für Zusammenführung
        try {
          const offersData = JSON.parse(await fs.readFile(result.offersPath, 'utf8'));
          if (offersData.offers && Array.isArray(offersData.offers)) {
            allOffers.push(...offersData.offers);
          }
        } catch (err) {
          console.error(`⚠️  Konnte Offers nicht laden: ${err.message}`);
        }
      }
    } catch (err) {
      console.error(`\n❌ Fehler bei Prospekt ${i + 1}:`, err.message);
      if (process.env.DEBUG) {
        console.error(err.stack);
      }
    }
  }
  
  // Zusammenführen aller Offers (wenn mehrere Prospekte)
  if (allOffers.length > 0 && urls.length > 1) {
    const { year, week, weekKey } = extractWeekFromUrl(urls[0]);
    const dataDir = resolve(__dirname, '../../data/lidl', String(year), `W${week}`);
    const mergedPath = join(dataDir, 'offers.json');
    
    // Deduplizierung
    const uniqueOffers = [];
    const seen = new Set();
    for (const offer of allOffers) {
      const key = `${offer.id || offer.erpNumber || offer.title}|${offer.price}`;
      if (!seen.has(key)) {
        seen.add(key);
        uniqueOffers.push(offer);
      }
    }
    
    const mergedData = {
      weekKey,
      extractedAt: new Date().toISOString(),
      sources: urls.map((url, idx) => ({
        url,
        id: extractLeafletId(url),
        offersFile: results[idx]?.offersPath || null
      })),
      totalOffers: uniqueOffers.length,
      offers: uniqueOffers
    };
    
    await fs.mkdir(dataDir, { recursive: true });
    await fs.writeFile(mergedPath, JSON.stringify(mergedData, null, 2));
    
    console.log(`\n${'='.repeat(60)}`);
    console.log(`✅ ZUSAMMENFASSUNG`);
    console.log(`${'='.repeat(60)}`);
    console.log(`📅 Woche: ${weekKey}`);
    console.log(`📦 Prospekte verarbeitet: ${results.length}/${urls.length}`);
    console.log(`🎯 Gesamt-Angebote: ${uniqueOffers.length} (nach Deduplizierung)`);
    console.log(`💾 Zusammenführung: ${mergedPath}`);
    console.log(`⏱️  Gesamtdauer: ${((Date.now() - startTime) / 1000).toFixed(1)}s`);
  } else if (results.length === 1) {
    console.log(`\n✅ Fertig! ${results[0].offersCount} Angebote in ${results[0].offersPath}`);
  }
}

// ============================================================================
// Entry Point
// ============================================================================

main().catch(err => {
  console.error('\n❌ Fehler beim Abrufen des Lidl-Prospekts:', err.message);
  if (process.env.DEBUG) {
    console.error(err.stack);
  }
  process.exit(1);
});
