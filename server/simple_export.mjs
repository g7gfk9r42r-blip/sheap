#!/usr/bin/env node
/**
 * Einfacher Export für Lidl-Angebote - Unterstützt alle Formate
 */

import fs from 'fs';

// Lese lidl.json direkt (die echten Lebensmittel!)
const data = JSON.parse(fs.readFileSync('media/prospekte/lidl/lidl.json', 'utf-8'));

console.log(`📊 ${data.length} Angebote gefunden\n`);

let output = '# LIDL LEBENSMITTEL-ANGEBOTE\n\n';
output += `Gesamt: ${data.length} Angebote\n\n`;
output += '---\n\n';

data.forEach((item, i) => {
  const title = item.product || item.title || 'Unbekannt';
  const price = item.price || 0;
  const weight = item.weight || item.unit || '';
  const brand = item.brand || '';
  const category = item.category || '';
  const discount = item.discount_percent ? ` (-${Math.abs(item.discount_percent)}%)` : '';
  
  output += `## ${i+1}. ${title}\n`;
  output += `- **Preis:** ${price} €`;
  if (weight) output += ` (${weight})`;
  if (discount) output += discount;
  output += '\n';
  if (brand) output += `- **Marke:** ${brand}\n`;
  if (category) output += `- **Kategorie:** ${category}\n`;
  if (item.price_per_kg) output += `- **Preis pro kg:** ${item.price_per_kg} €/kg\n`;
  output += '\n---\n\n';
});

// Statistik
output += '\n## 📊 STATISTIK\n\n';
const avgPrice = (data.reduce((sum, i) => sum + (i.price || 0), 0) / data.length).toFixed(2);
output += `- **Durchschnittspreis:** ${avgPrice} €\n`;

const cheapest = data.reduce((min, i) => (i.price || 999) < (min.price || 999) ? i : min, data[0]);
output += `- **Günstigstes:** ${cheapest.product} (${cheapest.price} €)\n`;

const expensive = data.reduce((max, i) => (i.price || 0) > (max.price || 0) ? i : max, data[0]);
output += `- **Teuerstes:** ${expensive.product} (${expensive.price} €)\n`;

// Kategorien
const categories = {};
data.forEach(i => {
  const cat = i.category || 'Sonstige';
  categories[cat] = (categories[cat] || 0) + 1;
});

output += `\n### Kategorien:\n`;
Object.entries(categories).sort((a, b) => b[1] - a[1]).forEach(([cat, count]) => {
  output += `- ${cat}: ${count} Angebote\n`;
});

// Speichern
fs.writeFileSync('lidl_for_chatgpt.txt', output);

console.log('✅ Exportiert nach: lidl_for_chatgpt.txt');
console.log(`📄 Dateigröße: ${(output.length / 1024).toFixed(1)} KB\n`);
console.log('🎯 NÄCHSTE SCHRITTE:\n');
console.log('1. Text kopieren (macOS):');
console.log('   cat lidl_for_chatgpt.txt | pbcopy\n');
console.log('2. In ChatGPT einfügen mit:');
console.log('   "Erstelle mir 10 Rezepte für 2 Personen basierend auf diesen Lidl-Angeboten:"\n');

