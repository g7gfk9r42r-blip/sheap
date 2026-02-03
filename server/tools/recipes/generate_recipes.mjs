#!/usr/bin/env node

/**
 * RECIPE GENERATOR
 * 
 * Generiert Rezepte aus Supermarkt-Angeboten mit GPT-4
 * 
 * SICHERHEIT:
 * - Nur echte Produkte aus JSON
 * - Preis-Validierung
 * - Kalorien-Plausibilität
 * - Schema-Validierung
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import OpenAI from 'openai';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PROSPEKTE_DIR = path.join(__dirname, '../../media/prospekte');
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

// ============================================================
// KONFIGURATION
// ============================================================

const CONFIG = {
  recipesPerSupermarket: 50,  // Anzahl Rezepte pro Supermarkt
  maxRetries: 3,              // Max. Versuche bei GPT-Fehlern
  minIngredients: 3,          // Min. Zutaten pro Rezept
  maxIngredients: 10,         // Max. Zutaten pro Rezept
  minCalories: 200,           // Min. Kalorien pro Portion (Plausibilität)
  maxCalories: 1500,          // Max. Kalorien pro Portion (Plausibilität)
};

// ============================================================
// HELPER FUNCTIONS
// ============================================================

/**
 * Lädt Angebote aus JSON-Datei
 */
function loadOffers(supermarket) {
  const jsonPath = path.join(PROSPEKTE_DIR, supermarket, `${supermarket}.json`);
  
  if (!fs.existsSync(jsonPath)) {
    console.error(`❌ Keine JSON gefunden: ${jsonPath}`);
    return null;
  }

  try {
    const data = JSON.parse(fs.readFileSync(jsonPath, 'utf-8'));
    console.log(`✅ ${supermarket}: ${data.offers?.length || 0} Angebote geladen`);
    return data.offers || [];
  } catch (error) {
    console.error(`❌ Fehler beim Laden von ${jsonPath}:`, error.message);
    return null;
  }
}

/**
 * Filtert nur Lebensmittel (keine Haushaltswaren, Technik, etc.)
 */
function filterFoodItems(offers) {
  const foodKeywords = [
    'fleisch', 'wurst', 'käse', 'milch', 'joghurt', 'butter',
    'gemüse', 'obst', 'salat', 'kartoffel', 'tomate', 'gurke',
    'brot', 'brötchen', 'pasta', 'nudel', 'reis', 'mehl',
    'ei', 'eier', 'fisch', 'lachs', 'hähnchen', 'rind', 'schwein',
    'sahne', 'quark', 'öl', 'essig', 'gewürz', 'zucker', 'salz',
    'schokolade', 'keks', 'kuchen', 'pizza', 'sauce', 'ketchup',
    'marmelade', 'honig', 'müsli', 'cornflakes', 'saft', 'wasser'
  ];

  const nonFoodKeywords = [
    'toilettenpapier', 'küchentücher', 'servietten', 'windel',
    'shampoo', 'duschgel', 'zahnpasta', 'waschmittel', 'spülmittel',
    'kerze', 'deko', 'geschenk', 'spielzeug', 'kleidung', 'socken',
    'pfanne', 'topf', 'messer', 'grill', 'werkzeug', 'strom'
  ];

  return offers.filter(offer => {
    const title = offer.title?.toLowerCase() || '';
    const description = offer.description?.toLowerCase() || '';
    const combined = `${title} ${description}`;

    // Muss mindestens ein Food-Keyword enthalten
    const hasFood = foodKeywords.some(kw => combined.includes(kw));
    
    // Darf kein Non-Food-Keyword enthalten
    const hasNonFood = nonFoodKeywords.some(kw => combined.includes(kw));

    return hasFood && !hasNonFood;
  });
}

/**
 * Bereitet Angebote für GPT vor (vereinfachtes Format)
 */
function prepareOffersForGPT(offers) {
  return offers.map((offer, idx) => ({
    id: idx + 1,
    name: offer.title,
    brand: offer.brand || 'Eigenmarke',
    price: offer.price,
    originalPrice: offer.originalPrice,
    discount: offer.discount,
    unit: offer.unit || 'Stück',
    category: offer.category || 'Lebensmittel',
    description: offer.description || ''
  }));
}

