#!/usr/bin/env node

/**
 * PROSPEKT PARSER
 * 
 * Wandelt Rohdaten (Prospekt-Text) in strukturierte JSON um
 * Verwendet GPT-4 für intelligentes Parsing
 * 
 * USAGE:
 *   node parse_prospekt.mjs netto prospekt.txt
 *   node parse_prospekt.mjs lidl prospekt.txt
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config({ path: '../../.env' });

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// ============================================================
// CONFIGURATION
// ============================================================

const RETAILERS = [
  'netto', 'lidl', 'aldi_nord', 'aldi_sued', 'edeka', 
  'rewe', 'kaufland', 'penny', 'norma', 'real'
];

// ============================================================
// HELPER FUNCTIONS
// ============================================================

/**
 * Liest Rohdaten aus Datei oder stdin
 */
function loadRawData(filePath) {
  if (!filePath || filePath === '-') {
    // Von stdin lesen
    console.log('📝 Bitte Prospekt-Text eingeben (Ctrl+D zum Beenden):');
    return fs.readFileSync(0, 'utf-8');
  }

  if (!fs.existsSync(filePath)) {
    throw new Error(`Datei nicht gefunden: ${filePath}`);
  }

  return fs.readFileSync(filePath, 'utf-8');
}

/**
 * Bereinigt Rohdaten (entfernt Duplikate, unnötige Zeilen)
 */
function cleanRawData(raw) {
  // Zeilen deduplizieren (viele Prospekte wiederholen sich)
  const lines = raw.split('\n');
  const seen = new Set();
  const unique = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed && !seen.has(trimmed)) {
      seen.add(trimmed);
      unique.push(trimmed);
    }
  }

  return unique.join('\n');
}

/**
 * Parst Rohdaten mit GPT-4 in strukturierte JSON
 */
