#!/usr/bin/env node
// Füge NORMA-Angebote hinzu, die ab Freitag 28.11.2025 gültig sind

import fs from 'fs/promises';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Neue Angebote (ab Freitag 28.11.2025)
const fridayOffersText = `Produktbild »Top Cup / Dessert Butterkeks & Crunchy / Dessert«
ZOTT MONTE
Top Cup / Dessert Butterkeks & Crunchy / Dessert
Im Aktionskühlregal
z.B. Top Cup je 70 g
(1 kg = 12,14)
–,85*
Filiale
 Produktbild »Pizza La Mia Grande«
DR. OETKER
Pizza La Mia Grande
In der Tiefkühltruhe
z.B. 4 Formaggi
je 400 g
(1 kg = 8,23)
3,29*
Filiale
 Produktbild »Kleine Weihnachtsmänner«
3er Pack
KINDER
Kleine Weihnachtsmänner
je 3 x 15 g
(1 kg = 39,78)
1,79*
Filiale
 Produktbild »Gala Pudding«
DR. OETKER
Gala Pudding
z.B. Bourbon-Vanille
je 3 x 37 g, ergibt 1,5 Liter
(1 l = –,86)
1,29*
Filiale
 Produktbild »Orangen«
3 kg
XXL
GÖTTERFRUCHT
Orangen
je 3 kg
Zum tagesaktuellen Tiefpreis
 Produktbild »Hähnchen-Brustfilet«
1,5 kg
GUT LANGENHOF
Hähnchen-Brustfilet
Im Kühlregal
je 1,5 kg
(1 kg = 8,66)
12,99*
Filiale
 Produktbild »Rinder Leber«
ca. 1 kg
GUT BARTENHOF
Rinder Leber
Im Kühlregal
(1 kg = 5,99)
z.B. 833 g
4,99*
Filiale
 Produktbild »Hackfleisch gemischt«
1 kg
GUT BARTENHOF
Hackfleisch gemischt
Im Kühlregal
je 1 kg
(1 kg = 6,29)
6,29*
Filiale`;

