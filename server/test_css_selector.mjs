#!/usr/bin/env node
/**
 * Test-Script für CSS-Selector-basierte Extraktion via Crawl4AI
 * Testet verschiedene CSS-Selectors um Produkte auf Lidl-Seiten zu finden
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

dotenv.config();
dotenv.config({ path: resolve(__dirname, '.env.local'), override: false });

const BASE_URL = process.env.CRAWL4AI_BASE_URL?.trim();
const TOKEN = process.env.CRAWL4AI_TOKEN?.trim();

if (!BASE_URL) {
  console.error('❌ Keine Base URL gesetzt (CRAWL4AI_BASE_URL).');
  process.exit(1);
}

const LIDL_URL = 'https://www.lidl.de/l/prospekte/latest-leaflet-f5771509-f19a-11e9-b196-005056ab0fb6/view/flyer/page/1';
const crawlEndpoint = `${BASE_URL.replace(/\/+$/, '')}/crawl`;

// Helper: Extrahiere Feld aus HTML
function extractField(html, contextMatch, selectors) {
  // Vereinfachte Extraktion - suche nach Text in der Nähe des Matches
  const matchIndex = html.indexOf(contextMatch);
  if (matchIndex === -1) return null;
  
  const snippet = html.substring(matchIndex, matchIndex + 2000);
  
  // Suche nach Preis-Pattern
  if (selectors.some(s => s.includes('price'))) {
    const priceMatch = snippet.match(/[\d,]+[\s]*€/);
    if (priceMatch) return priceMatch[0].trim();
  }
  
  // Suche nach Titel (h1-h3)
  if (selectors.some(s => s.includes('title') || s.includes('h1') || s.includes('h2'))) {
    const titleMatch = snippet.match(/<h[1-3][^>]*>([^<]+)</);
    if (titleMatch) return titleMatch[1].trim();
  }
  
  return null;
}

// Helper: Extrahiere Bild-URL
function extractImage(html, contextMatch) {
  const matchIndex = html.indexOf(contextMatch);
  if (matchIndex === -1) return null;
  
  const snippet = html.substring(matchIndex, matchIndex + 2000);
  const imgMatch = snippet.match(/<img[^>]+src=["']([^"']+)["']/);
  if (imgMatch) return imgMatch[1];
  
  return null;
}

// Mögliche CSS-Selectors für Lidl-Produkte (werden nacheinander getestet)
const POSSIBLE_SELECTORS = [
  '.product-wrapper',
  '.product-card',
  '.product-item',
  '[data-product]',
  '[data-product-id]',
  '.offer-item',
  '.product',
  'article.product',
  '.leaflet-product',
  '[class*="product"]',
  '[class*="offer"]',
];

async function testCssSelector(selector) {
  console.log(`\n🔍 Teste Selector: "${selector}"`);
  
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 180_000); // 3 Minuten

  try {
    // Zuerst: Crawle die Seite und hole HTML
    const crawlResponse = await fetch(crawlEndpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
      },
      body: JSON.stringify({
        urls: [LIDL_URL],
        crawler_config: {
          type: 'CrawlerRunConfig',
          params: {
            wait_until: 'domcontentloaded',
            page_timeout: 120000,
          },
        },
      }),
      signal: controller.signal,
    });

    if (!crawlResponse.ok) {
      console.error(`   ❌ Crawl fehlgeschlagen: ${crawlResponse.status}`);
      return null;
    }

    const crawlData = await crawlResponse.json().catch(() => null);
    if (!crawlData) {
      console.error('   ❌ Ungültige JSON-Antwort');
      return null;
    }

    const results = crawlData.results || (Array.isArray(crawlData) ? crawlData : [crawlData]);
    const firstResult = results[0] || {};
    const html = firstResult.html || firstResult.cleaned_html || '';
    const markdown = 
      firstResult.markdown?.raw_markdown ??
      firstResult.markdown?.markdown_with_citations ??
      '';

    if (!html && !markdown) {
      console.error('   ❌ Kein HTML oder Markdown verfügbar');
      return null;
    }
    
    // Verwende Markdown falls verfügbar (oft strukturierter)
    const content = markdown || html;

    // Extrahiere Produkte aus Markdown oder HTML
    console.log(`   ℹ️  Analysiere ${markdown ? 'Markdown' : 'HTML'} (${content.length} Zeichen)`);
    
    // Suche nach Produkt-Patterns im Content
    let matches = [];
    
    if (markdown) {
      // Markdown: Suche nach Listen-Items oder strukturierten Produktinformationen
      // Lidl-Markdown enthält oft Listen mit Produkten
      const listItems = markdown.match(/^[\s]*[-*•]\s+.+$/gm) || [];
      matches = listItems;
    } else {
      // HTML: Suche nach Selector-Patterns
      if (selector.startsWith('.')) {
        const className = selector.substring(1).replace(/\*/g, '');
        const classRegex = new RegExp(`class=["'][^"']*${className.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[^"']*["']`, 'gi');
        matches = html.match(classRegex) || [];
      } else if (selector.startsWith('[') && selector.includes('data-')) {
        const attrName = selector.match(/data-[\w-]+/)?.[0] || '';
        if (attrName) {
          const attrRegex = new RegExp(`${attrName}=["'][^"']*["']`, 'gi');
          matches = html.match(attrRegex) || [];
        }
      }
    }
    
    // Falls keine Matches: Versuche generische Extraktion
    if (matches.length === 0) {
      console.log(`   ⚠️  Selector nicht gefunden, versuche generische Extraktion...`);
      matches = [content]; // Verwende gesamten Content
    } else {
      console.log(`   ✅ ${matches.length} Elemente gefunden`);
    }
    
    // Extrahiere strukturierte Daten
    const extractedItems = [];
    const seenTitles = new Set();
    
    if (markdown) {
      // Parse Markdown: Suche nach Produkt-Listen
      // Lidl-Markdown enthält oft strukturierte Listen
      const lines = markdown.split('\n');
      
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const nextLine = lines[i + 1] || '';
        const context = line + ' ' + nextLine; // Kombiniere aktuelle und nächste Zeile
        
        // Suche nach Produktnamen (oft fettgedruckt oder in Listen)
        let title = null;
        
        // Pattern 1: **Produktname**
        const boldMatch = line.match(/\*\*([^*]{5,50})\*\*/);
        if (boldMatch) {
          title = boldMatch[1].trim();
        }
        
        // Pattern 2: Liste mit Produktname
        const listMatch = line.match(/^[\s]*[-*•]\s+(.+?)(?:\s*[-–—]\s*|\s*€|$)/);
        if (listMatch && !title) {
          const candidate = listMatch[1].trim();
          // Filtere aus: zu kurze, zu lange, oder offensichtlich keine Produktnamen
          if (candidate.length >= 5 && candidate.length <= 60 && 
              !candidate.match(/^(Lidl|Prospekt|Angebot|Seite|€|EUR|kg|g|ml|l|Aktionsprospekt|Deutschland)$/i)) {
            title = candidate;
          }
        }
        
        // Pattern 3: Produktname gefolgt von Preis
        if (!title) {
          const productPriceMatch = context.match(/([A-ZÄÖÜ][A-Za-zÄÖÜäöüß\s-]{5,40})\s+([\d,]+[\s]*€)/);
          if (productPriceMatch) {
            const candidate = productPriceMatch[1].trim();
            if (candidate.length >= 5 && candidate.length <= 60) {
              title = candidate;
            }
          }
        }
        
        if (title && title.length >= 5 && title.length <= 60 && !seenTitles.has(title)) {
          seenTitles.add(title);
          
          // Extrahiere Preis (aus aktuellem oder nächstem Kontext)
          const priceMatch = context.match(/([\d,]+[\s]*€)/);
          const price = priceMatch ? priceMatch[1].trim() : null;
          
          // Extrahiere Info (Einheit, Rabatt, etc.)
          const infoPatterns = [
            /\d+\s*(?:x\s*)?\d*\s*(?:g|kg|ml|l|Stück|Packung|Liter|Gramm)/i,
            /-\d+%/,
            /AKTION[^€]*/i,
            /Rabatt[^€]*/i,
            /\+?\d+%\s*(?:gratis|extra)/i,
          ];
          let info = null;
          for (const pattern of infoPatterns) {
            const infoMatch = context.match(pattern);
            if (infoMatch) {
              info = infoMatch[0].trim();
              break;
            }
          }
          
          // Extrahiere Bild-URL (falls im Markdown)
          const imageMatch = markdown.match(/!\[[^\]]*\]\(([^)]+imgproxy[^)]+)\)/);
          const image = imageMatch ? imageMatch[1] : null;
          
          // Nur hinzufügen wenn Titel plausibel ist (nicht nur Datum/Prospekt-Info)
          if (!title.match(/^\d{2}\.\d{2}\.\d{4}/) && !title.match(/^Aktionsprospekt/i)) {
            extractedItems.push({
              title: title,
              price: price || null,
              info: info || null,
              image: image || null,
            });
          }
        }
      }
    } else {
      // HTML: Suche nach Produktbildern (Lidl verwendet imgproxy)
      const imageMatches = [...html.matchAll(/<img[^>]+src=["']([^"']*imgproxy[^"']+)["'][^>]*>/gi)];
      
      for (const imgMatch of imageMatches.slice(0, 30)) {
        const imgIndex = imgMatch.index || 0;
        const imageUrl = imgMatch[1];
        const context = html.substring(Math.max(0, imgIndex - 1000), imgIndex + 1500);
        
        let title = null;
        const titleCandidates = context.match(/>([A-ZÄÖÜ][A-Za-zÄÖÜäöüß\s-]{4,49})</g) || [];
        for (const candidate of titleCandidates) {
          const text = candidate.replace(/[<>]/g, '').trim();
          if (text.length >= 5 && text.length <= 50 && 
              !text.match(/^(Lidl|Prospekt|Angebot|Seite|€|EUR|kg|g|ml|l)$/i) &&
              !seenTitles.has(text)) {
            title = text;
            seenTitles.add(text);
            break;
          }
        }
        
        const priceMatch = context.match(/([\d,]+[\s]*€)/);
        const price = priceMatch ? priceMatch[1].trim() : null;
        
        const infoPatterns = [
          />([^<]{3,30}(?:\d+\s*(?:g|kg|ml|l|Stück|Packung|Liter|Gramm))[^<]{0,20})</i,
          />([^<]{3,30}(?:-\d+%|AKTION|Rabatt)[^<]{0,20})</i,
        ];
        let info = null;
        for (const pattern of infoPatterns) {
          const infoMatch = context.match(pattern);
          if (infoMatch) {
            info = infoMatch[1].trim();
            break;
          }
        }
        
        if (title || price) {
          extractedItems.push({
            title: title || 'Unbekannt',
            price: price || null,
            info: info || null,
            image: imageUrl || null,
          });
        }
      }
    }

    if (extractedItems.length > 0) {
      console.log(`   ✅ ${extractedItems.length} Produkte extrahiert`);
      return { selector, items: extractedItems, count: extractedItems.length };
    }

    console.log(`   ⚠️  Keine Produktdaten extrahiert`);
    return null;
  } catch (error) {
    if (error.name === 'AbortError') {
      console.error(`   ❌ Timeout`);
    } else {
      console.error(`   ❌ Fehler: ${error.message}`);
    }
    return null;
  } finally {
    clearTimeout(timer);
  }
}

