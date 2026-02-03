#!/usr/bin/env node
/**
 * Exportiert NUR echte Lebensmittel & Getränke aus Lidl-Angeboten
 * Strenger Filter - nur essbare/trinkbare Produkte
 */

import fs from 'fs';
import path from 'path';

const dataDir = 'data/lidl/2025';
const weeks = fs.readdirSync(dataDir).filter(f => f.startsWith('W')).sort().reverse();
const latestWeek = weeks[0];
const offersPath = path.join(dataDir, latestWeek, 'offers_1.json');

console.log(`📅 Woche: ${latestWeek}\n`);

const data = JSON.parse(fs.readFileSync(offersPath));
const allOffers = data.offers || data;

// SEHR STRENGER Filter: NUR Lebensmittel & Getränke
const foodOffers = allOffers.filter(offer => {
  const cats = (offer.categories || []).join(' ').toLowerCase();
  
  // Kategorie-basierte Filterung (am zuverlässigsten!)
  if (cats.includes('wein') || cats.includes('spirituosen')) {
    return true; // Alkohol ist OK
  }
  
  const title = (offer.title || '').toLowerCase();
  const desc = (offer.description || '').toLowerCase(); 
  const text = title + ' ' + desc + ' ' + cats;
  
  // STRIKT AUSSCHLIESSEN (Geräte, Geschirr, etc.)
  const excludeStrict = [
    // Geräte & Maschinen
    'maschine', 'automat', 'gerät', 'apparat', 'mixer', 'juicer',
    'sprudler', 'aufschäumer', 'pad', 'kapsel',
    
    // Geschirr & Küchen-Utensilien
    'glas', 'gläser', 'tasse', 'becher', 'flasche', 'karaffe',
    'besteck', 'messer', 'gabel', 'löffel',
    'dose', 'dosen', 'behälter', 'vorrats',
    'topf', 'töpfe', 'pfanne', 'bräter',
    
    // Andere Non-Food
    'textil', 'kleidung', 'möbel', 'werkzeug', 'spielzeug',
    'schrank', 'gefrier', 'kühl', 'wäsche',
  ];
  
  if (excludeStrict.some(kw => title.includes(kw))) {
    return false;
  }
  
  // NUR EINSCHLIESSEN: Echte Lebensmittel & Getränke
  const onlyFood = [
    // Fleisch & Wurst
    'fleisch', 'wurst', 'schinken', 'salami', 'steak', 'schnitzel',
    'bratwurst', 'hackfleisch', 'gyros', 'burger', 'rind', 'schwein',
    'hähnchen', 'chicken', 'pute', 'ente', 'gans',
    
    // Fisch & Meeresfrüchte
    'fisch', 'lachs', 'thunfisch', 'forelle', 'hering', 'garnele',
    'shrimp', 'muschel', 'tintenfisch',
    
    // Milchprodukte & Käse
    'käse', 'milch', 'butter', 'joghurt', 'quark', 'sahne',
    'frischkäse', 'mozzarella', 'gouda', 'camembert', 'parmesan',
    'pudding', 'dessert',
    
    // Backwaren
    'brot', 'brötchen', 'toast', 'kuchen', 'torte', 'gebäck',
    'croissant', 'bagel',
    
    // Obst & Gemüse
    'obst', 'frucht', 'gemüse', 'salat', 'tomate', 'gurke',
    'paprika', 'kartoffel', 'zwiebel', 'karotte', 'apfel',
    'banane', 'orange', 'beeren', 'erdbeere', 'traube',
    
    // Fertiggerichte & TK
    'pizza', 'lasagne', 'nudel', 'pasta', 'reis',
    'fischstäbchen', 'pommes', 'tk-', 'tiefkühl',
    
    // Getränke (nicht-alkoholisch)
    'saft', 'wasser', 'cola', 'limo', 'limonade',
    'kaffee beans', 'tee', 'kakao',
    
    // Süßigkeiten & Snacks
    'schokolade', 'schoko', 'praline', 'keks', 'cookie',
    'bonbon', 'gummi', 'chips', 'nüsse', 'eis', 'eiscreme',
    
    // Grundnahrungsmittel & Würzmittel
    'öl', 'essig', 'gewürz', 'salz', 'pfeffer',
    'sauce', 'soße', 'ketchup', 'senf', 'mayo',
    'pesto', 'aufstrich', 'marmelade', 'honig',
    'müsli', 'cornflakes', 'cerealien',
    
    // Alkohol (falls nicht über Kategorie erfasst)
    'wein', 'rotwein', 'weißwein', 'prosecco', 'champagner',
    'bier', 'whisky', 'gin', 'vodka', 'rum', 'schnaps',
    'likör', 'cognac', 'brandy',
  ];
  
  return onlyFood.some(kw => text.includes(kw));
});

console.log(`🍎 Echte Lebensmittel/Getränke: ${foodOffers.length}\n`);

if (foodOffers.length === 0) {
  console.error('❌ Keine Lebensmittel gefunden!');
  process.exit(1);
}

// Formatiere für ChatGPT
let output = `# LIDL LEBENSMITTEL & GETRÄNKE - WOCHE ${latestWeek}\n\n`;
output += `📊 **${foodOffers.length} Angebote**\n`;
output += `📅 Aktuell gültig\n\n`;
output += '---\n\n';

foodOffers.forEach((offer, i) => {
  output += `## ${i + 1}. ${offer.title}\n`;
  output += `- **Preis:** ${offer.price} €`;
  if (offer.unit) output += ` (${offer.unit})`;
  output += '\n';
  
  if (offer.brand) output += `- **Marke:** ${offer.brand}\n`;
  
  if (offer.originalPrice && offer.originalPrice > offer.price) {
    const discount = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
    output += `- **Rabatt:** ${discount}% (statt ${offer.originalPrice} €)\n`;
  }
  
  if (offer.description) {
    const desc = offer.description.substring(0, 150).replace(/\n/g, ' ').trim();
    if (desc.length > 10) {
      output += `- **Info:** ${desc}...\n`;
    }
  }
  
  output += '\n---\n\n';
});

// Statistik
const prices = foodOffers.map(o => o.price).filter(p => p > 0);
const avgPrice = (prices.reduce((a, b) => a + b, 0) / prices.length).toFixed(2);

output += '\n## 📊 STATISTIK\n\n';
output += `- **Angebote:** ${foodOffers.length}\n`;
output += `- **Durchschnittspreis:** ${avgPrice} €\n`;

const cheapest = foodOffers.filter(o => o.price > 0).reduce((min, o) => o.price < min.price ? o : min);
output += `- **Günstigstes:** ${cheapest.title} (${cheapest.price} €)\n`;

const expensive = foodOffers.reduce((max, o) => o.price > max.price ? o : max);
output += `- **Teuerstes:** ${expensive.title} (${expensive.price} €)\n`;

fs.writeFileSync('lidl_for_chatgpt.txt', output);

console.log('✅ FERTIG!\n');
console.log(`📁 Datei: lidl_for_chatgpt.txt`);
console.log(`📊 Angebote: ${foodOffers.length}`);
console.log(`💾 Größe: ${(output.length / 1024).toFixed(1)} KB\n`);
console.log('═'.repeat(70));
console.log('\n🎯 JETZT KOPIEREN:\n');
console.log('  cat lidl_for_chatgpt.txt | pbcopy\n');
console.log('🎯 CHATGPT-PROMPT:\n');
console.log('  "Erstelle mir 10 kreative Rezepte für 2 Personen');
console.log('   basierend auf diesen Lidl-Angeboten:"\n');
console.log('  [Text einfügen]\n');
console.log('═'.repeat(70));