/**
 * Generiert Rezepte mit GPT-4
 */
async function generateRecipes(supermarket, offers) {
  console.log(`\n🤖 Generiere Rezepte für ${supermarket}...`);

  const preparedOffers = prepareOffersForGPT(offers);
  
  const systemPrompt = `Du bist ein professioneller Koch und Ernährungsberater.

AUFGABE:
Erstelle ${CONFIG.recipesPerSupermarket} kreative, alltagstaugliche Rezepte aus den verfügbaren Supermarkt-Angeboten.

STRIKTE REGELN:
1. ✅ NUR Produkte aus der bereitgestellten Liste verwenden
2. ✅ EXAKTE Produktnamen, Marken und Preise verwenden
3. ✅ Realistische Kalorien-Angaben (200-1500 kcal/Portion)
4. ✅ ${CONFIG.minIngredients}-${CONFIG.maxIngredients} Zutaten pro Rezept
5. ✅ Rezepte für 2-4 Portionen
6. ✅ Prep- & Kochzeit in Minuten
7. ✅ Schritt-für-Schritt Anleitung
8. ❌ KEINE erfundenen Zutaten
9. ❌ KEINE erfundenen Preise
10. ❌ KEINE unrealistischen Kalorien

KALORIEN-RICHTWERTE (pro 100g):
- Gemüse: 20-50 kcal
- Obst: 40-80 kcal
- Fleisch: 150-250 kcal
- Käse: 250-400 kcal
- Brot: 220-280 kcal
- Nudeln (gekocht): 130-160 kcal

JSON-FORMAT (PFLICHT):
{
  "recipes": [
    {
      "id": "string (z.B. 'aldi_nord_001')",
      "title": "string (appetitlich, kreativ)",
      "description": "string (kurz, ansprechend)",
      "servings": number (2-4),
      "prepTime": number (Minuten),
      "cookTime": number (Minuten),
      "difficulty": "easy|medium|hard",
      "ingredients": [
        {
          "productId": number (ID aus Liste),
          "name": "string (exakt wie in Liste)",
          "brand": "string (exakt wie in Liste)",
          "amount": "string (z.B. '200 g', '2 Stück')",
          "price": number (exakt wie in Liste),
          "originalPrice": number|null,
          "retailer": "string (Supermarkt-Name)"
        }
      ],
      "totalPrice": number (Summe aller Zutaten),
      "totalSavings": number (Summe aller Ersparnisse),
      "nutrition": {
        "calories": number (pro Portion, realistisch!),
        "protein": number (g pro Portion),
        "carbs": number (g pro Portion),
        "fat": number (g pro Portion)
      },
      "instructions": [
        "string (Schritt 1)",
        "string (Schritt 2)",
        "..."
      ],
      "tags": ["string", ...] (z.B. "schnell", "vegetarisch", "low-carb")
    }
  ]
}`;

  const userPrompt = `Erstelle ${CONFIG.recipesPerSupermarket} Rezepte aus diesen Angeboten von ${supermarket}:

${JSON.stringify(preparedOffers, null, 2)}

WICHTIG: Antworte NUR mit validem JSON (siehe Format oben). Keine Erklärungen, kein Markdown!`;

  try {
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

    console.log(`✅ ${data.recipes?.length || 0} Rezepte generiert`);
    return data.recipes || [];

  } catch (error) {
    console.error(`❌ GPT-Fehler:`, error.message);
    return [];
  }
}

/**
 * Validiert Rezepte (Sicherheits-Check)
 */
