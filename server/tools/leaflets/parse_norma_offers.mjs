#!/usr/bin/env node
// Parse NORMA Angebote aus Text und speichere als JSON
// Usage: node parse_norma_offers.mjs < input.txt
// Oder: Text direkt in Script einfügen

import fs from 'fs/promises';
import { join, resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// NORMA Angebote Text - wird vom User-Input verwendet
// Falls leer, wird von stdin gelesen
let normaText = process.argv[2] || '';

// Falls kein Argument, versuche von stdin zu lesen
if (!normaText && !process.stdin.isTTY) {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(chunk);
  }
  normaText = Buffer.concat(chunks).toString('utf-8');
}

// Fallback: Vollständiger Text vom User (aus Query)
if (!normaText) {
  normaText = `Produktbild »Tomato Ketchup«
1,17 Liter
58% billiger
HEINZ
Tomato Ketchup
je 1,17 l
(
1 l = 2,90
ohne App /
1 l = 2,38
mit App)
3,39*
Filiale
 Produktbild »Pflasterrolle XXL«
XXL
SENSOMED
Pflasterrolle XXL
z.B. Elastisch
je 3 m x 6 cm
(
1 m = 1,33
ohne App /
1 m = 1,11
mit App)
3,99*
Filiale
 Produktbild »Premium Lebkuchenmischung«
1 kg
GOLDORA
Premium Lebkuchenmischung
je 1 kg
(
1 kg = 18,99
ohne App /
1 kg = 16,99
mit App)
18,99*
Filiale
 Produktbild »Aufschnitt«
ABLINGER
Aufschnitt
Im Aktionskühlregal
je 300 g
(
1 kg = 11,10
ohne App /
1 kg = 9,97
mit App)
16% billiger
UVP 3,99
3,33*
Filiale
 Produktbild »Erdnuss Locken«
LORENZ
Erdnuss Locken
Aus unserem Sortiment
je 175 g
(
1 kg = 7,37
ohne App /
1 kg = 5,66
mit App)
41% billiger
statt 2,19
1,29*
Filiale
 Produktbild »Geflügel Snacks«
ROY
Geflügel Snacks
Aus unserem Sortiment
z.B. Spare Ribs
je 100 g
(
1 kg = 23,90
ohne App /
1 kg = 19,90
mit App)
20% billiger
statt 2,99
2,39*
Filiale
 Produktbild »3-Kammer-Kopfkissen«
ORTHO-VITAL
3-Kammer-Kopfkissen
ca. 80 x 80 cm
24,99*
Filiale
 Produktbild »Rivaner-Grauer Burgunder QbA«
DEUTSCHLAND
Rivaner-Grauer Burgunder QbA
je 0,75 l
(
1 l = 3,85
ohne App /
1 l = 3,19
mit App)
Ständig im Sortiment
2,89
Filiale
 Produktbild »Dornfelder Regent QbA«
DEUTSCHLAND
Dornfelder Regent QbA
je 1 l
(
1 l = 3,69
ohne App /
1 l = 2,99
mit App)
Ständig im Sortiment
3,69
Filiale
Shop
 Produktbild »Likörpralinen / Weinbrand Bohnen«
EXCELSIOR
Likörpralinen / Weinbrand Bohnen
z.B. Eierlikör Pralinen je 150 g
(
1 kg = 15,27
ohne App /
1 kg = 13,27
mit App)
Ständig im Sortiment
2,29
Filiale
 Produktbild »Vino Spumante Secco«
ITALIEN/CAMASELLA
Vino Spumante Secco
je 0,75 l
(
1 l = 6,65
ohne App /
1 l = 5,32
mit App)
Ständig im Sortiment
4,99
Filiale
 Produktbild »Zimtsterne«
GOLDORA
Zimtsterne
je 175 g
(
1 kg = 17,09
ohne App /
1 kg = 13,09
mit App)
Ständig im Sortiment
2,99
Filiale
 Produktbild »Pastasauce«
VILLA GUSTO
Pastasauce
je 476 ml
(
1 l = 3,55
ohne App /
1 l = 3,13
mit App)
Ständig im Sortiment
1,69
Filiale
 Produktbild »Whisky«
BLACK RAM
Whisky
Aus unserem Sortiment
je 0,7 l
(
1 l = 14,27
ohne App /
1 l = 12,84
mit App)
16% billiger
statt 11,99
9,99*
Filiale
 Produktbild »Frischkäse«
ALMETTE
Frischkäse
Aus unserem Sortiment
Im Kühlregal
je 150 g
(
1 kg = 7,40
ohne App /
1 kg = 6,60
mit App)
44% billiger
statt 1,99
1,11*
Filiale
 Produktbild »Sonnenblumenkerne«
MERAY
Sonnenblumenkerne
je 250 g
(
1 kg = 9,96
ohne App /
1 kg = 7,96
mit App)
16% billiger
UVP 2,99
2,49*
Filiale`;
}

