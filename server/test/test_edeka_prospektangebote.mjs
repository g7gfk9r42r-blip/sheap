#!/usr/bin/env node
// test/test_edeka_prospektangebote.mjs
// Test für EDEKA-Prospektangebote.de Fetcher

import { fetchEdekaOffersProspektangebote } from '../dist/fetchers/fetcher_edeka_prospektangebote.js';

console.log('🧪 TEST – EDEKA Prospektangebote.de Fetcher\n');

try {
  const offers = await fetchEdekaOffersProspektangebote();
  
  console.log(`\n✅ ${offers.length} Angebote gefunden\n`);
  
  if (offers.length > 0) {
    console.log('📋 Erste 10 Angebote:\n');
    offers.slice(0, 10).forEach((offer, i) => {
      console.log(`${i + 1}. ${offer.title}`);
      console.log(`   💰 ${offer.price}€${offer.unit ? ` / ${offer.unit}` : ''}`);
      if (offer.discountPercent) console.log(`   🏷️  Rabatt: ${offer.discountPercent}`);
      console.log('');
    });
  }
} catch (err) {
  console.error('❌ Fehler:', err);
  process.exit(1);
}

