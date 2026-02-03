#!/usr/bin/env node
// scripts/parse_kaufda_html.mjs
// Parse KaufDA HTML-Datei und extrahiere PDF-Links oder Angebote

import { parseKaufdaHtml } from '../dist/utils/kaufda_html_parser.js';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const HTML_PATH = resolve(__dirname, '../media/prospekte/edeka/kaufDA - EDEKA - Aktuelle Angebote.html');

async function main() {
  console.log('🔍 Parse KaufDA HTML-Datei\n');
  console.log(`📄 Datei: ${HTML_PATH}\n`);
  
  try {
    const { pdfLinks, offers } = await parseKaufdaHtml(HTML_PATH);
    
    console.log('\n' + '='.repeat(50));
    console.log('📋 PDF-Links gefunden:');
    console.log('='.repeat(50));
    
    if (pdfLinks.length === 0) {
      console.log('⚠️  Keine PDF-Links gefunden');
    } else {
      pdfLinks.forEach((link, i) => {
        console.log(`\n${i + 1}. ${link.url}`);
        if (link.title) console.log(`   Titel: ${link.title}`);
        if (link.validFrom && link.validTo) {
          console.log(`   Gültig: ${link.validFrom} - ${link.validTo}`);
        }
      });
    }
    
    console.log('\n' + '='.repeat(50));
    console.log('🛒 Angebote gefunden:');
    console.log('='.repeat(50));
    
    if (offers.length === 0) {
      console.log('⚠️  Keine Angebote gefunden');
    } else {
      console.log(`\n📦 ${offers.length} Angebote:\n`);
      offers.slice(0, 10).forEach((offer, i) => {
        console.log(`${i + 1}. ${offer.name}`);
        console.log(`   💰 ${offer.price}€${offer.unit ? ` / ${offer.unit}` : ''}`);
        if (offer.discount) console.log(`   🏷️  Rabatt: -${offer.discount}%`);
        if (offer.imageUrl) console.log(`   🖼️  Bild: ${offer.imageUrl.substring(0, 60)}...`);
        console.log('');
      });
      
      if (offers.length > 10) {
        console.log(`... und ${offers.length - 10} weitere Angebote`);
      }
    }
    
    // Speichere PDF-Links für edeka_regions.ts
    if (pdfLinks.length > 0) {
      console.log('\n' + '='.repeat(50));
      console.log('💡 Tipp: Kopiere diese URLs in src/constants/edeka_regions.ts');
      console.log('='.repeat(50));
      pdfLinks.forEach((link, i) => {
        console.log(`\n// Region ${i + 1}:`);
        console.log(`pdfUrl: '${link.url}',`);
      });
    }
    
  } catch (err) {
    console.error('❌ Fehler:', err);
    process.exit(1);
  }
}

main();

