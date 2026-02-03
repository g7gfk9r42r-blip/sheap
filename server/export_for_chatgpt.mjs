#!/usr/bin/env node
/**
 * Exportiert Lidl-Angebote aus offers.json in ein ChatGPT-freundliches Format
 * 
 * Usage:
 *   node export_for_chatgpt.mjs
 *   node export_for_chatgpt.mjs --all      # Alle Angebote (inkl. Non-Food)
 *   node export_for_chatgpt.mjs --limit 50 # Nur erste 50
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Parse Argumente
const args = process.argv.slice(2);
const includeAll = args.includes('--all');
const limitIndex = args.indexOf('--limit');
const limit = limitIndex >= 0 ? parseInt(args[limitIndex + 1], 10) : null;

// Lebensmittel-Keywords für Filterung
const foodKeywords = [
  // Basis
  'fleisch', 'fisch', 'käse', 'brot', 'milch', 'butter', 'ei', 'eier',
  'obst', 'gemüse', 'salat', 'kartoffel', 'tomate', 'gurke', 'paprika',
  
  // Wurst & Aufschnitt
  'wurst', 'schinken', 'salami', 'mortadella', 'aufschnitt',
  
  // Milchprodukte
  'joghurt', 'quark', 'sahne', 'creme', 'pudding', 'frischkäse',
  
  // Getränke
  'saft', 'wasser', 'limo', 'cola', 'bier', 'wein', 'kaffee', 'tee',
  'milch', 'kakao',
  
  // Backwaren
  'kuchen', 'torte', 'gebäck', 'keks', 'brötchen', 'croissant',
  
  // Süßigkeiten
  'schokolade', 'bonbon', 'gummi', 'eis', 'dessert',
  
  // Grundnahrungsmittel
  'nudeln', 'pasta', 'reis', 'mehl', 'zucker', 'salz', 'pfeffer',
  'öl', 'essig', 'sauce', 'soße', 'gewürz', 'ketchup', 'senf',
  'mayonnaise', 'mayo',
  
  // Fertigprodukte
  'pizza', 'lasagne', 'suppe', 'eintopf', 'fertiggericht',
  
  // Snacks
  'chips', 'nüsse', 'cracker', 'salzstange',
  
  // Spezial
  'müsli', 'cornflakes', 'cerealien', 'honig', 'marmelade', 'aufstrich',
  'pesto', 'hummus', 'oliven', 'antipasti',
  
  // Tiefkühl
  'tiefkühl', 'gefroren', 'tk-', 'frozen',
  
  // Konserven
  'dose', 'konserve', 'glas',
  
  // Bio/Vegan
  'bio', 'vegan', 'vegetarisch',
];

/**
 * Prüft ob Angebot ein Lebensmittel ist
 */
function isFoodOffer(offer) {
  if (includeAll) return true;
  
  const searchText = [
    offer.title || '',
    offer.description || '',
    offer.brand || '',
    ...(offer.categories || [])
  ].join(' ').toLowerCase();
  
  return foodKeywords.some(keyword => searchText.includes(keyword));
}

/**
 * Formatiert Angebot als Text
 */
function formatOffer(offer, index) {
  let text = `## ${index}. ${offer.title}\n`;
  
  // Preis
  text += `- **Preis:** ${offer.price} €`;
  if (offer.unit) {
    text += ` (${offer.unit})`;
  }
  text += '\n';
  
  // Marke
  if (offer.brand) {
    text += `- **Marke:** ${offer.brand}\n`;
  }
  
  // Originalpreis (wenn reduziert)
  if (offer.metadata?.originalPrice && offer.metadata.originalPrice > offer.price) {
    const discount = Math.round(((offer.metadata.originalPrice - offer.price) / offer.metadata.originalPrice) * 100);
    text += `- **Statt:** ${offer.metadata.originalPrice} € (${discount}% Rabatt)\n`;
  }
  
  // Beschreibung (kurz)
  if (offer.description && offer.description.length > 0) {
    const desc = offer.description.substring(0, 150);
    text += `- **Info:** ${desc}${offer.description.length > 150 ? '...' : ''}\n`;
  }
  
  // Kategorien
  if (offer.categories && offer.categories.length > 0) {
    text += `- **Kategorie:** ${offer.categories.join(', ')}\n`;
  }
  
  // Gültigkeit
  if (offer.validFrom || offer.validTo) {
    const from = offer.validFrom ? new Date(offer.validFrom).toLocaleDateString('de-DE') : '?';
    const to = offer.validTo ? new Date(offer.validTo).toLocaleDateString('de-DE') : '?';
    text += `- **Gültig:** ${from} bis ${to}\n`;
  }
  
  text += '\n---\n\n';
  return text;
}

