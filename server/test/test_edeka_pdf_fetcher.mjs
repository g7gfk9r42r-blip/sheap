#!/usr/bin/env node
// test/test_edeka_pdf_fetcher.mjs
// Test für EDEKA PDF Fetcher

import { fetchAllEdekaPdfs, fetchEdekaPdfForRegion } from '../dist/fetchers/edeka_pdf_fetcher.js';
import { getRegionsWithPdfUrls } from '../dist/constants/edeka_regions.js';

console.log('🧪 TEST – EDEKA PDF Fetcher\n');

async function main() {
  try {
    // Prüfe, ob Regionen mit PDF-URLs vorhanden sind
    const regionsWithUrls = getRegionsWithPdfUrls();
    
    if (regionsWithUrls.length === 0) {
      console.log('⚠️  Keine Regionen mit PDF-URLs gefunden.');
      console.log('Bitte trage die PDF-URLs in src/constants/edeka_regions.ts ein.\n');
      console.log('So findest du die PDF-URLs:');
      console.log('1. Gehe zu https://www.kaufda.de/Geschaefte/Edeka');
      console.log('2. Wähle eine Region aus');
      console.log('3. Öffne den Prospekt');
      console.log('4. Rechtsklick auf "PDF herunterladen" → Link-Adresse kopieren');
      console.log('5. Füge die URL in edeka_regions.ts ein\n');
      return;
    }
    
    console.log(`📋 ${regionsWithUrls.length} Regionen mit PDF-URLs gefunden\n`);
    
    // Test: Lade die ersten 2 Regionen
    const testRegions = regionsWithUrls.slice(0, 2);
    
    console.log('📥 Teste Download und Extraktion für:');
    testRegions.forEach(r => console.log(`   - ${r.region}`));
    console.log('');
    
    // Test einzelne Regionen
    for (const region of testRegions) {
      console.log(`\n${'='.repeat(50)}`);
      console.log(`🔍 Teste Region: ${region.region}`);
      console.log('='.repeat(50));
      
      const result = await fetchEdekaPdfForRegion(region.region);
      
      if (result && result.success) {
        console.log(`\n✅ Erfolgreich!`);
        console.log(`   📦 Angebote: ${result.offersCount}`);
        console.log(`   📄 PDF: ${result.pdfPath}`);
        console.log(`   📋 JSON: ${result.jsonPath}`);
        
        // Lade JSON und zeige erste 5 Angebote
        if (result.jsonPath) {
          const fs = await import('fs/promises');
          const jsonContent = await fs.readFile(result.jsonPath, 'utf-8');
          const data = JSON.parse(jsonContent);
          
          if (data.offers && data.offers.length > 0) {
            console.log(`\n📋 Erste 5 Angebote:\n`);
            data.offers.slice(0, 5).forEach((offer, i) => {
              console.log(`${i + 1}. ${offer.name}`);
              console.log(`   💰 ${offer.price}€${offer.unit ? ` / ${offer.unit}` : ''}`);
              if (offer.discount) console.log(`   🏷️  Rabatt: -${offer.discount}%`);
              console.log('');
            });
          }
        }
      } else {
        console.log(`\n❌ Fehlgeschlagen: ${result?.error || 'Unbekannter Fehler'}`);
      }
    }
    
    // Optional: Teste alle Regionen
    if (process.argv.includes('--all')) {
      console.log(`\n${'='.repeat(50)}`);
      console.log('🔄 Teste alle Regionen...');
      console.log('='.repeat(50));
      
      const results = await fetchAllEdekaPdfs();
      
      console.log(`\n📊 Gesamt-Ergebnis:`);
      console.log(`   ✅ Erfolgreich: ${results.filter(r => r.success).length}`);
      console.log(`   ❌ Fehlgeschlagen: ${results.filter(r => !r.success).length}`);
      console.log(`   📦 Gesamt-Angebote: ${results.reduce((sum, r) => sum + r.offersCount, 0)}`);
    }
    
  } catch (err) {
    console.error('❌ Fehler:', err);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ Unerwarteter Fehler:', err);
  process.exit(1);
});

