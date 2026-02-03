#!/usr/bin/env node
// Entferne Duplikate aus NORMA JSON

import fs from 'fs/promises';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const jsonPath = resolve(__dirname, '../../media/prospekte/norma/offers_2025-W48.json');

async function main() {
  const content = await fs.readFile(jsonPath, 'utf-8');
  const data = JSON.parse(content);
  
  // Entferne Duplikate basierend auf Titel + Preis + validFrom
  // Behalte die Version mit der vollständigsten Marke
  const seen = new Map();
  
  for (const offer of data.offers) {
    const key = `${offer.title}|${offer.price}|${offer.validFrom}`;
    const existing = seen.get(key);
    
    if (!existing) {
      seen.set(key, offer);
    } else {
      // Behalte die Version mit der längeren/klareren Marke
      if ((offer.brand && offer.brand.length > 0) && 
          (!existing.brand || offer.brand.length > existing.brand.length)) {
        seen.set(key, offer);
      }
    }
  }
  
  const uniqueOffers = Array.from(seen.values());
  
  data.offers = uniqueOffers;
  data.totalOffers = uniqueOffers.length;
  
  await fs.writeFile(jsonPath, JSON.stringify(data, null, 2), 'utf-8');
  
  console.log(`✅ Duplikate entfernt: ${data.offers.length} eindeutige Angebote`);
  console.log(`   - Ab Montag (24.11): ${uniqueOffers.filter(o => o.validFrom === '2025-11-24').length}`);
  console.log(`   - Ab Freitag (28.11): ${uniqueOffers.filter(o => o.validFrom === '2025-11-28').length}`);
}

main().catch(console.error);