async function parseWithGPT(retailer, rawData) {
  console.log(`\n🤖 Parse Prospekt mit GPT-4...`);
  console.log(`   Retailer: ${retailer}`);
  console.log(`   Zeichen: ${rawData.length}`);

  const systemPrompt = `Du bist ein Experte für Supermarkt-Prospekte und Datenextraktion.

AUFGABE:
Extrahiere ALLE Lebensmittel-Angebote aus dem Prospekt-Text.

STRIKTE REGELN:
1. ✅ NUR Lebensmittel (keine Haushaltswaren, Technik, Kleidung, etc.)
2. ✅ Exakte Preise extrahieren
3. ✅ Original-Preise erkennen (falls vorhanden)
4. ✅ Rabatt berechnen (falls Original-Preis vorhanden)
5. ✅ Marke identifizieren (falls genannt)
6. ✅ Einheit extrahieren (kg, Liter, Stück, etc.)
7. ✅ Kategorie zuordnen (Fleisch, Gemüse, Milchprodukte, etc.)
8. ❌ KEINE Duplikate
9. ❌ KEINE erfundenen Produkte
10. ❌ KEINE Non-Food-Artikel

KATEGORIEN:
- Fleisch & Wurst
- Obst & Gemüse
- Milchprodukte & Käse
- Brot & Backwaren
- Getränke
- Tiefkühlkost
- Konserven & Fertiggerichte
- Süßigkeiten & Snacks
- Gewürze & Saucen
- Pasta & Reis

PREIS-FORMATE:
- "2.49" → 2.49
- "2,49" → 2.49
- "1.99 statt 2.99" → price: 1.99, originalPrice: 2.99
- "–20%" → discount: "-20%"
- "0,99 / kg" → 0.99, unit: "kg"

EINHEITEN:
- kg, g, Liter, ml, Stück, Packung, Dose, Becher, etc.

JSON-FORMAT (PFLICHT):
{
  "retailer": "${retailer}",
  "validFrom": "YYYY-MM-DD" (wenn im Text gefunden),
  "validUntil": "YYYY-MM-DD" (wenn im Text gefunden),
  "totalOffers": number,
  "offers": [
    {
      "title": "string (Produktname)",
      "brand": "string|null (Marke, falls genannt)",
      "price": number (aktueller Preis),
      "originalPrice": number|null (alter Preis, falls vorhanden),
      "discount": "string|null (z.B. '-20%', falls vorhanden)",
      "unit": "string (kg, Liter, Stück, etc.)",
      "amount": "string|null (z.B. '500 g', '1 Liter')",
      "category": "string (siehe Kategorien oben)",
      "description": "string|null (zusätzliche Infos)"
    }
  ]
}

BEISPIEL:
Text: "Hackfleisch gemischt 500 g 3.49 statt 4.99"
→
{
  "title": "Hackfleisch gemischt",
  "brand": null,
  "price": 3.49,
  "originalPrice": 4.99,
  "discount": "–30%",
  "unit": "g",
  "amount": "500 g",
  "category": "Fleisch & Wurst",
  "description": "Aus 50% Schwein und 50% Rind"
}`;

  const userPrompt = `Extrahiere ALLE Lebensmittel aus diesem ${retailer}-Prospekt:

${rawData}

Antworte NUR mit validem JSON (siehe Format oben). Keine Erklärungen!`;

  try {
    console.log('⏳ Warte auf GPT-4 (kann 30-60 Sek dauern)...\n');

    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.3, // Niedriger für präzises Parsing
      response_format: { type: 'json_object' }
    });

    const response = completion.choices[0].message.content;
    const data = JSON.parse(response);

    console.log(`✅ ${data.offers?.length || 0} Angebote extrahiert\n`);

    // Statistik anzeigen
    if (data.offers && data.offers.length > 0) {
      const categories = {};
      data.offers.forEach(offer => {
        categories[offer.category] = (categories[offer.category] || 0) + 1;
      });

      console.log('📊 KATEGORIEN:');
      Object.entries(categories)
        .sort((a, b) => b[1] - a[1])
        .forEach(([cat, count]) => {
          console.log(`   ${cat}: ${count}`);
        });
      console.log('');

      // Beispiel-Angebote zeigen
      console.log('📦 BEISPIEL-ANGEBOTE:');
      data.offers.slice(0, 5).forEach((offer, idx) => {
        const priceStr = offer.originalPrice 
          ? `${offer.price}€ (statt ${offer.originalPrice}€)` 
          : `${offer.price}€`;
        console.log(`   ${idx + 1}. ${offer.title} - ${priceStr}`);
      });
      console.log('');
    }

    return data;

  } catch (error) {
    console.error(`❌ GPT-Fehler:`, error.message);
    throw error;
  }
}

/**
 * Validiert die geparsten Daten
 */
function validateData(data) {
  console.log('🔒 Validiere Daten...');

  const issues = [];

  // 1. Struktur prüfen
  if (!data.offers || !Array.isArray(data.offers)) {
    issues.push('Keine offers-Array gefunden');
  }

  // 2. Jedes Angebot prüfen
  if (data.offers) {
    data.offers.forEach((offer, idx) => {
      // Pflichtfelder
      if (!offer.title) issues.push(`Angebot ${idx + 1}: Kein Titel`);
      if (typeof offer.price !== 'number') issues.push(`Angebot ${idx + 1}: Kein gültiger Preis`);
      if (!offer.category) issues.push(`Angebot ${idx + 1}: Keine Kategorie`);

      // Preis-Plausibilität
      if (offer.price < 0 || offer.price > 1000) {
        issues.push(`Angebot ${idx + 1}: Unplausibel Preis (${offer.price}€)`);
      }

      // Original-Preis muss größer sein
      if (offer.originalPrice && offer.originalPrice <= offer.price) {
        issues.push(`Angebot ${idx + 1}: Original-Preis nicht größer`);
      }
    });
  }

  if (issues.length > 0) {
    console.log(`⚠️  ${issues.length} Validierungs-Probleme:`);
    issues.slice(0, 10).forEach(issue => console.log(`   - ${issue}`));
    if (issues.length > 10) {
      console.log(`   ... und ${issues.length - 10} weitere`);
    }
    console.log('');
  } else {
    console.log('✅ Alle Daten valide\n');
  }

  return issues.length === 0;
}

