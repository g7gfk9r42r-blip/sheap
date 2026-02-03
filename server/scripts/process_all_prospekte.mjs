#!/usr/bin/env node
/**
 * Universal Prospekt Scraper - Main Script
 * 
 * Verarbeitet alle Prospekt-Dateien in media/prospekte/ rekursiv.
 * 
 * Verwendung:
 *   npm run build && node scripts/process_all_prospekte.mjs
 * 
 * Oder direkt:
 *   node scripts/process_all_prospekte.mjs
 */

import { scrapeAllProspekte } from '../dist/fetchers/prospekt_scraper.js';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

async function main() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║   Universal Prospekt Scraper - Wöchentliche Verarbeitung ║');
  console.log('╚═══════════════════════════════════════════════════════════╝');
  console.log('');
  
  const startTime = Date.now();
  
  try {
    const results = await scrapeAllProspekte();
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(2);
    
    console.log('\n' + '═'.repeat(50));
    console.log(`✅ Verarbeitung abgeschlossen in ${duration}s`);
    console.log('═'.repeat(50));
    
    // Exit-Code basierend auf Erfolg
    const hasFailures = results.some(r => r.failedFiles > 0);
    process.exit(hasFailures ? 1 : 0);
    
  } catch (err) {
    console.error('\n❌ KRITISCHER FEHLER:', err);
    process.exit(1);
  }
}

main();