async function main() {
  console.log('🧪 CSS-Selector Extraktion Test');
  console.log(`   URL: ${LIDL_URL}`);
  console.log(`   Base URL: ${BASE_URL}\n`);

  console.log(`📋 Teste ${POSSIBLE_SELECTORS.length} mögliche Selectors...\n`);

  const results = [];
  
  for (const selector of POSSIBLE_SELECTORS) {
    const result = await testCssSelector(selector);
    if (result) {
      results.push(result);
    }
    // Kurze Pause zwischen Tests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }

  if (results.length === 0) {
    console.log('\n❌ Kein Selector hat Produkte gefunden.');
    console.log('\n💡 Mögliche Lösungen:');
    console.log('   1. Prüfe die tatsächliche HTML-Struktur der Lidl-Seite');
    console.log('   2. Verwende Browser DevTools um die richtigen Selectors zu finden');
    console.log('   3. Versuche eine andere Extraction Strategy (z.B. LLM)');
    process.exit(1);
  }

  // Finde den besten Selector (meiste Produkte)
  const bestResult = results.reduce((best, current) => 
    current.count > best.count ? current : best
  , results[0]);

  console.log('\n' + '='.repeat(60));
  console.log('✅ BESTER SELECTOR GEFUNDEN!');
  console.log('='.repeat(60));
  console.log(`Selector: "${bestResult.selector}"`);
  console.log(`Anzahl Produkte: ${bestResult.count}\n`);

  console.log('📦 Extrahiertes JSON:');
  console.log('-'.repeat(60));
  console.log(JSON.stringify(bestResult.items, null, 2));
  console.log('-'.repeat(60));

  if (bestResult.items.length > 0) {
    console.log('\n📋 Erstes Produkt:');
    console.log(JSON.stringify(bestResult.items[0], null, 2));
  }

  console.log('\n🎉 Test erfolgreich abgeschlossen!');
}

main().catch((err) => {
  console.error('❌ Unerwarteter Fehler:', err);
  process.exit(1);
});