/**
 * Speichert JSON in Supermarkt-Ordner
 */
function saveJSON(retailer, data) {
  const retailerDir = path.join(PROSPEKTE_DIR, retailer);
  
  // Ordner erstellen falls nicht vorhanden
  if (!fs.existsSync(retailerDir)) {
    fs.mkdirSync(retailerDir, { recursive: true });
  }

  const outputPath = path.join(retailerDir, `${retailer}.json`);

  // Metadaten hinzufügen
  const output = {
    retailer,
    parsedAt: new Date().toISOString(),
    source: 'prospekt_text',
    ...data
  };

  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2), 'utf-8');
  console.log(`✅ JSON gespeichert: ${outputPath}`);

  return outputPath;
}

// ============================================================
// MAIN FUNCTION
// ============================================================

async function main() {
  console.log('\n📄 PROSPEKT PARSER');
  console.log('═'.repeat(60));

  // API-Key prüfen
  if (!process.env.OPENAI_API_KEY) {
    console.error('❌ OPENAI_API_KEY nicht gesetzt!');
    console.log('   Prüfe: /server/.env');
    process.exit(1);
  }

  // Argumente parsen
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('USAGE:');
    console.log('  node parse_prospekt.mjs <retailer> <file>');
    console.log('  node parse_prospekt.mjs <retailer> -    (stdin)');
    console.log('');
    console.log('BEISPIELE:');
    console.log('  node parse_prospekt.mjs netto netto_prospekt.txt');
    console.log('  cat prospekt.txt | node parse_prospekt.mjs lidl -');
    console.log('');
    console.log('RETAILER:');
    RETAILERS.forEach(r => console.log(`  - ${r}`));
    process.exit(1);
  }

  const retailer = args[0].toLowerCase();
  const inputFile = args[1] || '-';

  // Retailer validieren
  if (!RETAILERS.includes(retailer)) {
    console.error(`❌ Unbekannter Retailer: ${retailer}`);
    console.log(`   Erlaubt: ${RETAILERS.join(', ')}`);
    process.exit(1);
  }

  console.log(`Retailer: ${retailer}`);
  console.log(`Input: ${inputFile === '-' ? 'stdin' : inputFile}`);
  console.log('═'.repeat(60));

  // 1. Rohdaten laden
  console.log('\n📖 Lade Rohdaten...');
  const rawData = loadRawData(inputFile);
  console.log(`✅ ${rawData.length} Zeichen geladen`);

  // 2. Bereinigen
  const cleanData = cleanRawData(rawData);
  console.log(`✅ ${cleanData.length} Zeichen nach Bereinigung`);

  // 3. Mit GPT parsen
  const parsedData = await parseWithGPT(retailer, cleanData);

  // 4. Validieren
  const isValid = validateData(parsedData);

  if (!isValid) {
    console.log('⚠️  Daten enthalten Fehler, aber werden trotzdem gespeichert');
  }

  // 5. Speichern
  const outputPath = saveJSON(retailer, parsedData);

  console.log('\n═'.repeat(60));
  console.log('✅ PARSING ERFOLGREICH!');
  console.log('═'.repeat(60));
  console.log(`\nNächster Schritt:`);
  console.log(`  node tools/recipes/test_single.mjs ${retailer}`);
  console.log(`  # Generiert Rezepte aus den geparsten Angeboten`);
}

main().catch(error => {
  console.error('\n❌ FEHLER:', error);
  process.exit(1);
});

