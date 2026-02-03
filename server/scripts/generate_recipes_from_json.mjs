#!/usr/bin/env node
// Generiert Rezepte aus Kaufland, Aldi Nord und Aldi Süd JSON-Dateien
// Die ersten Rezepte zu 100% aus Angeboten, dann 75%

import fs from 'fs/promises';
import { fileURLToPath } from 'url';
import { dirname, join, resolve } from 'path';

// Fetch ist in Node.js 18+ global verfügbar

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Lade .env Datei
const envPath = resolve(__dirname, '../.env');
try {
  const envContent = await fs.readFile(envPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=').trim();
      if (key && value) {
        process.env[key.trim()] = value.replace(/^["']|["']$/g, '');
      }
    }
  }
} catch (error) {
  // .env nicht gefunden, verwende nur process.env
}

// Lade OpenAI API Key
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

if (!OPENAI_API_KEY) {
  console.error('❌ OPENAI_API_KEY nicht gesetzt!');
  process.exit(1);
}

/**
 * Liest Angebote aus JSON-Dateien und normalisiert sie in ein einheitliches Format
 */
async function loadOffersFromJson(filePath, retailer) {
  try {
    const content = await fs.readFile(filePath, 'utf-8');
    
    if (!content || content.trim().length === 0) {
      console.warn(`⚠️  ${filePath} ist leer`);
      return [];
    }
    
    const data = JSON.parse(content);
    
    const offers = [];
    
    if (retailer === 'Kaufland') {
      // Kaufland Format: { offers: [...] }
      if (data.offers && Array.isArray(data.offers)) {
        for (const offer of data.offers) {
          const name = offer.product || offer.name || '';
          if (name) {
            offers.push({
              supermarket: retailer,
              brand: offer.brand || null,
              product_name: name.trim(),
              description: offer.description || '',
              category: offer.category || '',
              packaging: offer.packaging || offer.unit || '',
              price_current: offer.price || 0,
              price_type: offer.promotion_type || offer.highlight || 'normal',
              unit: offer.base_unit || offer.unit || '',
              unit_price: offer.base_price || offer.price || 0,
              valid_from: offer.valid_from || null,
              valid_to: offer.valid_to || null,
              promotion_note: offer.highlight || offer.promotion_type || null,
            });
          }
        }
      }
    } else if (retailer === 'ALDI Nord') {
      // ALDI Nord Format: { products: [...] }
      if (data.products && Array.isArray(data.products)) {
        for (const product of data.products) {
          const name = product.name || '';
          if (name) {
            offers.push({
              supermarket: retailer,
              brand: product.brand || null,
              product_name: name.trim(),
              description: product.description || '',
              category: product.category || '',
              packaging: product.packaging || product.unit || '',
              price_current: product.price || 0,
              price_type: product.is_qad ? 'weekend_deal' : product.is_xxl ? 'multi_buy' : 'normal',
              unit: product.unit || '',
              unit_price: product.price_per_kg || product.price || 0,
              valid_from: data.valid_from || null,
              valid_to: data.valid_to || null,
              promotion_note: product.is_qad ? 'GÜNSTIGES WOCHENENDE' : product.is_xxl ? 'XXL' : null,
            });
          }
        }
      }
    } else if (retailer === 'ALDI Süd') {
      // ALDI Süd Format: { offers: [...] }
      if (data.offers && Array.isArray(data.offers)) {
        for (const offer of data.offers) {
          const name = offer.name || '';
          if (name) {
            offers.push({
              supermarket: retailer,
              brand: offer.brand || null,
              product_name: name.trim(),
              description: offer.description || '',
              category: offer.category || '',
              packaging: offer.packaging || offer.unit || '',
              price_current: offer.price || 0,
              price_type: offer.is_promotion ? 'promotion' : 'normal',
              unit: offer.unit_price_unit || '',
              unit_price: offer.unit_price || offer.price || 0,
              valid_from: data.valid_from || null,
              valid_to: data.valid_to || null,
              promotion_note: offer.is_promotion ? 'VORTEILS-PREIS' : null,
            });
          }
        }
      }
    }
    
    return offers;
  } catch (error) {
    console.error(`❌ Fehler beim Laden von ${filePath}:`, error.message);
    return [];
  }
}

/**
 * Erstellt einen eindeutigen Schlüssel für ein Angebot.
 * 
 * Wir deduplizieren nur exakt identische Angebote.
 * Gleicher Supermarkt, Produktname, Marke, Packung, Zeitraum und Preis.
 * Hintergrund: Aus dem Prospekt kommen häufig leicht unterschiedliche Varianten
 * (z. B. andere Gültigkeit, andere Packungsgröße oder anderer Promo-Preis),
 * die wir bewusst NICHT zusammenlegen wollen.
 */
function buildOfferKey(offer) {
  return [
    offer.supermarket ?? '',
    offer.brand ?? '',
    offer.product_name ?? '',
    offer.packaging ?? '',
    offer.valid_from ?? '',
    offer.valid_to ?? '',
    String(offer.price_current ?? ''),
    offer.price_type ?? '',
    offer.unit ?? '',
    String(offer.unit_price ?? ''),
  ].join('||');
}

/**
 * Dedupliziert Angebote basierend auf exakten Übereinstimmungen.
 * 
 * @param {Array} offers - Array von Angeboten
 * @param {string} supermarketName - Name des Supermarkts für Logging
 * @returns {Array} Deduplizierte Angebote
 */
function dedupeOffers(offers, supermarketName) {
  const map = new Map();
  const duplicates = [];

  for (const offer of offers) {
    const key = buildOfferKey(offer);
    if (map.has(key)) {
      duplicates.push({ existing: map.get(key), duplicate: offer });
    } else {
      map.set(key, offer);
    }
  }

  console.log(`🔍 [${supermarketName}] Eingelesene Angebote: ${offers.length}`);
  console.log(`🔍 [${supermarketName}] Eindeutige Angebote: ${map.size}`);
  console.log(`🔍 [${supermarketName}] Duplikate: ${duplicates.length}`);

  if (duplicates.length > 0) {
    console.log(
      `🔁 [${supermarketName}] Beispiel-Duplikate (max. 5):`
    );
    duplicates.slice(0, 5).forEach((d, idx) => {
      const dup = d.duplicate;
      console.log(`   ${idx + 1}. ${dup.product_name} (${dup.brand || 'keine Marke'})`);
      console.log(`      Packung: ${dup.packaging}, Preis: €${dup.price_current}`);
      console.log(`      Gültig: ${dup.valid_from || '?'} - ${dup.valid_to || '?'}`);
      console.log(`      Typ: ${dup.price_type}, Promo: ${dup.promotion_note || 'keine'}`);
    });
  }

  return Array.from(map.values());
}

/**
 * Filtert Angebote auf einen Zielzeitraum.
 * 
 * Hintergrund: Prospekte haben Gültigkeitszeiträume (z. B. 03.12.–09.12.25).
 * Wir wollen nur Angebote in der Rezeptlogik berücksichtigen, die in der Zielwoche gültig sind.
 * 
 * @param {Array} offers - Array von Angeboten
 * @param {Date} targetStart - Startdatum des Zielzeitraums
 * @param {Date} targetEnd - Enddatum des Zielzeitraums
 * @returns {Array} Gefilterte Angebote
 */
function filterOffersByDateRange(offers, targetStart, targetEnd) {
  return offers.filter(offer => {
    // Wenn keine Gültigkeitsdaten vorhanden, behalten wir das Angebot
    if (!offer.valid_from && !offer.valid_to) {
      return true;
    }
    
    const offerStart = offer.valid_from ? new Date(offer.valid_from) : null;
    const offerEnd = offer.valid_to ? new Date(offer.valid_to) : null;
    
    // Angebot ist gültig, wenn es den Zielzeitraum überschneidet
    // offer.valid_from <= targetEnd && offer.valid_to >= targetStart
    if (offerStart && offerStart > targetEnd) {
      return false; // Angebot beginnt nach Zielzeitraum
    }
    if (offerEnd && offerEnd < targetStart) {
      return false; // Angebot endet vor Zielzeitraum
    }
    
    return true;
  });
}

/**
 * Normalisiert Zutatenname für Matching
 */
function normalizeIngredient(name) {
  return name.toLowerCase()
    .replace(/[^\w\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Prüft ob Zutat in Angeboten vorhanden ist
 */
function isIngredientInOffers(ingredient, offers) {
  const normalized = normalizeIngredient(ingredient);
  const offerNames = offers.map(o => normalizeIngredient(o.product_name || o.name || ''));
  
  // Direktes Match
  if (offerNames.some(name => name === normalized)) {
    return true;
  }
  
  // Teil-Match (z.B. "Tomaten" in "Tomaten, Cherry")
  if (offerNames.some(name => name.includes(normalized) || normalized.includes(name))) {
    return true;
  }
  
  // Kategorie-Match (z.B. "Käse" in "Franz. Butterkäse")
  const categories = offers.map(o => normalizeIngredient(o.category || ''));
  if (categories.some(cat => cat && (cat.includes(normalized) || normalized.includes(cat)))) {
    return true;
  }
  
  return false;
}

/**
 * Generiert Rezepte mit GPT
 */
async function generateRecipesWithGPT(offers, retailer, count, strictMode = true) {
  const offerList = offers
    .slice(0, 200) // Limit für Token
    .map(o => {
      const name = o.product_name || o.name || '';
      const category = o.category || '';
      const price = o.price_current || o.price || 0;
      return `- ${name} (${category}) - €${price.toFixed(2)}`;
    })
    .join('\n');
  
  const requirement = strictMode 
    ? 'JEDE Zutat MUSS aus der Liste stammen. Verwende NUR Zutaten, die in der Liste sind.'
    : 'Mindestens 75% der Zutaten MÜSSEN aus der Liste stammen. Du kannst auch Standard-Zutaten wie Salz, Pfeffer, Öl, Butter hinzufügen.';
  
  const prompt = `Erstelle ${count} abwechslungsreiche, leckere Rezepte für ${retailer} basierend auf diesen aktuellen Angeboten:

${offerList}

WICHTIG: ${requirement}

Jedes Rezept sollte:
- Einen aussagekräftigen Titel haben
- Eine kurze Beschreibung enthalten
- Eine Liste von Zutaten haben (nur Zutaten-Namen, keine Mengen)
- Für 2-4 Personen geeignet sein
- Einfach und alltagstauglich sein

Antworte NUR mit einem JSON-Array in diesem Format:
[
  {
    "title": "Rezept-Name",
    "description": "Kurze Beschreibung",
    "ingredients": ["Zutat 1", "Zutat 2", "Zutat 3"]
  }
]

Keine Markdown, keine Erklärungen, nur JSON!`;

  // Retry-Logik mit Exponential Backoff
  const maxRetries = 3;
  let lastError = null;
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 60000); // 60s Timeout
      
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'system',
              content: 'Du bist ein professioneller Koch und Rezept-Entwickler. Du erstellst kreative, leckere Rezepte basierend auf verfügbaren Zutaten.'
            },
            {
              role: 'user',
              content: prompt
            }
          ],
          temperature: 0.8,
          max_tokens: 4000,
        }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        let errorMessage = `OpenAI API error: ${response.status}`;
        try {
          const errorJson = JSON.parse(errorText);
          errorMessage += ` - ${errorJson.error?.message || errorText}`;
        } catch {
          errorMessage += ` - ${errorText.substring(0, 200)}`;
        }
        
        // Rate limit - warte länger
        if (response.status === 429) {
          const waitTime = Math.min(30000 * attempt, 120000); // Max 2 Minuten
          console.log(`   ⏳ Rate limit erreicht, warte ${waitTime/1000}s...`);
          await new Promise(resolve => setTimeout(resolve, waitTime));
          continue; // Retry
        }
        
        throw new Error(errorMessage);
      }

      const data = await response.json();
      const content = data.choices[0]?.message?.content || '';
      
      if (!content) {
        throw new Error('Leere Antwort von OpenAI API');
      }
      
      // Extrahiere JSON aus Antwort
      // Extrahiere JSON-Array oder Dict mit .recipes-Array
      let recipes;
      try {
        // Versuche zuerst ein reines JSON-Array zu parsen
        const jsonMatch = content.match(/\[[\s\S]*\]/);
        if (jsonMatch) {
          recipes = JSON.parse(jsonMatch[0]);
          if (!Array.isArray(recipes)) {
            throw new Error('Antwort enthält kein JSON-Array');
          }
          return recipes;
        }

        // Fallback: Versuche ein Object mit "recipes"-Array
        const dictMatch = content.match(/\{[\s\S]*\}/);
        if (dictMatch) {
          const parsed = JSON.parse(dictMatch[0]);
          if (parsed.recipes && Array.isArray(parsed.recipes)) {
            return parsed.recipes;
          }
        }

        throw new Error('Kein JSON-Array oder "recipes"-Array in Antwort gefunden');
      } catch (parseError) {
        lastError = parseError;
        throw parseError; // Re-throw um in outer catch zu landen
      }
      
    } catch (error) {
      lastError = error;

      if (error.name === 'AbortError') {
        console.error(`   ⚠️  Timeout bei Versuch ${attempt}/${maxRetries}`);
      } else if (error.message && error.message.includes('fetch')) {
        console.error(`   ⚠️  Network-Fehler bei Versuch ${attempt}/${maxRetries}: ${error.message}`);
      } else {
        console.error(`   ⚠️  Fehler bei Versuch ${attempt}/${maxRetries}: ${error.message}`);
      }
      
      // Warte vor Retry (exponential backoff)
      if (attempt < maxRetries) {
        const waitTime = Math.min(2000 * Math.pow(2, attempt - 1), 10000);
        console.log(`   ⏳ Warte ${waitTime/1000}s vor Retry...`);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }
  
  // Wenn wir hier rauskommen, dann sind alle Versuche fehlgeschlagen
  throw new Error(`Fehler nach ${maxRetries} Versuchen: ${lastError?.message || 'Unbekannter Fehler'}`);
}

