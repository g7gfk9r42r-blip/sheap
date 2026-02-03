#!/usr/bin/env node
/**
 * Validiert Lidl-Offers und prüft auf Probleme
 * 
 * Usage:
 *   node scripts/validate_lidl_offers.mjs
 *   node scripts/validate_lidl_offers.mjs --week 2025-W47
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
  week: args.find(arg => arg.startsWith('--week='))?.split('=')[1] || null,
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

function validateOffer(offer, index) {
  const errors = [];
  const warnings = [];
  
  // Required fields
  if (!offer.id) errors.push('Fehlende ID');
  if (!offer.title || offer.title.trim().length === 0) errors.push('Fehlender oder leerer Titel');
  if (!offer.title || offer.title === 'Unbekanntes Produkt') warnings.push('Generischer Titel "Unbekanntes Produkt"');
  if (typeof offer.price !== 'number' || offer.price <= 0) errors.push('Ungültiger Preis');
  if (!offer.unit || offer.unit.trim().length === 0) warnings.push('Fehlende Einheit');
  if (!offer.validFrom) errors.push('Fehlendes Gültigkeitsdatum (validFrom)');
  if (!offer.validTo) errors.push('Fehlendes Gültigkeitsdatum (validTo)');
  
  // Data quality
  if (offer.price > 1000) warnings.push('Sehr hoher Preis (>1000€) - möglicher Fehler?');
  if (offer.title.length < 3) warnings.push('Sehr kurzer Titel (<3 Zeichen)');
  if (offer.title.length > 200) warnings.push('Sehr langer Titel (>200 Zeichen)');
  
  // Price logic
  if (offer.originalPrice && offer.originalPrice <= offer.price) {
    warnings.push('Originalpreis ist nicht höher als Angebotspreis');
  }
  
  if (offer.originalPrice && offer.price) {
    const discountPercent = Math.round(((offer.originalPrice - offer.price) / offer.originalPrice) * 100);
    if (discountPercent > 90) warnings.push(`Sehr hoher Rabatt (${discountPercent}%) - möglicher Fehler?`);
    if (discountPercent < 0) warnings.push('Negativer Rabatt - möglicher Fehler?');
  }
  
  // Image
  if (!offer.imageUrl || offer.imageUrl.trim().length === 0) {
    warnings.push('Fehlendes Bild');
  } else if (!offer.imageUrl.startsWith('http')) {
    warnings.push('Ungültige Bild-URL (kein http/https)');
  }
  
  // Dates
  if (offer.validFrom && offer.validTo) {
    const from = new Date(offer.validFrom);
    const to = new Date(offer.validTo);
    if (from > to) errors.push('Gültigkeitsdatum: "Von" ist nach "Bis"');
    if (to < new Date()) warnings.push('Gültigkeitsdatum bereits abgelaufen');
  }
  
  // Week key
  if (!offer.weekKey) warnings.push('Fehlende weekKey');
  
  return { errors, warnings };
}

async function main() {
  try {
    // Load database
    await adapter.load();
    
    const weekKey = flags.week || getCurrentWeek();
    
    // Get offers
    const offers = adapter.getOffers('LIDL', weekKey);
    
    console.log('═══════════════════════════════════════════════════════════');
    console.log(`🔍 Validierung: Lidl-Offers - Woche: ${weekKey}`);
    console.log(`📊 Gesamt: ${offers.length} Angebote`);
    console.log('═══════════════════════════════════════════════════════════\n');
    
    if (offers.length === 0) {
      console.log('⚠️  Keine Offers gefunden für diese Woche.');
      return;
    }
    
    // Validate all offers
    const validationResults = offers.map((offer, index) => ({
      offer,
      index,
      ...validateOffer(offer, index),
    }));
    
    // Count errors and warnings
    const totalErrors = validationResults.reduce((sum, r) => sum + r.errors.length, 0);
    const totalWarnings = validationResults.reduce((sum, r) => sum + r.warnings.length, 0);
    const offersWithErrors = validationResults.filter(r => r.errors.length > 0).length;
    const offersWithWarnings = validationResults.filter(r => r.warnings.length > 0).length;
    
    // Show offers with errors
    if (offersWithErrors > 0) {
      console.log('❌ Angebote mit Fehlern:\n');
      validationResults
        .filter(r => r.errors.length > 0)
        .forEach(({ offer, index, errors }) => {
          console.log(`${index + 1}. ${offer.title || '(Kein Titel)'}`);
          console.log(`   ID: ${offer.id}`);
          errors.forEach(error => {
            console.log(`   ❌ ${error}`);
          });
          console.log();
        });
    }
    
    // Show offers with warnings (first 10)
    if (offersWithWarnings > 0) {
      const warningsToShow = validationResults
        .filter(r => r.warnings.length > 0)
        .slice(0, 10);
      
      if (warningsToShow.length > 0) {
        console.log('⚠️  Angebote mit Warnungen (erste 10):\n');
        warningsToShow.forEach(({ offer, index, warnings }) => {
          console.log(`${index + 1}. ${offer.title || '(Kein Titel)'}`);
          warnings.forEach(warning => {
            console.log(`   ⚠️  ${warning}`);
          });
          if (warningsToShow.length > 10 && index === 9) {
            console.log(`   ... und ${offersWithWarnings - 10} weitere Angebote mit Warnungen`);
          }
          console.log();
        });
      }
    }
    
    // Statistics
    const validOffers = validationResults.filter(r => r.errors.length === 0).length;
    const perfectOffers = validationResults.filter(r => r.errors.length === 0 && r.warnings.length === 0).length;
    
    console.log('═══════════════════════════════════════════════════════════');
    console.log('📊 Validierungs-Ergebnisse:');
    console.log(`   ✅ Gültige Offers: ${validOffers}/${offers.length} (${Math.round(validOffers / offers.length * 100)}%)`);
    console.log(`   ⭐ Perfekte Offers: ${perfectOffers}/${offers.length} (${Math.round(perfectOffers / offers.length * 100)}%)`);
    console.log(`   ❌ Offers mit Fehlern: ${offersWithErrors} (${totalErrors} Fehler insgesamt)`);
    console.log(`   ⚠️  Offers mit Warnungen: ${offersWithWarnings} (${totalWarnings} Warnungen insgesamt)`);
    
    // Data quality metrics
    const withDiscount = offers.filter(o => o.originalPrice).length;
    const withBrand = offers.filter(o => o.brand).length;
    const withImage = offers.filter(o => o.imageUrl).length;
    const withPage = offers.filter(o => o.page !== null).length;
    
    console.log('\n📈 Datenqualität:');
    console.log(`   💰 Mit Rabatt: ${withDiscount}/${offers.length} (${Math.round(withDiscount / offers.length * 100)}%)`);
    console.log(`   🏷️  Mit Marke: ${withBrand}/${offers.length} (${Math.round(withBrand / offers.length * 100)}%)`);
    console.log(`   🖼️  Mit Bild: ${withImage}/${offers.length} (${Math.round(withImage / offers.length * 100)}%)`);
    console.log(`   📄 Mit Seitennummer: ${withPage}/${offers.length} (${Math.round(withPage / offers.length * 100)}%)`);
    
    // Price distribution
    const prices = offers.map(o => o.price).filter(p => p > 0);
    if (prices.length > 0) {
      const avgPrice = prices.reduce((a, b) => a + b, 0) / prices.length;
      const minPrice = Math.min(...prices);
      const maxPrice = Math.max(...prices);
      console.log('\n💰 Preis-Verteilung:');
      console.log(`   Durchschnitt: ${avgPrice.toFixed(2)}€`);
      console.log(`   Minimum: ${minPrice.toFixed(2)}€`);
      console.log(`   Maximum: ${maxPrice.toFixed(2)}€`);
    }
    
    console.log('═══════════════════════════════════════════════════════════\n');
    
    // Exit code
    if (totalErrors > 0) {
      console.log('❌ Validierung fehlgeschlagen: Es gibt Fehler in den Offers.');
      process.exit(1);
    } else if (totalWarnings > 0) {
      console.log('⚠️  Validierung erfolgreich, aber es gibt Warnungen.');
      process.exit(0);
    } else {
      console.log('✅ Validierung erfolgreich: Alle Offers sind korrekt!');
      process.exit(0);
    }
    
  } catch (error) {
    console.error('❌ Fehler:', error.message);
    if (process.env.DEBUG) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

main();

