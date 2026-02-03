/**
 * KaufDA HTML Parser
 * 
 * Extrahiert PDF-Links oder Angebote aus gespeicherten KaufDA HTML-Dateien.
 * Nutzt cheerio für HTML-Parsing.
 */

import * as cheerio from 'cheerio';
import { promises as fs } from 'fs';
import { join } from 'path';

export type ExtractedPdfLink = {
  region?: string;
  url: string;
  title?: string;
  validFrom?: string;
  validTo?: string;
};

export type ExtractedOffer = {
  name: string;
  price: number;
  discount?: number | null;
  unit?: string | null;
  imageUrl?: string | null;
  rawText?: string;
};

/**
 * Extrahiert PDF-Download-Links aus einer KaufDA HTML-Datei
 */
export async function extractPdfLinksFromHtml(htmlPath: string): Promise<ExtractedPdfLink[]> {
  console.log(`[KaufDA-Parser] Parse HTML: ${htmlPath}`);
  
  const htmlContent = await fs.readFile(htmlPath, 'utf-8');
  const $ = cheerio.load(htmlContent);
  
  const pdfLinks: ExtractedPdfLink[] = [];
  
  // Suche nach PDF-Links in verschiedenen Formaten
  const selectors = [
    'a[href*=".pdf"]',
    'a[href*="/pdf"]',
    'a[href*="download"]',
    'a[data-pdf]',
    'a[data-prospekt]',
    '[data-pdf-url]',
    '[data-prospekt-url]',
  ];
  
  for (const selector of selectors) {
    $(selector).each((_, element) => {
      const $el = $(element);
      const href = $el.attr('href') || $el.attr('data-pdf') || $el.attr('data-pdf-url') || $el.attr('data-prospekt-url');
      
      if (href && (href.includes('.pdf') || href.includes('/pdf') || href.includes('download'))) {
        // Normalisiere URL (kann relativ sein)
        let url = href;
        if (href.startsWith('/')) {
          url = `https://www.kaufda.de${href}`;
        } else if (!href.startsWith('http')) {
          url = `https://www.kaufda.de/${href}`;
        }
        
        const title = $el.text().trim() || $el.attr('title') || $el.attr('aria-label');
        
        // Extrahiere Gültigkeitsdaten falls vorhanden
        const parent = $el.parent();
        const validText = parent.text() || $el.closest('[class*="valid"], [class*="gültig"]').text();
        const validMatch = validText.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})\s*[-–]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})/);
        
        let validFrom: string | undefined;
        let validTo: string | undefined;
        if (validMatch) {
          validFrom = `${validMatch[3]}-${validMatch[2]}-${validMatch[1]}`;
          validTo = `${validMatch[6]}-${validMatch[5]}-${validMatch[4]}`;
        }
        
        pdfLinks.push({
          url,
          title: title || undefined,
          validFrom,
          validTo,
        });
      }
    });
  }
  
  // Suche auch nach JavaScript-Variablen, die PDF-URLs enthalten könnten
  $('script').each((_, element) => {
    const scriptContent = $(element).html() || '';
    
    // Suche nach PDF-URLs in JavaScript
    const pdfUrlMatches = scriptContent.match(/["']([^"']*\.pdf[^"']*)["']/gi);
    if (pdfUrlMatches) {
      for (const match of pdfUrlMatches) {
        const url = match.replace(/["']/g, '');
        if (url.includes('edeka') || url.includes('prospekt')) {
          pdfLinks.push({
            url: url.startsWith('http') ? url : `https://www.kaufda.de${url}`,
          });
        }
      }
    }
    
    // Suche nach JSON-Daten, die PDF-URLs enthalten
    const jsonMatch = scriptContent.match(/\{[\s\S]*"pdfUrl"[\s\S]*\}/);
    if (jsonMatch) {
      try {
        const data = JSON.parse(jsonMatch[0]);
        if (data.pdfUrl) {
          pdfLinks.push({
            url: data.pdfUrl,
            title: data.title,
          });
        }
      } catch {
        // Ignore JSON parse errors
      }
    }
  });
  
  // Deduplizierung
  const uniqueLinks = Array.from(
    new Map(pdfLinks.map(link => [link.url, link])).values()
  );
  
  console.log(`[KaufDA-Parser] ${uniqueLinks.length} PDF-Links gefunden`);
  
  return uniqueLinks;
}

/**
 * Extrahiert Angebote direkt aus der HTML (falls vorhanden)
 */
export async function extractOffersFromHtml(htmlPath: string): Promise<ExtractedOffer[]> {
  console.log(`[KaufDA-Parser] Extrahiere Angebote aus HTML: ${htmlPath}`);
  
  const htmlContent = await fs.readFile(htmlPath, 'utf-8');
  const $ = cheerio.load(htmlContent);
  
  const offers: ExtractedOffer[] = [];
  
  // Suche nach Angebots-Containern
  const offerSelectors = [
    '[class*="offer"]',
    '[class*="angebot"]',
    '[class*="product"]',
    '[class*="item"]',
    '[data-offer]',
    '[data-product]',
  ];
  
  for (const selector of offerSelectors) {
    $(selector).each((_, element) => {
      const $el = $(element);
      const text = $el.text().trim();
      
      // Suche nach Preis
      const priceMatch = text.match(/(\d+[,.]\d{2})\s*€/);
      if (!priceMatch) return;
      
      const price = parseFloat(priceMatch[1].replace(',', '.'));
      if (price < 0.01 || price > 1000) return;
      
      // Extrahiere Produktname (Text vor dem Preis)
      let name = text.replace(/(\d+[,.]\d{2})\s*€.*$/, '').trim();
      name = name.replace(/^(SUPERKNÜLLER|Angebot|Aktion)\s*/i, '').trim();
      
      if (name.length < 3 || name.length > 200) return;
      
      // Extrahiere Rabatt
      let discount: number | null = null;
      const discountMatch = text.match(/-(\d+)%/);
      if (discountMatch) {
        discount = parseInt(discountMatch[1], 10);
      }
      
      // Extrahiere Einheit
      let unit: string | null = null;
      const unitMatch = text.match(/(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung)/i);
      if (unitMatch) {
        unit = `${unitMatch[1]} ${unitMatch[2].toLowerCase()}`;
      }
      
      // Extrahiere Bild-URL
      const imageUrl = $el.find('img').attr('src') || $el.find('img').attr('data-src') || null;
      
      offers.push({
        name,
        price,
        discount,
        unit,
        imageUrl,
        rawText: text.substring(0, 200),
      });
    });
  }
  
  // Deduplizierung
  const uniqueOffers = Array.from(
    new Map(offers.map(offer => [`${offer.name}|${offer.price}`, offer])).values()
  );
  
  console.log(`[KaufDA-Parser] ${uniqueOffers.length} Angebote aus HTML extrahiert`);
  
  return uniqueOffers;
}

/**
 * Haupt-Funktion: Extrahiert PDF-Links aus einer gespeicherten HTML-Datei
 */
export async function parseKaufdaHtml(htmlPath: string): Promise<{
  pdfLinks: ExtractedPdfLink[];
  offers: ExtractedOffer[];
}> {
  const pdfLinks = await extractPdfLinksFromHtml(htmlPath);
  const offers = await extractOffersFromHtml(htmlPath);
  
  return { pdfLinks, offers };
}