// Parse Funktion (vereinfacht)
function parseNormaOffers(text, validFrom, validTo) {
  const offers = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l && !l.includes('NORMA Filiale') && !l.includes('https://'));
  
  let currentOffer = null;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Neues Angebot beginnt mit "Produktbild »"
    if (line.includes('Produktbild »')) {
      // Vorheriges Angebot speichern
      if (currentOffer && currentOffer.title && currentOffer.price !== null) {
        offers.push(currentOffer);
      }
      
      // Neues Angebot starten
      const titleMatch = line.match(/Produktbild »(.+?)«/);
      currentOffer = {
        title: titleMatch ? titleMatch[1] : '',
        brand: '',
        price: null,
        originalPrice: null,
        discount: null,
        unit: '',
        pricePerUnit: null,
        pricePerUnitWithApp: null,
        category: '',
        retailer: 'NORMA',
        validFrom: validFrom,
        validTo: validTo,
      };
      continue;
    }
    
    if (!currentOffer) continue;
    
    // Überspringe Footer/Header-Zeilen (aber nicht "tagesaktuellen Tiefpreis" - das ist Teil des Angebots)
    if (line.includes('Filiale') || line.includes('Shop') || line.includes('NORMA') || line.startsWith('http')) {
      continue;
    }
    
    // "tagesaktuellen Tiefpreis" als Note speichern
    if (line.includes('tagesaktuellen') || line.includes('Tiefpreis')) {
      if (currentOffer && !currentOffer.note) {
        currentOffer.note = 'tagesaktueller Tiefpreis';
        // Setze Preis auf 0 als Placeholder
        if (currentOffer.price === null) {
          currentOffer.price = 0;
        }
      }
      continue;
    }
    
    // Marke erkennen (auch mit Punkten wie "DR. OETKER")
    // Prüfe ob es eine Marke sein könnte (hauptsächlich Großbuchstaben, kann Punkte enthalten)
    const isPotentialBrand = line.match(/^[A-Z][A-Z\s\/&.]+$/) || 
                             (line.match(/^[A-Z]{2,}/) && line.match(/[A-Z]/g) && line.match(/[A-Z]/g).length >= 2);
    
    if (isPotentialBrand && 
        !line.includes('=') && 
        !line.includes('€') && 
        !line.match(/^\d/) && 
        line.length > 2 && 
        line.length < 40 &&
        !['XXL', 'DEUTSCHLAND', 'ITALIEN', 'STÜCK', 'PACK', '3ER PACK', '3 KG', 'ZUM'].includes(line)) {
      const nextLine = i + 1 < lines.length ? lines[i + 1] : '';
      // Wenn nächste Zeile nicht auch eine Marke ist, dann ist es wahrscheinlich die Marke
      const nextIsBrand = nextLine.match(/^[A-Z][A-Z\s\/&.]+$/) && !nextLine.includes('=') && !nextLine.includes('€');
      if (!nextIsBrand || nextLine.includes('=') || nextLine.includes('€')) {
        // Speichere Marke, wenn noch keine gesetzt oder wenn diese länger/klarer ist
        if (!currentOffer.brand || (line.length > currentOffer.brand.length && line.includes('.'))) {
          currentOffer.brand = line;
        }
      }
    }
    
    // Titel (verbessert: auch wenn "Im " oder "z.B." enthalten, wenn es der einzige Text ist)
    if (line && 
        !line.includes('Produktbild') && 
        !line.includes('Filiale') && 
        !line.includes('Shop') &&
        !line.match(/^\d+[,.]\d{2}/) &&
        !line.includes('UVP') &&
        !line.includes('statt') &&
        !line.includes('% billiger') &&
        !line.includes('Ständig im Sortiment') &&
        !line.includes('Aus unserem Sortiment') &&
        !line.includes('Zum tagesaktuellen') &&
        !line.includes('(1 kg =') &&
        !line.includes('(1 l =') &&
        line.length > 3 && 
        line.length < 150 &&
        !line.match(/^[A-Z][A-Z\s\/&]+$/)) {
      // Wenn Titel noch leer oder gleich Marke, setze Titel
      if (!currentOffer.title || currentOffer.title === currentOffer.brand || currentOffer.title.length < 5) {
        // Überspringe "Im Aktionskühlregal", "In der Tiefkühltruhe", etc. als Titel
        if (!line.match(/^(Im |In der |z\.B\. |ca\. )/i) || currentOffer.title.length < 3) {
          currentOffer.title = line;
        }
      }
    }
    
    // Preis erkennen (auch mit "–," für 0,85)
    if (line.match(/[–\-]?\d+[,.]\d{2}\*?$/) && !line.includes('=') && !line.includes('UVP') && !line.includes('statt')) {
      const priceMatch = line.match(/([–\-]?\d+[,.]\d{2})\*?/);
      if (priceMatch) {
        let priceStr = priceMatch[1].replace(',', '.').replace('–', '0').replace('-', '0');
        const price = parseFloat(priceStr);
        if (!isNaN(price) && price > 0 && price < 1000) {
          currentOffer.price = price;
        }
      }
    }
    
    // Spezialfall: Preis mit "–," (z.B. "–,85" = 0,85)
    if (line.match(/^[–\-],\d{2}\*?$/)) {
      const priceMatch = line.match(/[–\-],(\d{2})\*?/);
      if (priceMatch) {
        const price = parseFloat('0.' + priceMatch[1]);
        if (!isNaN(price) && price > 0) {
          currentOffer.price = price;
        }
      }
    }
    
    // UVP / Originalpreis
    if (line.includes('UVP') || line.includes('statt')) {
      const uvpMatch = line.match(/(?:UVP|statt)\s+(\d+[,.]\d{2})/);
      if (uvpMatch) {
        currentOffer.originalPrice = parseFloat(uvpMatch[1].replace(',', '.'));
      }
    }
    
    // Rabatt
    if (line.includes('% billiger')) {
      const discountMatch = line.match(/(\d+)%\s+billiger/);
      if (discountMatch) {
        currentOffer.discount = parseInt(discountMatch[1]);
      }
    }
    
    // Einheit
    if (line.includes('je ') && (line.includes('kg') || line.includes('l') || line.includes('g') || line.includes('ml') || line.includes('m') || line.includes('Stück') || line.includes('Pack') || line.includes('Ausführung'))) {
      const unitMatch = line.match(/je\s+([\d.,x\s]+\s*(?:kg|l|g|ml|m|Stück|Stk|Pack|Ausführung|Bettwäsche|Nachthemd|Set|Karte|Paar|Artikel|Liter))/i);
      if (unitMatch) {
        currentOffer.unit = unitMatch[1].trim();
      }
    }
    
    // Preis pro Einheit
    if (line.includes('1 kg =') || line.includes('1 l =') || line.includes('1 m =')) {
      const pricePerUnitMatch = line.match(/1\s+(?:kg|l|m|m2)\s*=\s*([\d.,]+)/);
      if (pricePerUnitMatch) {
        currentOffer.pricePerUnit = parseFloat(pricePerUnitMatch[1].replace(',', '.'));
      }
    }
  }
  
  // Letztes Angebot speichern
  if (currentOffer && currentOffer.title) {
    // Für Angebote ohne expliziten Preis (z.B. "tagesaktueller Tiefpreis"): setze price auf 0 und note
    if (currentOffer.price === null) {
      // Prüfe ob "tagesaktuell" oder "Tiefpreis" im Text vorkommt
      const textLower = (currentOffer.title + ' ' + (currentOffer.unit || '')).toLowerCase();
      if (textLower.includes('tagesaktuell') || textLower.includes('tiefpreis')) {
        currentOffer.price = 0; // Placeholder für "tagesaktueller Preis"
        currentOffer.note = 'tagesaktueller Tiefpreis';
      }
    }
    // Speichere nur wenn Preis vorhanden oder Note gesetzt
    if (currentOffer.price !== null || currentOffer.note) {
      offers.push(currentOffer);
    }
  }
  
  return offers.filter(o => o.title && (o.price !== null || o.note));
}

