#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');

console.log('\n🔄 KONVERTIERE NETTO REZEPTE FÜR APP\n');
console.log('═'.repeat(60));

// Input lesen
const input = JSON.parse(fs.readFileSync(
  path.join(PROSPEKTE_DIR, 'netto/netto_recipes.json'), 
  'utf-8'
));

console.log(`✅ ${input.totalRecipes} Rezepte geladen`);

// Konvertieren
const appRecipes = input.recipes.map((recipe, idx) => {
  const id = `netto_${recipe.title.toLowerCase().replace(/[^a-z0-9]+/g, '_')}`;
  
  let mealType = 'dinner';
  if (recipe.tags.some(t => t.toLowerCase().includes('frühstück') || t.toLowerCase().includes('breakfast'))) {
    mealType = 'breakfast';
  } else if (recipe.tags.some(t => t.toLowerCase().includes('salat') || t.toLowerCase().includes('leicht'))) {
    mealType = 'lunch';
  }

  const ingredients = recipe.ingredients.map(ing => ({
    name: ing.name,
    quantity: parseFloat(ing.amount) || 1,
    unit: ing.amount.replace(/[0-9.,]/g, '').trim() || 'Stück',
    brand: ing.brand || 'Netto Eigenmarke',
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
    short_description: recipe.description,
    meal_type: mealType,
    tags: recipe.tags.map(t => t.toLowerCase().replace(/\s+/g, '')),
    servings: recipe.servings,
    prep_time_min: recipe.prepTime,
    cook_time_min: recipe.cookTime,
    difficulty: recipe.difficulty,
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
    steps: recipe.instructions
  };
});

// Speichern
const outputPath = path.join(PROSPEKTE_DIR, 'netto/netto_app.json');
fs.writeFileSync(outputPath, JSON.stringify(appRecipes, null, 2), 'utf-8');

console.log(`\n✅ ${appRecipes.length} Rezepte konvertiert`);
console.log(`📁 Gespeichert: netto_app.json\n`);

// Beispiel anzeigen
console.log('📖 BEISPIEL-REZEPT:');
console.log('═'.repeat(60));
const example = appRecipes[0];
console.log(`Titel: ${example.title}`);
console.log(`ID: ${example.id}`);
console.log(`Typ: ${example.meal_type}`);
console.log(`Portionen: ${example.servings}`);
console.log(`Preis: ${example.total_discount_price_eur}€`);
console.log(`Kalorien: ${example.nutrients_per_serving.kcal} kcal/Portion`);
console.log('═'.repeat(60));