// Parse Funktion
function parseNormaOffers(text) {
  const offers = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l && !l.includes('NORMA Filiale') && !l.includes('https://'));
  
  let currentOffer = null;
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Neues Angebot beginnt mit "Produktbild »"
    if (line.includes('Produktbild »')) {
      // Vorheriges Angebot speichern
      if (currentOffer && currentOffer.title && currentOffer.price) {
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
        validFrom: '2025-11-24',
        validTo: '2025-11-26',
      };
      continue;
    }
    
    if (!currentOffer) continue;
    
    // Überspringe Footer/Header-Zeilen
    if (line.includes('Filiale') || line.includes('Shop') || line.includes('NORMA') || line.startsWith('http')) {
      continue;
    }
    
    // Marke erkennen (GROSSBUCHSTABEN, nicht Preis, nicht "XXL", "DEUTSCHLAND", etc. als Marke wenn danach noch Text kommt)
    if (line.match(/^[A-Z][A-Z\s\/&]+$/) && 
        !line.includes('=') && 
        !line.includes('€') && 
        !line.match(/\d/) && 
        line.length > 2 && 
        line.length < 40 &&
        !['XXL', 'DEUTSCHLAND', 'ITALIEN', 'STÜCK', 'PACK'].includes(line)) {
      // Prüfe ob nächste Zeile auch Großbuchstaben ist (dann ist es wahrscheinlich der Titel)
      const nextLine = i + 1 < lines.length ? lines[i + 1] : '';
      if (!nextLine.match(/^[A-Z][A-Z\s\/&]+$/) || nextLine.includes('=') || nextLine.includes('€')) {
        if (!currentOffer.brand || currentOffer.brand.length < line.length) {
          currentOffer.brand = line;
        }
      }
    }
    
    // Titel (wenn noch leer oder wenn es ein normaler Text ist)
    if (line && 
        !line.includes('Produktbild') && 
        !line.includes('Filiale') && 
        !line.includes('Shop') &&
        !line.match(/^\d+[,.]\d{2}/) &&
        !line.includes('je ') &&
        !line.includes('UVP') &&
        !line.includes('statt') &&
        !line.includes('% billiger') &&
        !line.includes('Ständig im Sortiment') &&
        !line.includes('Aus unserem Sortiment') &&
        !line.includes('Im ') &&
        !line.includes('z.B.') &&
        !line.includes('ca.') &&
        line.length > 3 && 
        line.length < 150 &&
        !line.match(/^[A-Z][A-Z\s\/&]+$/)) {
      if (!currentOffer.title || currentOffer.title === currentOffer.brand) {
        currentOffer.title = line;
      }
    }
    
    // Preis erkennen (letzter Preis vor "Filiale")
    if (line.match(/\d+[,.]\d{2}\*?$/) && !line.includes('=') && !line.includes('UVP') && !line.includes('statt')) {
      const priceMatch = line.match(/(\d+[,.]\d{2})\*?/);
      if (priceMatch) {
        const price = parseFloat(priceMatch[1].replace(',', '.'));
        // Nimm den letzten Preis (nicht den Preis pro Einheit)
        if (!currentOffer.price || (price > 0.5 && price < 1000)) {
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
      const unitMatch = line.match(/je\s+([\d.,]+\s*(?:kg|l|g|ml|m|Stück|Stk|Pack|Ausführung|Bettwäsche|Nachthemd|Set|Karte|Paar|Artikel))/i);
      if (unitMatch) {
        currentOffer.unit = unitMatch[1].trim();
      }
    }
    
    // Preis pro Einheit (ohne App)
    if (line.includes('ohne App') && line.includes('=')) {
      const pricePerUnitMatch = line.match(/1\s+(?:kg|l|m|m2)\s*=\s*([\d.,]+)/);
      if (pricePerUnitMatch) {
        currentOffer.pricePerUnit = parseFloat(pricePerUnitMatch[1].replace(',', '.'));
      }
    }
    
    // Preis pro Einheit (mit App)
    if (line.includes('mit App') && line.includes('=')) {
      const pricePerUnitAppMatch = line.match(/1\s+(?:kg|l|m|m2)\s*=\s*([\d.,]+)/);
      if (pricePerUnitAppMatch) {
        currentOffer.pricePerUnitWithApp = parseFloat(pricePerUnitAppMatch[1].replace(',', '.'));
      }
    }
  }
  
  // Letztes Angebot speichern
  if (currentOffer && currentOffer.title && currentOffer.price) {
    offers.push(currentOffer);
  }
  
  return offers.filter(o => o.title && o.price);
}

// Hauptfunktion
async function main() {
  console.log('📦 Parse NORMA Angebote...\n');
  
  const offers = parseNormaOffers(normaText);
  
  console.log(`✅ ${offers.length} Angebote gefunden\n`);
  
  // JSON-Struktur
  const output = {
    retailer: 'NORMA',
    weekKey: '2025-W48',
    year: 2025,
    week: 48,
    validFrom: '2025-11-24',
    validTo: '2025-11-26',
    totalOffers: offers.length,
    offers: offers,
    extractedAt: new Date().toISOString(),
  };
  
  // Speichern
  const outputDir = resolve(__dirname, '../../media/prospekte/norma');
  await fs.mkdir(outputDir, { recursive: true });
  
  const outputPath = join(outputDir, 'offers_2025-W48.json');
  await fs.writeFile(outputPath, JSON.stringify(output, null, 2), 'utf-8');
  
  console.log(`✅ JSON gespeichert: ${outputPath}`);
  console.log(`\n📊 Erste 5 Angebote:`);
  offers.slice(0, 5).forEach((offer, i) => {
    console.log(`\n${i + 1}. ${offer.title}`);
    console.log(`   Marke: ${offer.brand || 'N/A'}`);
    console.log(`   Preis: ${offer.price}€`);
    if (offer.unit) console.log(`   Einheit: ${offer.unit}`);
    if (offer.discount) console.log(`   Rabatt: ${offer.discount}%`);
  });
}

main().catch(console.error);
