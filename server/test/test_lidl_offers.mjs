#!/usr/bin/env node
/**
 * Test-Script für Lidl Offer Extraction
 * 
 * Testet:
 * - Crawl4AI-Aufruf
 * - Bild-Extraktion
 * - GPT-Analyse
 * - Speicherung
 */

import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Lade .env
dotenv.config();
dotenv.config({ path: resolve(__dirname, '..', '.env.local'), override: false });

// Dynamischer Import (TypeScript wird zu JS kompiliert)
const fetchLidlOffersModule = await import('../dist/fetchers/fetch_lidl_offers.js');
const fetchLidlOffers = fetchLidlOffersModule.fetchLidlOffers;

async function main() {
  console.log('🧪 Lidl Offer Extraction Test\n');
  
  try {
    // Führe Extraktion aus
    console.log('📥 Starte Extraktion...\n');
    const offers = await fetchLidlOffers();
    
    console.log(`\n✅ Extraktion abgeschlossen!`);
    console.log(`📊 ${offers.length} Offers gefunden\n`);
    
    // Zeige erste 5 Offers
    if (offers.length > 0) {
      console.log('📋 Erste 5 Offers:');
      console.log('='.repeat(60));
      offers.slice(0, 5).forEach((offer, index) => {
        console.log(`\n${index + 1}. ${offer.title}`);
        console.log(`   Preis: €${offer.price.toFixed(2)}${offer.unit ? ` / ${offer.unit}` : ''}`);
        console.log(`   Bild: ${offer.imageUrl.substring(0, 60)}...`);
        if (offer.discountPercent) {
          console.log(`   Rabatt: ${offer.discountPercent}`);
        }
      });
      console.log('\n' + '='.repeat(60));
    } else {
      console.log('⚠️  Keine Offers gefunden');
    }
    
    // Prüfe ob JSON-Datei erstellt wurde
    const { readFileSync, existsSync } = await import('fs');
    const { join } = await import('path');
    const now = new Date();
    const year = now.getFullYear();
    const week = Math.ceil((now - new Date(year, 0, 1)) / (7 * 24 * 60 * 60 * 1000));
    const weekKey = `${year}-W${week.toString().padStart(2, '0')}`;
    const jsonPath = join(__dirname, '..', 'data', 'offers', 'lidl', String(year), weekKey, 'offers.json');
    
    if (existsSync(jsonPath)) {
      const jsonData = JSON.parse(readFileSync(jsonPath, 'utf-8'));
      console.log(`\n💾 JSON-Datei erstellt: ${jsonPath}`);
      console.log(`   Enthält: ${jsonData.count} Offers`);
    } else {
      console.log(`\n⚠️  JSON-Datei nicht gefunden: ${jsonPath}`);
    }
    
    console.log('\n🎉 Test erfolgreich abgeschlossen!');
    
  } catch (error) {
    console.error('\n❌ Fehler:', error instanceof Error ? error.message : String(error));
    if (process.env.DEBUG) {
      console.error('Stack:', error instanceof Error ? error.stack : '');
    }
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('❌ Unerwarteter Fehler:', err);
  process.exit(1);
});

