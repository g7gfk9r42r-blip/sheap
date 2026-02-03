#!/usr/bin/env node

/**
 * TEST SCRIPT - Generiert Rezepte für EINEN Supermarkt
 * Zum Testen ohne lange Wartezeit
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config({ path: '../../.env' });

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// ============================================================
// TEST CONFIG - Nur 5 Rezepte für schnellen Test
// ============================================================

const CONFIG = {
  recipesPerSupermarket: 5,  // Nur 5 Rezepte für Test
  minIngredients: 3,
  maxIngredients: 8,
  minCalories: 200,
  maxCalories: 1500,
};

// Welcher Supermarkt soll getestet werden?
const TEST_SUPERMARKET = process.argv[2] || 'netto';

// ============================================================
// FUNCTIONS (gekürzt)
// ============================================================

function loadOffers(supermarket) {
  const jsonPath = path.join(PROSPEKTE_DIR, supermarket, `${supermarket}.json`);
  
  if (!fs.existsSync(jsonPath)) {
    console.error(`❌ Keine JSON gefunden: ${jsonPath}`);
    return null;
  }

  try {
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
    console.log(`✅ ${data.offers?.length || 0} Angebote geladen`);
    return data.offers || [];
  } catch (error) {
    console.error(`❌ Fehler:`, error.message);
    return null;
  }
}

function filterFoodItems(offers) {
  const foodKeywords = [
    'fleisch', 'wurst', 'käse', 'milch', 'joghurt', 'butter',
    'gemüse', 'obst', 'salat', 'kartoffel', 'tomate', 'gurke',
    'brot', 'brötchen', 'pasta', 'nudel', 'reis', 'mehl',
    'ei', 'eier', 'fisch', 'lachs', 'hähnchen', 'rind', 'schwein',
    'sahne', 'quark', 'öl', 'essig', 'gewürz', 'zucker', 'salz'
  ];

  return offers.filter(offer => {
    const title = offer.title?.toLowerCase() || '';
    return foodKeywords.some(kw => title.includes(kw));
  }).slice(0, 30); // Nur erste 30 für Test
}

function prepareOffersForGPT(offers) {
  return offers.map((offer, idx) => ({
    id: idx + 1,
    name: offer.title,
    brand: offer.brand || 'Eigenmarke',
    price: parseFloat(offer.price) || 0,
    originalPrice: parseFloat(offer.originalPrice) || null,
    unit: offer.unit || 'Stück',
    category: offer.category || 'Lebensmittel'
  }));
}

async function generateRecipes(supermarket, offers) {
  console.log(`\n🤖 Generiere ${CONFIG.recipesPerSupermarket} Test-Rezepte...`);

  const preparedOffers = prepareOffersForGPT(offers);
  
  console.log(`\n📦 Verfügbare Produkte (Auswahl):`);
  preparedOffers.slice(0, 10).forEach(o => {
    console.log(`   ${o.id}. ${o.name} - ${o.price}€`);
  });
  console.log(`   ... und ${preparedOffers.length - 10} weitere\n`);

  const systemPrompt = `Du bist ein professioneller Koch.

Erstelle ${CONFIG.recipesPerSupermarket} einfache, alltagstaugliche Rezepte aus den verfügbaren Produkten.

REGELN:
- NUR Produkte aus der Liste verwenden
- Exakte Produktnamen und Preise
- Realistische Kalorien (200-1500 kcal/Portion)
- ${CONFIG.minIngredients}-${CONFIG.maxIngredients} Zutaten pro Rezept
- Rezepte für 2-4 Portionen

KALORIEN-RICHTWERTE (pro 100g):
- Gemüse: 20-50 kcal
- Obst: 40-80 kcal
- Fleisch: 150-250 kcal
- Käse: 250-400 kcal

JSON-FORMAT (strikt einhalten!):
{
  "recipes": [
    {
      "id": "string",
      "title": "string",
      "description": "string",
      "servings": number,
      "prepTime": number,
      "cookTime": number,
      "difficulty": "easy|medium|hard",
      "ingredients": [
        {
          "productId": number,
          "name": "string",
          "brand": "string",
          "amount": "string",
          "price": number,
          "retailer": "${supermarket}"
        }
      ],
      "totalPrice": number,
      "totalSavings": number,
      "nutrition": {
        "calories": number,
        "protein": number,
        "carbs": number,
        "fat": number
      },
      "instructions": ["string", "string", ...],
      "tags": ["string", ...]
    }
  ]
}`;

  const userPrompt = `Erstelle ${CONFIG.recipesPerSupermarket} Rezepte aus diesen ${supermarket}-Produkten:

${JSON.stringify(preparedOffers, null, 2)}

Antworte NUR mit validem JSON!`;

  try {
    console.log('⏳ Warte auf GPT-4...\n');

    const completion = await openai.chat.completions.create({
      model: 'gpt-4-turbo-preview',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.7,
      response_format: { type: 'json_object' }
    });

    const response = completion.choices[0].message.content;
    const data = JSON.parse(response);

    console.log(`✅ ${data.recipes?.length || 0} Rezepte generiert\n`);
    
    // Zeige erstes Rezept als Beispiel
    if (data.recipes && data.recipes.length > 0) {
      const recipe = data.recipes[0];
      console.log('📖 BEISPIEL-REZEPT:');
      console.log('═'.repeat(60));
      console.log(`Titel: ${recipe.title}`);
      console.log(`Portionen: ${recipe.servings} | Zeit: ${recipe.prepTime + recipe.cookTime} Min`);
      console.log(`Kalorien: ${recipe.nutrition.calories} kcal/Portion`);
      console.log(`Preis: ${recipe.totalPrice.toFixed(2)}€`);
      console.log(`\nZutaten:`);
      recipe.ingredients.forEach(ing => {
        console.log(`  • ${ing.amount} ${ing.name} (${ing.price.toFixed(2)}€)`);
      });
      console.log('═'.repeat(60));
    }

    return data.recipes || [];

  } catch (error) {
    console.error(`❌ GPT-Fehler:`, error.message);
    return [];
  }
}

function saveRecipes(supermarket, recipes) {
  const outputPath = path.join(PROSPEKTE_DIR, supermarket, `${supermarket}_recipes.json`);
  
  const data = {
    supermarket,
    generatedAt: new Date().toISOString(),
    totalRecipes: recipes.length,
    recipes
  };

  fs.writeFileSync(outputPath, JSON.stringify(data, null, 2), 'utf-8');
  console.log(`\n✅ Gespeichert: ${outputPath}`);
}

// ============================================================
// MAIN
// ============================================================

async function main() {
  console.log('\n🧪 RECIPE GENERATOR - TEST MODE');
  console.log('═'.repeat(60));
  console.log(`Supermarkt: ${TEST_SUPERMARKET}`);
  console.log(`Rezepte: ${CONFIG.recipesPerSupermarket}`);
  console.log('═'.repeat(60));

  // API-Key prüfen
  if (!process.env.OPENAI_API_KEY) {
    console.error('\n❌ OPENAI_API_KEY nicht gesetzt!');
    console.log('   Prüfe: /server/.env');
    process.exit(1);
  }

  // 1. Angebote laden
  const allOffers = loadOffers(TEST_SUPERMARKET);
  if (!allOffers || allOffers.length === 0) {
    console.error(`\n❌ Keine Angebote gefunden für: ${TEST_SUPERMARKET}`);
    process.exit(1);
  }

  // 2. Lebensmittel filtern
  const foodOffers = filterFoodItems(allOffers);
  console.log(`🥗 ${foodOffers.length} Lebensmittel gefiltert`);

  if (foodOffers.length < 5) {
    console.error(`\n❌ Zu wenige Lebensmittel (${foodOffers.length})`);
    process.exit(1);
  }

  // 3. Rezepte generieren
  const recipes = await generateRecipes(TEST_SUPERMARKET, foodOffers);

  if (recipes.length === 0) {
    console.error('\n❌ Keine Rezepte generiert');
    process.exit(1);
  }

  // 4. Speichern
  saveRecipes(TEST_SUPERMARKET, recipes);

  console.log('\n═'.repeat(60));
  console.log('✅ TEST ERFOLGREICH!');
  console.log('═'.repeat(60));
  console.log(`\nNächster Schritt:`);
  console.log(`  node generate_recipes.mjs    # Alle Supermärkte`);
}

main().catch(error => {
  console.error('\n❌ FEHLER:', error);
  process.exit(1);
});