function validateRecipes(recipes, offers, supermarket) {
  console.log(`\n🔒 Validiere Rezepte für ${supermarket}...`);

  const validRecipes = [];
  const errors = [];

  for (const recipe of recipes) {
    const issues = [];

    // 1. Zutaten-Anzahl prüfen
    if (recipe.ingredients.length < CONFIG.minIngredients) {
      issues.push(`Zu wenige Zutaten (${recipe.ingredients.length})`);
    }
    if (recipe.ingredients.length > CONFIG.maxIngredients) {
      issues.push(`Zu viele Zutaten (${recipe.ingredients.length})`);
    }

    // 2. Kalorien-Plausibilität
    if (recipe.nutrition.calories < CONFIG.minCalories || recipe.nutrition.calories > CONFIG.maxCalories) {
      issues.push(`Unplausible Kalorien (${recipe.nutrition.calories})`);
    }

    // 3. Alle Zutaten in Angebots-Liste?
    for (const ing of recipe.ingredients) {
      const offer = offers.find(o => o.title === ing.name);
      if (!offer) {
        issues.push(`Zutat nicht gefunden: ${ing.name}`);
      }
    }

    // 4. Preis plausibel?
    const calculatedPrice = recipe.ingredients.reduce((sum, ing) => sum + ing.price, 0);
    if (Math.abs(calculatedPrice - recipe.totalPrice) > 0.5) {
      issues.push(`Preis-Diskrepanz: ${recipe.totalPrice} vs ${calculatedPrice.toFixed(2)}`);
    }

    if (issues.length === 0) {
      validRecipes.push(recipe);
    } else {
      errors.push({ recipe: recipe.title, issues });
    }
  }

  console.log(`✅ ${validRecipes.length}/${recipes.length} Rezepte valide`);
  
  if (errors.length > 0) {
    console.log(`⚠️  ${errors.length} Rezepte mit Problemen:`);
    errors.forEach(err => {
      console.log(`   - ${err.recipe}: ${err.issues.join(', ')}`);
    });
  }

  return validRecipes;
}

/**
 * Speichert Rezepte in JSON-Datei
 */
function saveRecipes(supermarket, recipes) {
  const outputPath = path.join(PROSPEKTE_DIR, supermarket, `${supermarket}_recipes.json`);
  
  const data = {
    supermarket,
    generatedAt: new Date().toISOString(),
    totalRecipes: recipes.length,
    recipes
  };

  fs.writeFileSync(outputPath, JSON.stringify(data, null, 2), 'utf-8');
  console.log(`✅ Rezepte gespeichert: ${outputPath}`);
}

// ============================================================
// MAIN FUNCTION
// ============================================================

async function main() {
  console.log('🍳 RECIPE GENERATOR GESTARTET\n');
  console.log('═'.repeat(60));

  // API-Key prüfen
  if (!process.env.OPENAI_API_KEY) {
    console.error('❌ OPENAI_API_KEY nicht gesetzt!');
    console.log('   Erstelle .env Datei mit: OPENAI_API_KEY=sk-...');
    process.exit(1);
  }

  // Alle Supermärkte durchgehen
  const supermarkets = fs.readdirSync(PROSPEKTE_DIR)
    .filter(name => {
      const dirPath = path.join(PROSPEKTE_DIR, name);
      return fs.statSync(dirPath).isDirectory();
    });

  console.log(`📁 Gefundene Supermärkte: ${supermarkets.join(', ')}\n`);

  for (const supermarket of supermarkets) {
    console.log('═'.repeat(60));
    console.log(`🏪 VERARBEITE: ${supermarket.toUpperCase()}`);
    console.log('═'.repeat(60));

    // 1. Angebote laden
    const allOffers = loadOffers(supermarket);
    if (!allOffers || allOffers.length === 0) {
      console.log(`⏭️  Überspringe ${supermarket} (keine Angebote)\n`);
      continue;
    }

    // 2. Nur Lebensmittel filtern
    const foodOffers = filterFoodItems(allOffers);
    console.log(`🥗 ${foodOffers.length}/${allOffers.length} Lebensmittel gefiltert`);

    if (foodOffers.length < 10) {
      console.log(`⏭️  Zu wenige Lebensmittel für Rezepte\n`);
      continue;
    }

    // 3. Rezepte generieren
    const recipes = await generateRecipes(supermarket, foodOffers);

    if (recipes.length === 0) {
      console.log(`❌ Keine Rezepte generiert\n`);
      continue;
    }

    // 4. Validieren
    const validRecipes = validateRecipes(recipes, foodOffers, supermarket);

    // 5. Speichern
    if (validRecipes.length > 0) {
      saveRecipes(supermarket, validRecipes);
    }

    console.log(''); // Leerzeile
  }

  console.log('═'.repeat(60));
  console.log('✅ FERTIG!');
  console.log('═'.repeat(60));
}

main().catch(error => {
  console.error('❌ FEHLER:', error);
  process.exit(1);
});