// Hauptfunktion
async function main() {
  console.log('📦 Füge NORMA-Angebote (ab Freitag 28.11.2025) hinzu...\n');
  
  const fridayOffers = parseNormaOffers(fridayOffersText, '2025-11-28', '2025-11-30');
  
  console.log(`✅ ${fridayOffers.length} neue Angebote gefunden\n`);
  
  // Lade bestehende JSON
  const jsonPath = resolve(__dirname, '../../media/prospekte/norma/offers_2025-W48.json');
  let existingData = { offers: [] };
  
  try {
    const existingContent = await fs.readFile(jsonPath, 'utf-8');
    existingData = JSON.parse(existingContent);
  } catch (err) {
    console.log('⚠️  Keine bestehende JSON gefunden, erstelle neue...');
  }
  
  // Füge neue Angebote hinzu
  const allOffers = [...(existingData.offers || []), ...fridayOffers];
  
  // Aktualisiere JSON-Struktur
  const output = {
    retailer: 'NORMA',
    weekKey: '2025-W48',
    year: 2025,
    week: 48,
    validFrom: '2025-11-24', // Erste Angebote ab Montag
    validTo: '2025-11-30',   // Letzte Angebote bis Sonntag
    totalOffers: allOffers.length,
    offers: allOffers,
    extractedAt: new Date().toISOString(),
    note: 'Angebote ab 24.11.2025 (Montag) und ab 28.11.2025 (Freitag)',
  };
  
  // Speichern
  await fs.writeFile(jsonPath, JSON.stringify(output, null, 2), 'utf-8');
  
  console.log(`✅ JSON aktualisiert: ${jsonPath}`);
  console.log(`   Gesamt: ${allOffers.length} Angebote`);
  console.log(`   - Ab Montag (24.11): ${(existingData.offers || []).length} Angebote`);
  console.log(`   - Ab Freitag (28.11): ${fridayOffers.length} Angebote`);
  console.log(`\n📊 Neue Angebote (ab Freitag):`);
  fridayOffers.forEach((offer, i) => {
    console.log(`\n${i + 1}. ${offer.title}`);
    console.log(`   Marke: ${offer.brand || 'N/A'}`);
    console.log(`   Preis: ${offer.price}€`);
    if (offer.unit) console.log(`   Einheit: ${offer.unit}`);
    console.log(`   Gültig ab: ${offer.validFrom}`);
  });
}

main().catch(console.error);

