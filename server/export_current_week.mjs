#!/usr/bin/env node
/**
 * Exportiert die AKTUELLEN Lidl-Angebote für ChatGPT
 * Filtert automatisch nur Lebensmittel
 */

import fs from 'fs';
import path from 'path';

// Finde die neueste offers.json
const dataDir = 'data/lidl/2025';
const weeks = fs.readdirSync(dataDir).filter(f => f.startsWith('W')).sort().reverse();

if (weeks.length === 0) {
  console.error('❌ Keine Angebote gefunden!');
  console.error('Führe zuerst aus: npm run fetch:lidl');
  process.exit(1);
}

const latestWeek = weeks[0];
const offersPath = path.join(dataDir, latestWeek, 'offers_1.json');

console.log(`📅 Verarbeite Woche: ${latestWeek}`);
console.log(`📁 Datei: ${offersPath}\n`);

const data = JSON.parse(fs.readFileSync(offersPath, 'utf-8'));
const allOffers = data.offers || data;

console.log(`📊 Gesamt: ${allOffers.length} Angebote gefunden`);

// Lebensmittel-Filter (verbessert)
const foodKeywords = [
  // Fleisch & Wurst
  'fleisch', 'wurst', 'schinken', 'salami', 'bratwurst', 'hackfleisch', 'gyros', 
  'steak', 'schnitzel', 'chicken', 'hähnchen', 'pute', 'rind', 'schwein',
  
  // Fisch
  'fisch', 'lachs', 'thunfisch', 'forelle', 'garnele', 'shrimp', 'hering',
  
  // Milchprodukte
  'käse', 'milch', 'butter', 'joghurt', 'quark', 'sahne', 'creme', 'frischkäse',
  'mozzarella', 'gouda', 'camembert', 'parmesan',
  
  // Obst & Gemüse
  'obst', 'gemüse', 'salat', 'tomate', 'gurke', 'paprika', 'kartoffel',
  'zwiebel', 'apfel', 'banane', 'orange', 'beeren', 'karotte',
  
  // Backwaren
  'brot', 'brötchen', 'toast', 'kuchen', 'torte', 'gebäck', 'croissant',
  
  // Fertiggerichte & TK
  'pizza', 'lasagne', 'fischstäbchen', 'pommes', 'tk-', 'tiefkühl',
  
  // Getränke
  'saft', 'wasser', 'cola', 'limo', 'bier', 'wein', 'prosecco', 'kaffee', 'tee',
  
  // Süßigkeiten & Snacks
  'schokolade', 'keks', 'bonbon', 'gummi', 'chips', 'nüsse', 'eis',
  
  // Grundnahrungsmittel
  'nudeln', 'pasta', 'reis', 'mehl', 'zucker', 'öl', 'essig', 'sauce', 'soße',
  'gewürz', 'pesto', 'aufstrich', 'marmelade', 'honig', 'müsli', 'cornflakes',
];

// Ausschluss-Keywords (Geräte, Werkzeug, etc.)
const excludeKeywords = [
  'werkzeug', 'bohrmaschine', 'schrauber', 'akku', 'fernseher', 'tv', 'display',
  'smartphone', 'tablet', 'laptop', 'computer', 'maus', 'tastatur', 'monitor',
  'drucker', 'scanner', 'waschmaschine', 'trockner', 'staubsauger', 'bügel',
  'föhn', 'rasierer', 'kleidung', 'hose', 'jacke', 'pullover', 'schuhe',
  'spielzeug', 'puppe', 'auto', 'fahrrad', 'helm', 'rucksack', 'koffer',
];

const foodOffers = allOffers.filter(offer => {
  const searchText = [
    offer.title || '',
    offer.description || '',
    offer.brand || '',
    ...(offer.categories || [])
  ].join(' ').toLowerCase();
  
  // Ausschließen
  if (excludeKeywords.some(kw => searchText.includes(kw))) {
    return false;
  }
  
  // Einschließen
  return foodKeywords.some(kw => searchText.includes(kw));
});

