#!/usr/bin/env node
// Parse PENNY Angebote aus Text und speichere als JSON

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
  return { year, week, weekKey: `${year}-W${week}` };
}

// Parse Funktion für PENNY-Angebote
function parsePennyOffers(text, validFromDate, validToDate) {
  const offers = [];
  const lines = text.split('\n').map(l => l.trim()).filter(l => l);
  
  // Kategorien, die wir überspringen (nicht relevante Abschnitte)
  const skipSections = [
    'Volkach', 'Angebote', 'Aktionen', 'Clever Kochen', 'Mein Markt',
    'Sekundärnavigation', 'PENNY App', 'Prospekt', 'Karriere',
    'Als Liste', 'Als Prospekt', 'Ab Freitag', 'Top Angebote',
    'Diese Woche', 'Mo-Sa', 'Obst & Gemüse',
    'Kühlregal', 'Best Moments', 'Douceur', 'Süßigkeiten & Snacks',
    'TREUE', 'Fleisch & Wurst', 'Weitere Angebote', 'Getränke',
    'Drogerie & Haushalt', 'Black Week', 'Pflanzen', 'Haushalt & Wohnen',
    'Kochen & Backen', 'Kinderwelt', 'Multimedia & Elektronik', 'Weihnachten',
    'Food-Highlights für alle', 'Sparen auf Top-Marken', 'Framstag',
    'ANGEBOTE DER NÄCHSTEN WOCHE', 'Mehr über Penny', 'Nachhaltigkeit',
    'Über uns', 'Presse', 'PENNY auf Festivals', 'Top Kategorien',
    'Angebote der Woche', 'Prospekt der Woche', 'Ernährung & Rezepte',
    'Tipps & Tricks', 'MAGGI', 'Unsere Märkte', 'Markteröffnungen',
    'Marktsuche', 'Lieferservice', 'Marktkonzept', 'Bezahlen im Markt',
    'Scan & Go', 'Services', 'Kontakt & Hilfe', 'Newsletter',
    'WhatsApp', 'PENNY Onlineshop', 'App', 'Eishockey', 'Impressum',
    'Datenschutz', 'Privatsphäre-Einstellungen', 'Geschlossen', 'Markt anzeigen',
    'KEIN NON-FOOD SORTIMENT', 'Nächster Non-Food Markt', 'PENNY', 'Weitere',
    'Mach jeden Tag zum FRYTAG', 'Gewinne mit MAGGI', 'Dein Coupon',
    'Rezept', 'Veggie', 'Fleisch', 'Fisch', 'À la', 'min', 'mittel',
    'leicht', 'gering', 'z. B.', 'z.B.', 'Gilt nicht für', 'Aktionszeitraum',
    'Teilnahmezeitraum', 'Teilnahmebedingungen', 'Abbildungen ähnlich',
    'offer', 'Ab Freitag findest du hier immer'
  ];
  
  // Prüfe, ob eine Zeile übersprungen werden soll
  function shouldSkip(line) {
    if (!line || line.length < 2) return true;
    if (skipSections.some(section => line.includes(section))) return true;
    if (line.match(/^\d+\s+min$/) || line.match(/^(mittel|leicht|gering)$/)) return true;
    if (line.includes('*Dieser Artikel') || line.includes('**Ersparnis') || 
        line.includes('***Der Vorteil') || line.includes('****') ||
        line.includes('PENNY Markt GmbH') || line.includes('Domstraße')) return true;
    if (line.match(/^[😉]$/)) return true; // Emoji-only lines
    return false;
  }
  
  // Hauptparsing-Logik: Suche nach Preis-Zeilen und extrahiere Angebote
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    if (shouldSkip(line)) continue;
    
    // Suche nach Preis-Zeilen (z.B. "1.39*", "1.69", "UVP 2.29")
    const priceMatch = line.match(/^([\d.,]+)\*?$/);
    const uvpMatch = line.match(/^UVP\s+([\d.,]+)$/);
    
    if (priceMatch || uvpMatch) {
      const priceStr = (priceMatch?.[1] || '').replace(',', '.');
      const price = parseFloat(priceStr);
      
      if (!isNaN(price) && price >= 0 && price < 10000) {
        // Erstelle neues Angebot
        const offer = {
          title: '',
          brand: '',
          price: price,
          originalPrice: null,
          discount: null,
          unit: '',
          pricePerUnit: null,
          pricePerUnitWithApp: null,
          category: '',
          retailer: 'PENNY',
          validFrom: validFromDate,
          validTo: validToDate,
          note: null,
          appOnly: false,
        };
        
        // Suche nach UVP in den nächsten Zeilen
        if (uvpMatch) {
          offer.originalPrice = parseFloat(uvpMatch[1].replace(',', '.'));
        }
        
        // Suche nach Titel und Marke in den umgebenden Zeilen (vorherige 5 und nächste 10 Zeilen)
        const contextStart = Math.max(0, i - 5);
        const contextEnd = Math.min(lines.length, i + 10);
        
        for (let j = contextStart; j < contextEnd; j++) {
          if (j === i) continue; // Überspringe die Preis-Zeile selbst
          const contextLine = lines[j];
          if (shouldSkip(contextLine)) continue;
          
          // UVP-Erkennung
          const uvpContextMatch = contextLine.match(/^UVP\s+([\d.,]+)$/);
          if (uvpContextMatch && !offer.originalPrice) {
            offer.originalPrice = parseFloat(uvpContextMatch[1].replace(',', '.'));
          }
          
          // Rabatt-Erkennung
          const discountMatch = contextLine.match(/-(\d+)%/);
          const discountTextMatch = contextLine.match(/(\d+)%\s+Rabatt/);
          if (discountMatch || discountTextMatch) {
            const discountValue = discountMatch ? parseInt(discountMatch[1]) : 
                                discountTextMatch ? parseInt(discountTextMatch[1]) : null;
            if (discountValue) {
              offer.discount = discountValue;
            }
          }
          
          // "Nur mit App" Erkennung
          if (contextLine.includes('Nur mit App')) {
            offer.appOnly = true;
          }
          
          // Marke-Erkennung (GROSSBUCHSTABEN, bekannte Marken)
          const brandPattern = /^[A-Z][A-Z\s\/&.'-]+$/;
          if (contextLine.match(brandPattern) && contextLine.length > 2 && contextLine.length < 50 &&
              !contextLine.match(/\d/) && !contextLine.includes('=') && !contextLine.includes('€') &&
              !['XXL', 'UVP', 'Aktion', 'Preisknaller', 'Nur mit App', 'Aktion', 'Preisknaller'].includes(contextLine)) {
            if (!offer.brand || offer.brand.length < contextLine.length) {
              offer.brand = contextLine;
            }
          }
          
          // Titel-Erkennung (alles andere, was nicht Preis, Marke, Einheit etc. ist)
          if (contextLine && 
              !contextLine.match(/^[\d.,]+\*?$/) && // Nicht nur Preis
              !contextLine.match(/^UVP\s+[\d.,]+$/) && // Nicht UVP
              !contextLine.match(/^-?\d+%/) && // Nicht Rabatt
              !contextLine.includes('Nur mit App') &&
              !contextLine.match(/^je\s+/) && // Nicht Einheit
              !contextLine.match(/\(1\s+(?:kg|l|m)\s*=\s*[\d.,]+\)/) && // Nicht Preis pro Einheit
              !contextLine.match(brandPattern) && // Nicht nur Marke
              !contextLine.includes('mit App:') && !contextLine.includes('ohne App:') &&
              contextLine.length > 3 && contextLine.length < 200 &&
              !contextLine.includes('Rezept') && !contextLine.includes('min') &&
              !contextLine.match(/^(mittel|leicht|gering)$/)) {
            
            // Wenn Titel noch leer oder zu kurz, setze Titel
            if (!offer.title || offer.title.length < contextLine.length) {
              // Entferne Preis aus Titel, falls vorhanden
              const cleanTitle = contextLine.replace(/\s*[\d.,]+\*?\s*$/, '').trim();
              if (cleanTitle && cleanTitle.length > 3) {
                offer.title = cleanTitle;
              }
            }
          }
          
          // Einheit-Erkennung
          const unitMatch = contextLine.match(/je\s+([\d.,]+\s*(?:kg|l|g|ml|m|Stück|Stk|Pack|Packung|Korb|Kiste|Netz|Set|Stück-Packung|kg-Netz|kg-Korb|kg-Kiste|g|ml|l|I|Stück|Stk|Stück-Packung|g-Packung|ml|I))/i);
          if (unitMatch && !offer.unit) {
            offer.unit = unitMatch[1].trim();
          }
          
          // Preis pro Einheit
          const pricePerUnitMatch = contextLine.match(/\(1\s+(?:kg|l|m)\s*=\s*([\d.,]+)\)/);
          const pricePerUnitWithAppMatch = contextLine.match(/mit App:\s*je\s+[^;]+\(1\s+(?:kg|l|m)\s*=\s*([\d.,]+)\)/);
          const pricePerUnitWithoutAppMatch = contextLine.match(/ohne App:\s*je\s+[^;]+\(1\s+(?:kg|l|m)\s*=\s*([\d.,]+)\)/);
          
          if (pricePerUnitWithAppMatch) {
            offer.pricePerUnitWithApp = parseFloat(pricePerUnitWithAppMatch[1].replace(',', '.'));
          } else if (pricePerUnitWithoutAppMatch) {
            offer.pricePerUnit = parseFloat(pricePerUnitWithoutAppMatch[1].replace(',', '.'));
          } else if (pricePerUnitMatch && !offer.pricePerUnit) {
            offer.pricePerUnit = parseFloat(pricePerUnitMatch[1].replace(',', '.'));
          }
        }
        
        // Speichere Angebot nur wenn es einen Titel oder Preis hat
        if (offer.title || offer.price !== null) {
          offers.push(offer);
        }
      }
    }
  }
  
  // Entferne Duplikate basierend auf Titel und Preis
  const uniqueOffers = [];
  const seen = new Set();
  
  for (const offer of offers) {
    const key = `${offer.title}|${offer.price}`;
    if (!seen.has(key) && offer.title && offer.price !== null) {
      seen.add(key);
      uniqueOffers.push(offer);
    }
  }
  
  return uniqueOffers;
}

