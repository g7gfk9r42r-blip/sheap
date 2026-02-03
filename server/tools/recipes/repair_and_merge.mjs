#!/usr/bin/env node

/**
 * REPAIR & MERGE
 * 
 * 1. Repariert netto.json (fügt Array-Wrapper hinzu)
 * 2. Konvertiert netto_recipes.json ins App-Format
 * 3. Merged beide zusammen
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');

function repairNettoJson() {
  const filePath = path.join(PROSPEKTE_DIR, 'netto/netto.json');
  
  console.log('🔧 Repariere netto.json...\n');
  
  // Lesen
  let content = fs.readFileSync(filePath, 'utf-8');
  
  // Prüfen ob schon valid
  try {
    const parsed = JSON.parse(content);
    if (Array.isArray(parsed)) {
      console.log('✅ Datei ist bereits valide (Array)');
      return parsed;
    }
  } catch (e) {
    // Nicht valide - reparieren
  }

  // Backup erstellen
  fs.writeFileSync(filePath + '.backup', content, 'utf-8');
  console.log('💾 Backup erstellt: netto.json.backup');

  // Array-Wrapper hinzufügen
  content = '[' + content + ']';
  
  // Parsen
  try {
    const parsed = JSON.parse(content);
    console.log(`✅ Repariert! ${parsed.length} Rezepte gefunden\n`);
    return parsed;
  } catch (error) {
    console.error('❌ Fehler beim Reparieren:', error.message);
    process.exit(1);
  }
}

function convertNewRecipes() {
  const filePath = path.join(PROSPEKTE_DIR, 'netto/netto_recipes.json');
  
  if (!fs.existsSync(filePath)) {
    console.log('⚠️  Keine neuen Rezepte gefunden\n');
    return [];
  }

  console.log('🔄 Konvertiere neue Rezepte...\n');

  const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  
  const converted = data.recipes.map((recipe, idx) => {
    const id = `netto_${recipe.title.toLowerCase().replace(/[^a-z0-9]+/g, '_')}_${idx + 1}`;
    
    let mealType = 'dinner';
    if (recipe.tags.some(t => t.toLowerCase().includes('frühstück'))) {
      mealType = 'breakfast';
    }

    const ingredients = recipe.ingredients.map(ing => ({
      name: ing.name,
      quantity: parseFloat(ing.amount) || 1,
      unit: ing.amount.replace(/[0-9.,]/g, '').trim() || 'Stück',
      brand: ing.brand || 'Eigenmarke',
      original_price_eur: ing.originalPrice || ing.price,
      discount_price_eur: ing.price
    }));

    const totalOriginal = ingredients.reduce((sum, ing) => sum + ing.original_price_eur, 0);
    const totalDiscount = ingredients.reduce((sum, ing) => sum + ing.discount_price_eur, 0);
    const savingPercent = totalOriginal > 0 
      ? ((totalOriginal - totalDiscount) / totalOriginal * 100)
      : 0;

    return {
      id,
      title: recipe.title,
      short_description: recipe.description || recipe.title,
      meal_type: mealType,
      tags: recipe.tags.map(t => t.toLowerCase().replace(/\s+/g, '')),
      servings: recipe.servings,
      total_original_price_eur: parseFloat(totalOriginal.toFixed(2)),
      total_discount_price_eur: parseFloat(totalDiscount.toFixed(2)),
      total_saving_percent: parseFloat(savingPercent.toFixed(1)),
      nutrients_per_serving: {
        kcal: recipe.nutrition.calories,
        protein_g: recipe.nutrition.protein,
        carbs_g: recipe.nutrition.carbs,
        fat_g: recipe.nutrition.fat
      },
      ingredients,
      steps: recipe.instructions || []
    };
  });

  console.log(`✅ ${converted.length} neue Rezepte konvertiert\n`);
  return converted;
}

function mergeAndSave(oldRecipes, newRecipes) {
  console.log('🔀 Merge Rezepte...\n');

  // Alle zusammenführen
  const all = [...oldRecipes, ...newRecipes];

  // Nach ID deduplizieren
  const unique = {};
  for (const recipe of all) {
    unique[recipe.id] = recipe;
  }

  const final = Object.values(unique);

  // Speichern
  const outputPath = path.join(PROSPEKTE_DIR, 'netto/netto.json');
  fs.writeFileSync(outputPath, JSON.stringify(final, null, 2), 'utf-8');

  console.log(`✅ ${final.length} Rezepte gespeichert`);
  console.log(`   Alte: ${oldRecipes.length}`);
  console.log(`   Neue: ${newRecipes.length}`);
  console.log(`   Gesamt: ${final.length}\n`);
  console.log(`📁 Gespeichert: ${outputPath}`);
}

async function main() {
  console.log('\n🔧 NETTO.JSON REPARIEREN & NEUE REZEPTE HINZUFÜGEN\n');
  console.log('═'.repeat(60));
  console.log('');

  // 1. Alte Rezepte reparieren
  const oldRecipes = repairNettoJson();

  // 2. Neue Rezepte konvertieren
  const newRecipes = convertNewRecipes();

  // 3. Mergen & speichern
  mergeAndSave(oldRecipes, newRecipes);

  console.log('\n═'.repeat(60));
  console.log('✅ FERTIG!');
  console.log('═'.repeat(60));
}

main();

