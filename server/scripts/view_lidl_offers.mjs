#!/usr/bin/env node
/**
 * Zeigt alle Lidl-Offers aus SQLite an
 * 
 * Usage:
 *   node scripts/view_lidl_offers.mjs           # Alle Offers
 *   node scripts/view_lidl_offers.mjs --json    # Als JSON
 *   node scripts/view_lidl_offers.mjs --count   # Nur Anzahl
 *   node scripts/view_lidl_offers.mjs --week 2025-W47  # Spezifische Woche
 */

import { adapter } from '../dist/db.js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load environment variables
dotenv.config({ path: resolve(__dirname, '../.env') });
dotenv.config({ path: resolve(__dirname, '../.env.local'), override: false });

// Parse arguments
const args = process.argv.slice(2);
const flags = {
  json: args.includes('--json'),
  count: args.includes('--count'),
  week: args.find(arg => arg.startsWith('--week='))?.split('=')[1] || null,
  details: args.includes('--details'),
};

// Get current week if not specified
function getCurrentWeek() {
  const now = new Date();
  const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  const year = d.getUTCFullYear();
  const week = String(weekNo).padStart(2, '0');
  return `${year}-W${week}`;
}

async function main() {
  try {
    // Load database
    await adapter.load();
    
    const weekKey = flags.week || getCurrentWeek();
    
    // Get offers
    const offers = adapter.getOffers('LIDL', weekKey);
    
    if (flags.count) {
      console.log(`📦 ${offers.length} Lidl-Offers gefunden (Woche: ${weekKey})`);
      return;
    }
    
    if (flags.json) {
      console.log(JSON.stringify(offers, null, 2));
      return;
    }
    
    // Detailed view
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`📦 Lidl-Offers - Woche: ${weekKey}`);
    console.log(`📊 Gesamt: ${offers.length} Angebote`);
    console.log('═══════════════════════════════════════════════════════════\n');
    
    if (offers.length === 0) {
      console.log('⚠️  Keine Offers gefunden für diese Woche.');
      return;
    }
    
    // Group by page
    const byPage = {};
    offers.forEach(offer => {
      const page = offer.page || 0;
      if (!byPage[page]) {
        byPage[page] = [];
      }
      byPage[page].push(offer);
    });
    
    // Show offers
    Object.keys(byPage).sort((a, b) => Number(a) - Number(b)).forEach(page => {
      const pageOffers = byPage[page];
      console.log(`\n📄 Seite ${page} (${pageOffers.length} Angebote)`);
      console.log('─'.repeat(60));
      
      pageOffers.forEach((offer, index) => {
        console.log(`\n${index + 1}. ${offer.title}`);
        console.log(`   💰 Preis: ${offer.price.toFixed(2)}€ / ${offer.unit}`);
        if (offer.originalPrice) {
          const discount = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
          console.log(`   💵 Ursprungspreis: ${offer.originalPrice.toFixed(2)}€ (${discount}% Rabatt)`);
        }
        if (offer.brand) {
          console.log(`   🏷️  Marke: ${offer.brand}`);
        }
        if (offer.imageUrl) {
          console.log(`   🖼️  Bild: ${offer.imageUrl.substring(0, 60)}...`);
        }
        if (flags.details) {
          console.log(`   📅 Gültig: ${new Date(offer.validFrom).toLocaleDateString('de-DE')} - ${new Date(offer.validTo).toLocaleDateString('de-DE')}`);
          console.log(`   🔑 ID: ${offer.id}`);
        }
      });
    });
    
    // Summary
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('📊 Zusammenfassung:');
    console.log(`   Gesamt: ${offers.length} Angebote`);
    console.log(`   Seiten: ${Object.keys(byPage).length}`);
    console.log(`   Mit Rabatt: ${offers.filter(o => o.originalPrice).length}`);
    console.log(`   Mit Marke: ${offers.filter(o => o.brand).length}`);
    console.log(`   Mit Bild: ${offers.filter(o => o.imageUrl).length}`);
    console.log('═══════════════════════════════════════════════════════════\n');
    
  } catch (error) {
    console.error('❌ Fehler:', error.message);
    if (process.env.DEBUG) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();

