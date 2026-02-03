#!/usr/bin/env node

/**
 * CONVERTER: GPT-Format → App-Format
 * 
 * Konvertiert generierte Rezepte ins Flutter-App-Format
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');

function convertRecipe(recipe, retailer, index) {
  // ID generieren
  const id = `${retailer}_${recipe.title.toLowerCase().replace(/[^a-z0-9]+/g, '_')}_${index}`;
  
  // Meal-Type aus Tags ableiten
  let mealType = 'dinner';
  if (recipe.tags.some(t => t.toLowerCase().includes('frühstück') || t.toLowerCase().includes('breakfast'))) {
    mealType = 'breakfast';
  } else if (recipe.tags.some(t => t.toLowerCase().includes('mittag') || t.toLowerCase().includes('lunch'))) {
    mealType = 'lunch';
  }

  // Ingredients konvertieren
  const ingredients = recipe.ingredients.map(ing => ({
    name: ing.name,
    quantity: parseFloat(ing.amount) || 1,
    unit: ing.amount.replace(/[0-9.,]/g, '').trim() || 'Stück',
    brand: ing.brand || 'Eigenmarke',
    original_price_eur: ing.originalPrice || ing.price,
    discount_price_eur: ing.price
  }));

  // Preise berechnen
  const totalOriginalPrice = ingredients.reduce((sum, ing) => sum + ing.original_price_eur, 0);
  const totalDiscountPrice = ingredients.reduce((sum, ing) => sum + ing.discount_price_eur, 0);
  const savingPercent = totalOriginalPrice > 0 
    ? ((totalOriginalPrice - totalDiscountPrice) / totalOriginalPrice * 100)
    : 0;

  return {
    id,
    title: recipe.title,
    short_description: recipe.description || recipe.title,
    meal_type: mealType,
    tags: recipe.tags.map(t => t.toLowerCase().replace(/\s+/g, '')),
    servings: recipe.servings,
    total_original_price_eur: parseFloat(totalOriginalPrice.toFixed(2)),
    total_discount_price_eur: parseFloat(totalDiscountPrice.toFixed(2)),
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
}

function convertRecipesFile(retailer) {
  const inputPath = path.join(PROSPEKTE_DIR, retailer, `${retailer}_recipes.json`);
  const outputPath = path.join(PROSPEKTE_DIR, retailer, `${retailer}.json`);

  if (!fs.existsSync(inputPath)) {
    console.error(`❌ Datei nicht gefunden: ${inputPath}`);
    return false;
  }

  try {
    // Input lesen
    const input = JSON.parse(fs.readFileSync(inputPath, 'utf-8'));
    
    // Konvertieren
    const converted = input.recipes.map((recipe, idx) => 
      convertRecipe(recipe, retailer, idx + 1)
    );

    // Als Array speichern (App-Format)
    fs.writeFileSync(outputPath, JSON.stringify(converted, null, 2), 'utf-8');

    console.log(`✅ ${retailer}: ${converted.length} Rezepte konvertiert`);
    console.log(`   Gespeichert: ${outputPath}`);
    
    return true;
  } catch (error) {
    console.error(`❌ Fehler bei ${retailer}:`, error.message);
    return false;
  }
}

async function main() {
  console.log('\n🔄 REZEPTE KONVERTIEREN (GPT → App-Format)\n');
  console.log('═'.repeat(60));

  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log('USAGE:');
    console.log('  node convert_to_app_format.mjs <retailer>');
    console.log('  node convert_to_app_format.mjs all');
    console.log('');
    console.log('BEISPIELE:');
    console.log('  node convert_to_app_format.mjs netto');
    console.log('  node convert_to_app_format.mjs all');
    process.exit(1);
  }

  const target = args[0].toLowerCase();

  if (target === 'all') {
    // Alle Supermärkte
    const retailers = fs.readdirSync(PROSPEKTE_DIR)
      .filter(name => {
        const dirPath = path.join(PROSPEKTE_DIR, name);
        return fs.statSync(dirPath).isDirectory();
      });

    let success = 0;
    for (const retailer of retailers) {
      if (convertRecipesFile(retailer)) {
        success++;
      }
    }

    console.log('\n═'.repeat(60));
    console.log(`✅ ${success}/${retailers.length} Supermärkte konvertiert`);
  } else {
    // Einzelner Supermarkt
    if (convertRecipesFile(target)) {
      console.log('\n═'.repeat(60));
      console.log('✅ ERFOLGREICH KONVERTIERT!');
    } else {
      process.exit(1);
    }
  }
}

main();

