#!/usr/bin/env node
// test/test_edeka_playwright.mjs
// Test für EDEKA Playwright Fetcher

import { fetchEdekaOffersPlaywright } from '../dist/fetchers/fetcher_edeka_playwright.js';

console.log('🧪 TEST – EDEKA Playwright Fetcher\n');

try {
  const offers = await fetchEdekaOffersPlaywright();
  
  console.log(`\n✅ ${offers.length} Angebote gefunden\n`);
  
  if (offers.length > 0) {
    console.log('📋 Erste 10 Angebote:\n');
    offers.slice(0, 10).forEach((offer, i) => {
      console.log(`${i + 1}. ${offer.title}`);
      console.log(`   💰 ${offer.price}€${offer.unit ? ` / ${offer.unit}` : ''}`);
      if (offer.discountPercent) console.log(`   🏷️  Rabatt: -${offer.discountPercent}%`);
      if (offer.originalPrice) console.log(`   📊 Original: ${offer.originalPrice}€`);
      console.log('');
    });
  }
} catch (err) {
  console.error('❌ Fehler:', err);
  process.exit(1);
}