async function main() {
  const { year, week, weekKey } = getYearWeek();
  const outputDir = resolve(__dirname, '../../media/prospekte/penny');
  await fs.mkdir(outputDir, { recursive: true });
  const outputPath = join(outputDir, `offers_${weekKey}.json`);

  console.log('📦 Parse PENNY Angebote...');

  // Lese den vollständigen Text aus der Datei oder von stdin
  const inputPath = join(outputDir, 'penny_full_text.txt');
  let pennyText = '';
  
  try {
    pennyText = await fs.readFile(inputPath, 'utf-8');
  } catch (error) {
    console.error(`⚠️  Konnte Datei ${inputPath} nicht lesen. Erstelle sie...`);
    // Erstelle die Datei mit dem Text aus der User-Query
    // Der User hat den Text bereits bereitgestellt, wir müssen ihn nur speichern
    console.log('ℹ️  Bitte füge den PENNY-Text in penny_full_text.txt ein oder übergebe ihn als Argument.');
    return;
  }

  // Parse Angebote (Mo-Sa = Montag bis Samstag)
  const validFrom = '2025-11-24'; // Montag
  const validTo = '2025-11-29';   // Samstag
  
  const offers = parsePennyOffers(pennyText, validFrom, validTo);

  const result = {
    totalOffers: offers.length,
    retailer: 'PENNY',
    weekKey,
    validFrom,
    validTo,
    offers,
    extractedAt: new Date().toISOString(),
  };

  await fs.writeFile(outputPath, JSON.stringify(result, null, 2), 'utf-8');

  console.log(`✅ ${offers.length} Angebote gefunden`);
  console.log(`✅ JSON gespeichert: ${outputPath}`);
  console.log('\n📊 Erste 10 Angebote:\n');
  offers.slice(0, 10).forEach((offer, index) => {
    console.log(`${index + 1}. ${offer.title}`);
    if (offer.brand) console.log(`   Marke: ${offer.brand}`);
    if (offer.price !== null) console.log(`   Preis: ${offer.price}€`);
    if (offer.unit) console.log(`   Einheit: ${offer.unit}`);
    if (offer.discount) console.log(`   Rabatt: ${offer.discount}%`);
    if (offer.appOnly) console.log(`   ⚠️  Nur mit App`);
    console.log('');
  });
}

main().catch(console.error);

