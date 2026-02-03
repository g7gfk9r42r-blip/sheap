#!/usr/bin/env node
// scripts/process_local_prospekte.mjs
// Verarbeitet lokal gespeicherte Prospekt-Dateien (PDF oder HTML)

import { processLocalFile, processDirectory } from '../dist/utils/local_file_processor.js';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Kommandozeilen-Argumente
const args = process.argv.slice(2);
const command = args[0];
const fileOrDir = args[1];
const retailer = args[2] || 'EDEKA';

async function main() {
  console.log('📁 Local Prospekt Processor\n');
  
  if (!command || !fileOrDir) {
    console.log('Verwendung:');
    console.log('  node scripts/process_local_prospekte.mjs file <pfad> [retailer]');
    console.log('  node scripts/process_local_prospekte.mjs dir <verzeichnis> [retailer]');
    console.log('');
    console.log('Beispiele:');
    console.log('  node scripts/process_local_prospekte.mjs file "media/prospekte/edeka/Berlin.pdf" EDEKA');
    console.log('  node scripts/process_local_prospekte.mjs dir "media/prospekte/lidl" LIDL');
    console.log('');
    console.log('💡 Tipp: Speichere Prospekte als "Webseite, vollständig" (mit Assets) oder als PDF!');
    process.exit(1);
  }
  
  const filePath = resolve(__dirname, '..', fileOrDir);
  
  try {
    if (command === 'file') {
      // Einzelne Datei verarbeiten
      const result = await processLocalFile(filePath, retailer);
      
      if (result.success) {
        console.log(`\n✅ Erfolgreich! ${result.offersCount} Angebote extrahiert`);
        console.log(`📄 Typ: ${result.fileType}`);
        if (result.outputPath) {
          console.log(`📋 JSON: ${result.outputPath}`);
        }
      } else {
        console.error(`\n❌ Fehlgeschlagen: ${result.error}`);
        process.exit(1);
      }
      
    } else if (command === 'dir') {
      // Verzeichnis verarbeiten
      const results = await processDirectory(filePath, retailer);
      
      const successful = results.filter(r => r.success);
      const failed = results.filter(r => !r.success);
      const totalOffers = results.reduce((sum, r) => sum + r.offersCount, 0);
      
      console.log(`\n📊 Zusammenfassung:`);
      console.log(`   ✅ Erfolgreich: ${successful.length}/${results.length}`);
      console.log(`   ❌ Fehlgeschlagen: ${failed.length}/${results.length}`);
      console.log(`   📦 Gesamt-Angebote: ${totalOffers}`);
      
      if (failed.length > 0) {
        console.log(`\n   Fehlgeschlagene Dateien:`);
        failed.forEach(r => {
          console.log(`     - ${r.error}`);
        });
      }
      
    } else {
      console.error(`❌ Unbekanntes Kommando: ${command}`);
      console.error('Verwende "file" oder "dir"');
      process.exit(1);
    }
    
  } catch (err) {
    console.error('❌ Fehler:', err);
    process.exit(1);
  }
}

main();

