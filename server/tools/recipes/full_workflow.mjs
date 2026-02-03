#!/usr/bin/env node

/**
 * FULL WORKFLOW
 * 
 * Macht ALLES in einem Schritt:
 * 1. Parse Rohdaten → JSON
 * 2. Generiere Rezepte → recipes.json
 * 
 * USAGE:
 *   node full_workflow.mjs netto prospekt.txt
 */

import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  console.log('\n🚀 FULL WORKFLOW: PARSE + REZEPTE');
  console.log('═'.repeat(60));

  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log('USAGE:');
    console.log('  node full_workflow.mjs <retailer> <prospekt_file>');
    console.log('');
    console.log('BEISPIEL:');
    console.log('  node full_workflow.mjs netto netto_prospekt.txt');
    console.log('');
    console.log('SCHRITTE:');
    console.log('  1. Parse Prospekt → netto.json');
    console.log('  2. Generiere Rezepte → netto_recipes.json');
    process.exit(1);
  }

  const retailer = args[0];
  const prospektFile = args[1];

  // SCHRITT 1: Parse Prospekt
  console.log('\n📄 SCHRITT 1/2: PARSE PROSPEKT');
  console.log('═'.repeat(60));
  
  try {
    execSync(`node ${__dirname}/parse_prospekt.mjs ${retailer} ${prospektFile}`, {
      stdio: 'inherit',
      cwd: __dirname
    });
  } catch (error) {
    console.error('\n❌ Parsing fehlgeschlagen!');
    process.exit(1);
  }

  // SCHRITT 2: Generiere Rezepte
  console.log('\n\n🍳 SCHRITT 2/2: GENERIERE REZEPTE');
  console.log('═'.repeat(60));
  
  try {
    execSync(`node ${__dirname}/test_single.mjs ${retailer}`, {
      stdio: 'inherit',
      cwd: __dirname
    });
  } catch (error) {
    console.error('\n❌ Rezept-Generierung fehlgeschlagen!');
    process.exit(1);
  }

  console.log('\n\n═'.repeat(60));
  console.log('✅ ✅ ✅  KOMPLETT FERTIG!  ✅ ✅ ✅');
  console.log('═'.repeat(60));
  console.log('\n📁 Erstellt:');
  console.log(`   1. server/media/prospekte/${retailer}/${retailer}.json`);
  console.log(`   2. server/media/prospekte/${retailer}/${retailer}_recipes.json`);
  console.log('\n🎯 Jetzt in Flutter App importieren!');
}

main();