/**
 * Hauptfunktion
 */
function main() {
  const offersPath = path.join(__dirname, 'offers.json');
  
  // Prüfe ob offers.json existiert
  if (!fs.existsSync(offersPath)) {
    console.error('❌ offers.json nicht gefunden!');
    console.error('');
    console.error('Führe zuerst aus:');
    console.error('  cd /Users/romw24/dev/AppProjektRoman/roman_app/server');
    console.error('  npm run view:lidl > offers.json');
    console.error('');
    console.error('Oder:');
    console.error('  npm run fetch:lidl  # Holt aktuelle Angebote');
    process.exit(1);
  }
  
  console.log('📄 Lade offers.json...');
  const data = JSON.parse(fs.readFileSync(offersPath, 'utf-8'));
  
  // Unterstütze verschiedene Formate
  let allOffers = [];
  if (Array.isArray(data)) {
    // Format: Array von Angeboten
    allOffers = data;
  } else if (data.offers && Array.isArray(data.offers)) {
    // Format: { offers: [...] }
    allOffers = data.offers;
  } else {
    console.error('❌ Ungültiges Format in offers.json');
    console.error('   Erwartet: Array oder { offers: [...] }');
    process.exit(1);
  }
  
  console.log(`   ${allOffers.length} Angebote geladen`);
  
  // Filtere Lebensmittel
  console.log('🔍 Filtere Angebote...');
  const filteredOffers = allOffers.filter(isFoodOffer);
  console.log(`   ${filteredOffers.length} Lebensmittel-Angebote gefunden`);
  
  // Limitiere falls gewünscht
  const finalOffers = limit ? filteredOffers.slice(0, limit) : filteredOffers;
  
  if (limit && finalOffers.length < filteredOffers.length) {
    console.log(`   Limitiert auf ${limit} Angebote`);
  }
  
  // Formatiere als Text
  console.log('📝 Formatiere für ChatGPT...');
  
  let output = '';
  output += '# LIDL ANGEBOTE - AKTUELLE WOCHE\n\n';
  output += `📊 **${finalOffers.length} Lebensmittel-Angebote**\n\n`;
  output += '---\n\n';
  
  finalOffers.forEach((offer, i) => {
    output += formatOffer(offer, i + 1);
  });
  
  // Füge Statistik hinzu
  output += '\n\n## 📊 STATISTIK\n\n';
  output += `- **Gesamt-Angebote:** ${finalOffers.length}\n`;
  
  const avgPrice = (finalOffers.reduce((sum, o) => sum + (o.price || 0), 0) / finalOffers.length).toFixed(2);
  output += `- **Durchschnittspreis:** ${avgPrice} €\n`;
  
  const cheapest = finalOffers.reduce((min, o) => o.price < min.price ? o : min, finalOffers[0]);
  output += `- **Günstigstes Angebot:** ${cheapest.title} (${cheapest.price} €)\n`;
  
  const expensive = finalOffers.reduce((max, o) => o.price > max.price ? o : max, finalOffers[0]);
  output += `- **Teuerstes Angebot:** ${expensive.title} (${expensive.price} €)\n`;
  
  // Speichere
  const outputPath = path.join(__dirname, 'lidl_for_chatgpt.txt');
  fs.writeFileSync(outputPath, output, 'utf-8');
  
  console.log('');
  console.log('✅ FERTIG!');
  console.log('');
  console.log(`📁 Exportiert nach: ${outputPath}`);
  console.log(`📊 Angebote: ${finalOffers.length}`);
  console.log(`💾 Dateigröße: ${(output.length / 1024).toFixed(1)} KB`);
  console.log('');
  console.log('🎯 NÄCHSTE SCHRITTE:');
  console.log('');
  console.log('1. Text kopieren (macOS):');
  console.log(`   cat "${outputPath}" | pbcopy`);
  console.log('');
  console.log('2. Text kopieren (Linux):');
  console.log(`   cat "${outputPath}" | xclip -selection clipboard`);
  console.log('');
  console.log('3. Datei öffnen:');
  console.log(`   open "${outputPath}"`);
  console.log('');
  console.log('4. In ChatGPT einfügen mit diesem Prompt:');
  console.log('');
  console.log('   "Ich habe die aktuellen Lidl-Angebote. Erstelle mir daraus');
  console.log('    10 kreative Rezepte für 2 Personen und eine Einkaufsliste."');
  console.log('');
}

main();