/**
 * Validiert Rezept (prüft ob Zutaten in Angeboten sind)
 */
function validateRecipe(recipe, offers, minPercentage = 1.0) {
  if (!recipe.ingredients || !Array.isArray(recipe.ingredients)) {
    return false;
  }
  
  const totalIngredients = recipe.ingredients.length;
  if (totalIngredients === 0) {
    return false;
  }
  
  const matchingIngredients = recipe.ingredients.filter(ing => 
    isIngredientInOffers(ing, offers)
  );
  
  const percentage = matchingIngredients.length / totalIngredients;
  return percentage >= minPercentage;
}

/**
 * Hauptfunktion
 */
async function main() {
  console.log('🍳 Rezept-Generator aus JSON-Dateien\n');
  
  const baseDir = resolve(__dirname, '../media/prospekte');
  
  // Zielzeitraum: Aktuelle Woche (oder nächste Woche)
  const now = new Date();
  const targetStart = new Date(now);
  targetStart.setDate(now.getDate() - now.getDay() + 1); // Montag dieser Woche
  targetStart.setHours(0, 0, 0, 0);
  
  const targetEnd = new Date(targetStart);
  targetEnd.setDate(targetStart.getDate() + 6); // Sonntag dieser Woche
  targetEnd.setHours(23, 59, 59, 999);
  
  console.log(`📅 Zielzeitraum: ${targetStart.toISOString().split('T')[0]} - ${targetEnd.toISOString().split('T')[0]}\n`);
  
  // Lade Angebote
  console.log('📥 Lade Angebote aus JSON-Dateien...\n');
  
  const kauflandOffersRaw = await loadOffersFromJson(
    join(baseDir, 'kaufland/kaufland.json'),
    'Kaufland'
  );
  console.log(`✅ Kaufland: ${kauflandOffersRaw.length} Angebote geladen`);
  
  const aldiNordOffersRaw = await loadOffersFromJson(
    join(baseDir, 'aldi_nord/aldi_nord.json'),
    'ALDI Nord'
  );
  console.log(`✅ ALDI Nord: ${aldiNordOffersRaw.length} Angebote geladen`);
  
  const aldiSuedOffersRaw = await loadOffersFromJson(
    join(baseDir, 'aldi_sued/aldi_sued.json'),
    'ALDI Süd'
  );
  console.log(`✅ ALDI Süd: ${aldiSuedOffersRaw.length} Angebote geladen\n`);
  
  const totalOffersRaw = kauflandOffersRaw.length + aldiNordOffersRaw.length + aldiSuedOffersRaw.length;
  console.log(`📊 Gesamt geladen: ${totalOffersRaw} Angebote\n`);
  
  if (totalOffersRaw === 0) {
    console.error('❌ Keine Angebote gefunden!');
    process.exit(1);
  }
  
  // Generiere Rezepte für jeden Supermarkt einzeln
  const retailers = [
    { name: 'Kaufland', offers: kauflandOffersRaw },
    { name: 'ALDI Nord', offers: aldiNordOffersRaw },
    { name: 'ALDI Süd', offers: aldiSuedOffersRaw },
  ];
  
  const allRecipes = [];
  const targetCountPerRetailer = Math.ceil(100 / retailers.length); // ~34 pro Supermarkt
  
  for (const retailer of retailers) {
    if (retailer.offers.length === 0) {
      console.log(`\n⏭️  ${retailer.name}: Keine Angebote, überspringe...\n`);
      continue;
    }
    
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🍳 ${retailer.name} - Rezept-Generierung`);
    console.log(`${'='.repeat(60)}`);
    
    // Filtere Angebote auf Zielzeitraum
    const filteredOffers = filterOffersByDateRange(retailer.offers, targetStart, targetEnd);
    console.log(`📅 Nach Zeitfilterung: ${filteredOffers.length} Angebote (von ${retailer.offers.length})\n`);
    
    // Dedupliziere Angebote (nur exakt identische)
    const uniqueOffers = dedupeOffers(filteredOffers, retailer.name);
    console.log('');
    
    const retailerRecipes = [];
    
    // Phase 1: 100% aus Angeboten (ca. 60% der Rezepte)
    const strictTarget = Math.floor(targetCountPerRetailer * 0.6);
    console.log(`🍳 Phase 1: Generiere ${strictTarget} Rezepte mit 100% Zutaten aus Angeboten...\n`);
    
    let strictRecipes = [];
    let attempts = 0;
    const maxAttempts = 8; // Mehr Versuche
    
    while (strictRecipes.length < strictTarget && attempts < maxAttempts) {
      attempts++;
      const needed = strictTarget - strictRecipes.length;
      const batchSize = Math.min(needed, 12); // Kleinere Batches für mehr Stabilität
      
      console.log(`   Versuch ${attempts}/${maxAttempts}: Generiere ${batchSize} Rezepte...`);
      
      try {
        const batch = await generateRecipesWithGPT(uniqueOffers, retailer.name, batchSize, true);
        
        if (!batch || !Array.isArray(batch)) {
          console.error(`   ⚠️  Ungültige Antwort: Kein Array erhalten\n`);
          await new Promise(resolve => setTimeout(resolve, 3000));
          continue;
        }
        
        // Validiere und filtere
        const valid = batch.filter(r => validateRecipe(r, uniqueOffers, 1.0));
        strictRecipes.push(...valid);
        
        console.log(`   ✅ ${valid.length}/${batch.length} Rezepte validiert (100% Zutaten)\n`);
        
        // Warte kurz zwischen Requests
        await new Promise(resolve => setTimeout(resolve, 2500));
      } catch (error) {
        console.error(`   ⚠️  Fehler: ${error.message}`);
        if (error.message.includes('fetch') || error.message.includes('network') || error.message.includes('ECONNREFUSED')) {
          console.error(`   💡 Network-Problem erkannt. Warte 5 Sekunden...\n`);
          await new Promise(resolve => setTimeout(resolve, 5000));
        } else {
          console.error(`\n`);
          // Bei anderen Fehlern auch kurz warten
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
    }
    
    retailerRecipes.push(...strictRecipes);
    console.log(`✅ Phase 1 abgeschlossen: ${strictRecipes.length} Rezepte (100% Zutaten)\n`);
    
    // Phase 2: 75% aus Angeboten (Rest)
    const remaining = targetCountPerRetailer - retailerRecipes.length;
    if (remaining > 0) {
      console.log(`🍳 Phase 2: Generiere ${remaining} Rezepte mit 75% Zutaten aus Angeboten...\n`);
      
      let flexibleRecipes = [];
      attempts = 0;
      const maxAttemptsPhase2 = 8;
      
      while (flexibleRecipes.length < remaining && attempts < maxAttemptsPhase2) {
        attempts++;
        const needed = remaining - flexibleRecipes.length;
        const batchSize = Math.min(needed, 12); // Kleinere Batches
        
        console.log(`   Versuch ${attempts}/${maxAttemptsPhase2}: Generiere ${batchSize} Rezepte...`);
        
        try {
          const batch = await generateRecipesWithGPT(uniqueOffers, retailer.name, batchSize, false);
          
          if (!batch || !Array.isArray(batch)) {
            console.error(`   ⚠️  Ungültige Antwort: Kein Array erhalten\n`);
            await new Promise(resolve => setTimeout(resolve, 3000));
            continue;
          }
          
          // Validiere und filtere (75% Minimum)
          const valid = batch.filter(r => validateRecipe(r, uniqueOffers, 0.75));
          flexibleRecipes.push(...valid);
          
          console.log(`   ✅ ${valid.length}/${batch.length} Rezepte validiert (≥75% Zutaten)\n`);
          
          await new Promise(resolve => setTimeout(resolve, 2500));
        } catch (error) {
          console.error(`   ⚠️  Fehler: ${error.message}`);
          if (error.message.includes('fetch') || error.message.includes('network') || error.message.includes('ECONNREFUSED')) {
            console.error(`   💡 Network-Problem erkannt. Warte 5 Sekunden...\n`);
            await new Promise(resolve => setTimeout(resolve, 5000));
          } else {
            console.error(`\n`);
            await new Promise(resolve => setTimeout(resolve, 2000));
          }
        }
      }
      
      retailerRecipes.push(...flexibleRecipes);
      console.log(`✅ Phase 2 abgeschlossen: ${flexibleRecipes.length} Rezepte (≥75% Zutaten)\n`);
    }
    
    // Füge Retailer-Info hinzu
    const recipesWithRetailer = retailerRecipes.map((recipe, index) => ({
      id: `recipe-${retailer.name.toLowerCase().replace(/\s+/g, '-')}-${index + 1}`,
      title: recipe.title,
      description: recipe.description,
      ingredients: recipe.ingredients,
      retailer: retailer.name,
      weekKey: new Date().toISOString().split('T')[0],
      createdAt: new Date().toISOString(),
    }));
    
    allRecipes.push(...recipesWithRetailer);
    
    console.log(`✅ ${retailer.name}: ${retailerRecipes.length} Rezepte generiert\n`);
  }
  
  // Speichere Rezepte
  const outputPath = join(baseDir, '../data/recipes_from_json.json');
  const recipesData = {
    generatedAt: new Date().toISOString(),
    totalRecipes: allRecipes.length,
    retailers: retailers.map(r => ({
      name: r.name,
      offers: r.offers.length,
      recipes: allRecipes.filter(rec => rec.retailer === r.name).length,
    })),
    recipes: allRecipes,
  };
  
  await fs.mkdir(dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, JSON.stringify(recipesData, null, 2));
  
  console.log('✅ FERTIG!\n');
  console.log(`📊 Zusammenfassung:`);
  console.log(`   Gesamt: ${allRecipes.length} Rezepte`);
  for (const retailer of retailers) {
    const count = allRecipes.filter(r => r.retailer === retailer.name).length;
    console.log(`   ${retailer.name}: ${count} Rezepte`);
  }
  console.log(`\n💾 Gespeichert in: ${outputPath}`);
}

main().catch(error => {
  console.error('\n❌ Fehler:', error.message);
  process.exit(1);
});