console.log(`🍎 Lebensmittel gefunden: ${foodOffers.length}\n`);

if (foodOffers.length === 0) {
  console.error('❌ Keine Lebensmittel gefunden!');
  console.error('💡 Versuche: npm run fetch:lidl');
  process.exit(1);
}

// Formatiere für ChatGPT
let output = `# LIDL ANGEBOTE - WOCHE ${latestWeek}\n\n`;
output += `📊 **${foodOffers.length} Lebensmittel-Angebote**\n`;
output += `📅 Gültig ab: ${new Date().toLocaleDateString('de-DE')}\n\n`;
output += '---\n\n';

foodOffers.forEach((offer, i) => {
  output += `## ${i + 1}. ${offer.title}\n`;
  output += `- **Preis:** ${offer.price} €`;
  if (offer.unit) output += ` (${offer.unit})`;
  output += '\n';
  
  if (offer.brand) {
    output += `- **Marke:** ${offer.brand}\n`;
  }
  
  if (offer.originalPrice && offer.originalPrice > offer.price) {
    const discount = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
    output += `- **Statt:** ${offer.originalPrice} € (-${discount}%)\n`;
  }
  
  if (offer.description && offer.description.length > 0) {
    const desc = offer.description.substring(0, 200).replace(/\n/g, ' ');
    output += `- **Info:** ${desc}${offer.description.length > 200 ? '...' : ''}\n`;
  }
  
  if (offer.categories && offer.categories.length > 0) {
    const cats = offer.categories.map(c => c.split('/').pop()).join(', ');
    output += `- **Kategorie:** ${cats}\n`;
  }
  
  output += '\n---\n\n';
});

// Statistik
output += '\n## 📊 STATISTIK\n\n';
const prices = foodOffers.map(o => o.price).filter(p => p && p > 0);
const avgPrice = (prices.reduce((a, b) => a + b, 0) / prices.length).toFixed(2);
output += `- **Angebote:** ${foodOffers.length}\n`;
output += `- **Durchschnittspreis:** ${avgPrice} €\n`;

const cheapest = foodOffers.filter(o => o.price > 0).reduce((min, o) => o.price < min.price ? o : min, foodOffers[0]);
output += `- **Günstigstes:** ${cheapest.title} (${cheapest.price} €)\n`;

const expensive = foodOffers.reduce((max, o) => (o.price || 0) > (max.price || 0) ? o : max, foodOffers[0]);
output += `- **Teuerstes:** ${expensive.title} (${expensive.price} €)\n`;

// Kategorien
const categories = {};
foodOffers.forEach(o => {
  if (o.categories && o.categories.length > 0) {
    const cat = o.categories[0].split('/').pop() || 'Sonstige';
    categories[cat] = (categories[cat] || 0) + 1;
  }
});

if (Object.keys(categories).length > 0) {
  output += `\n### Top Kategorien:\n`;
  Object.entries(categories)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .forEach(([cat, count]) => {
      output += `- ${cat}: ${count} Angebote\n`;
    });
}

// Speichern
const outputPath = 'lidl_for_chatgpt.txt';
fs.writeFileSync(outputPath, output);

console.log('✅ FERTIG!\n');
console.log(`📁 Exportiert: ${outputPath}`);
console.log(`📊 Angebote: ${foodOffers.length}`);
console.log(`💾 Größe: ${(output.length / 1024).toFixed(1)} KB\n`);
console.log('═'.repeat(70));
console.log('🎯 NÄCHSTE SCHRITTE:\n');
console.log('1. Text kopieren (macOS):');
console.log(`   cat ${outputPath} | pbcopy\n`);
console.log('2. Text kopieren (Linux):');
console.log(`   cat ${outputPath} | xclip -selection clipboard\n`);
console.log('3. In ChatGPT einfügen mit diesem Prompt:');
console.log('   "Erstelle mir 10 kreative Rezepte für 2 Personen');
console.log('    basierend auf diesen Lidl-Angeboten (nutze viele davon):"\n');
console.log('═'.repeat(70));

