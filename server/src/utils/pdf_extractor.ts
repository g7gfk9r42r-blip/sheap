/**
 * PDF Text Extractor für EDEKA-Prospekte
 * 
 * Extrahiert Angebote aus PDF-Text mit Regex-Patterns.
 * Nutzt pdf-parse für Text-Extraktion.
 */

import pdfParse from 'pdf-parse';

export type ExtractedOffer = {
  name: string;
  price: number;
  discount?: number | null;
  unit?: string | null;
  sourceRegion: string;
  rawText?: string;
};

/**
 * Extrahiert Angebote aus PDF-Text
 * 
 * @param pdfBuffer PDF-Datei als Buffer
 * @param sourceRegion Name der Region (z.B. "Berlin")
 * @returns Array von extrahierten Angeboten
 */
export async function extractOffersFromPdf(
  pdfBuffer: Buffer,
  sourceRegion: string
): Promise<ExtractedOffer[]> {
  console.log(`[PDF-Extractor] Extrahiere Angebote aus PDF für Region: ${sourceRegion}`);
  
  // Parse PDF zu Text
  const data = await pdfParse(pdfBuffer);
  const text = data.text;
  
  if (!text || text.length < 100) {
    console.warn(`[PDF-Extractor] PDF enthält zu wenig Text (${text.length} Zeichen)`);
    return [];
  }
  
  console.log(`[PDF-Extractor] PDF-Text extrahiert: ${text.length} Zeichen`);
  
  // Extrahiere Angebote
  const offers = parseOffersFromText(text, sourceRegion);
  
  console.log(`[PDF-Extractor] ${offers.length} Angebote gefunden`);
  
  return offers;
}

/**
 * Parst Angebote aus Text mit Regex-Patterns
 */
function parseOffersFromText(text: string, sourceRegion: string): ExtractedOffer[] {
  const offers: ExtractedOffer[] = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  
  // Preis-Pattern: "1,99" oder "1.99" oder "1,99€" oder "€1,99"
  const pricePattern = /(\d+[,.]\d{2})\s*€?|€\s*(\d+[,.]\d{2})/g;
  
  // Rabatt-Pattern: "-50%" oder "50% billiger" oder "SUPERKNÜLLER"
  const discountPattern = /-(\d+)%|(\d+)%\s*billiger|SUPERKNÜLLER/gi;
  
  // Einheit-Pattern: "1kg", "500g", "1l", "500ml", "Stück", "Packung"
  const unitPattern = /(\d+(?:[,.]\d+)?)\s*(kg|g|l|ml|stk|st\.|stück|packung|pck|pack)/i;
  
  // Preis pro Einheit: "1kg = 2,99" oder "1 l = 1,49"
  const pricePerUnitPattern = /1\s*(?:kg|l|m)\s*=\s*(\d+[,.]\d{2})/i;
  
  // Durchlaufe alle Zeilen
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Suche nach Preis
    const priceMatch = line.match(pricePattern);
    if (!priceMatch) continue;
    
    // Extrahiere Preis
    let price: number | null = null;
    for (const match of priceMatch) {
      const numMatch = match.match(/(\d+[,.]\d{2})/);
      if (numMatch) {
        const priceStr = numMatch[1].replace(',', '.');
        const parsedPrice = parseFloat(priceStr);
        if (parsedPrice >= 0.01 && parsedPrice <= 1000) {
          price = parsedPrice;
          break;
        }
      }
    }
    
    if (!price) continue;
    
    // Extrahiere Produktname (Text vor dem Preis, bereinigt)
    let name = line;
    
    // Entferne Preis
    name = name.replace(pricePattern, '').trim();
    
    // Entferne häufige Präfixe
    name = name.replace(/^(SUPERKNÜLLER|Angebot|Aktion|Rabatt|%|-\d+%)\s*/i, '').trim();
    
    // Entferne Rabatt-Informationen
    name = name.replace(/\s*-\d+%\s*/g, ' ').trim();
    name = name.replace(/\s*Niedrig\.\s*Gesamtpreis:\s*€\s*[\d.,]+\s*/gi, '').trim();
    name = name.replace(/\s*1kg\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
    name = name.replace(/\s*1l\s*=\s*€\s*[\d.,]+\s*/gi, '').trim();
    name = name.replace(/\s*versch\.\s*Sorten[^,]*/gi, '').trim();
    name = name.replace(/\s*aus\s+[^,]+/gi, '').trim();
    name = name.replace(/\s*Klasse\s+[IVX]+/gi, '').trim();
    
    // Bereinige mehrfache Leerzeichen
    name = name.replace(/\s+/g, ' ').trim();
    
    if (name.length < 3) continue;
    
    // Extrahiere Rabatt
    let discount: number | null = null;
    const discountMatch = line.match(discountPattern);
    if (discountMatch) {
      const discountStr = discountMatch[0].match(/(\d+)/);
      if (discountStr) {
        discount = parseInt(discountStr[1], 10);
      } else if (discountMatch[0].toUpperCase().includes('SUPERKNÜLLER')) {
        discount = 0; // SUPERKNÜLLER = Sonderangebot
      }
    }
    
    // Extrahiere Einheit
    let unit: string | null = null;
    const unitMatch = line.match(unitPattern);
    if (unitMatch) {
      unit = `${unitMatch[1]} ${unitMatch[2].toLowerCase()}`;
    }
    
    // Extrahiere Preis pro Einheit (falls vorhanden)
    const pricePerUnitMatch = line.match(pricePerUnitPattern);
    if (pricePerUnitMatch && !unit) {
      // Falls keine explizite Einheit, aber Preis pro Einheit vorhanden
      const unitType = line.match(/1\s*(kg|l|m)/i)?.[1]?.toLowerCase();
      if (unitType) {
        unit = `1 ${unitType}`;
      }
    }
    
    // Validiere Angebot
    if (name.length >= 3 && name.length <= 200 && price >= 0.01 && price <= 1000) {
      offers.push({
        name,
        price,
        discount,
        unit,
        sourceRegion,
        rawText: line.substring(0, 200), // Erste 200 Zeichen für Debugging
      });
    }
  }
  
  // Deduplizierung: Entferne Duplikate basierend auf Name + Preis
  const uniqueOffers: ExtractedOffer[] = [];
  const seen = new Set<string>();
  
  for (const offer of offers) {
    const key = `${offer.name.toLowerCase()}|${offer.price}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueOffers.push(offer);
    }
  }
  
  return uniqueOffers;
}

