import { Offer, Recipe, Retailer } from '../types.js';

const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
const NODE_ENV = process.env.NODE_ENV || 'development';

interface OpenAIMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface OpenAIResponse {
  choices: Array<{
    message: {
      content: string;
    };
  }>;
}

// Fallback mock recipes when OpenAI is not available
function generateMockRecipes(retailer: Retailer, weekKey: string, offers: Offer[]): Recipe[] {
  const mockRecipes = [
    {
      title: `${retailer} Special Pasta`,
      description: `A delicious pasta dish using this week's ${retailer} offers. Perfect for a quick and satisfying meal.`,
      ingredients: ['Pasta', 'Tomatoes', 'Garlic', 'Olive Oil', 'Parmesan'],
    },
    {
      title: `${retailer} Fresh Salad Bowl`,
      description: `A healthy and refreshing salad featuring the best seasonal ingredients from ${retailer}.`,
      ingredients: ['Mixed Greens', 'Cucumber', 'Cherry Tomatoes', 'Avocado', 'Lemon Dressing'],
    },
    {
      title: `${retailer} One-Pot Wonder`,
      description: `An easy one-pot meal that makes the most of ${retailer}'s current offers. Minimal cleanup, maximum flavor.`,
      ingredients: ['Rice', 'Chicken', 'Vegetables', 'Herbs', 'Stock'],
    }
  ];

  return mockRecipes.map((recipe, index) => ({
    id: `recipe-${retailer.toLowerCase()}-${index + 1}-${weekKey}`,
    title: recipe.title,
    description: recipe.description,
    ingredients: recipe.ingredients,
    retailer,
    weekKey,
    createdAt: new Date().toISOString(),
  }));
}

async function callOpenAI(messages: OpenAIMessage[]): Promise<string> {
  if (!OPENAI_API_KEY) {
    throw new Error('OpenAI API key not configured');
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages,
      temperature: 0.7,
      max_tokens: 1000,
    }),
  });

  if (!response.ok) {
    throw new Error(`OpenAI API error: ${response.status} ${response.statusText}`);
  }

  const data = await response.json() as OpenAIResponse;
  return data.choices[0]?.message?.content || '';
}

function parseRecipesFromAI(content: string): Omit<Recipe, 'id' | 'retailer' | 'weekKey' | 'createdAt'>[] {
  try {
    // Try to extract JSON from the response
    const jsonMatch = content.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      throw new Error('No JSON array found in response');
    }

    const recipes = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(recipes)) {
      throw new Error('Response is not an array');
    }

    return recipes.map((recipe: any) => ({
      title: recipe.title || 'Untitled Recipe',
      description: recipe.description || 'A delicious recipe',
      ingredients: Array.isArray(recipe.ingredients) ? recipe.ingredients : [],
    }));
  } catch (error) {
    console.warn('[openai] Failed to parse AI response:', error);
    throw new Error('Failed to parse AI response');
  }
}

export async function generateRecipes({
  retailer,
  weekKey,
  offers
}: {
  retailer: Retailer;
  weekKey: string;
  offers: Offer[];
}): Promise<Recipe[]> {
  // Use mock recipes in development or if API key is missing
  if (NODE_ENV === 'development' || !OPENAI_API_KEY) {
    console.log(`[openai] Using mock recipes for ${retailer} (${weekKey})`);
    return generateMockRecipes(retailer, weekKey, offers);
  }

  try {
    // Create offer summary for AI
    const offerSummary = offers
      .slice(0, 10) // Limit to first 10 offers to avoid token limits
      .map(offer => `${offer.title} (€${offer.price.toFixed(2)}${offer.unit ? `/${offer.unit}` : ''})`)
      .join(', ');

    const messages: OpenAIMessage[] = [
      {
        role: 'system',
        content: `You are a helpful cooking assistant. Create 3 simple, affordable recipes using some of the weekly grocery offers provided. 

Rules:
- Use ingredients that are likely to be on sale based on the offers
- Keep recipes simple and budget-friendly
- Each recipe should serve 2-4 people
- Include common pantry staples
- Return ONLY a JSON array with this exact format:
[
  {
    "title": "Recipe Name",
    "description": "Brief description of the recipe",
    "ingredients": ["ingredient1", "ingredient2", "ingredient3"]
  }
]

Do not include any other text or formatting.`
      },
      {
        role: 'user',
        content: `Create 3 recipes using these ${retailer} offers for week ${weekKey}:\n\n${offerSummary}`
      }
    ];

    const response = await callOpenAI(messages);
    const recipeData = parseRecipesFromAI(response);

    // Convert to Recipe objects
    return recipeData.map((recipe, index) => ({
      id: `recipe-${retailer.toLowerCase()}-${index + 1}-${weekKey}`,
      title: recipe.title,
      description: recipe.description,
      ingredients: recipe.ingredients,
      retailer,
      weekKey,
      createdAt: new Date().toISOString(),
    }));

  } catch (error) {
    console.warn(`[openai] Failed to generate recipes for ${retailer}:`, error);
    console.log(`[openai] Falling back to mock recipes`);
    return generateMockRecipes(retailer, weekKey, offers);
  }
}

export interface LidlOffer {
  title: string;
  price: number;
  unit?: string;
  discount?: string;
  image: string;
}

/**
 * Extrahiert Angebotsinformationen aus einem Lidl-Prospektbild mit GPT Vision
 */
export async function extractLidlOfferFromImage(imageUrl: string): Promise<LidlOffer | null> {
  if (!OPENAI_API_KEY) {
    console.warn('[openai] OPENAI_API_KEY nicht gesetzt, überspringe Bild-Analyse');
    return null;
  }

  try {
    const messages: OpenAIMessage[] = [
      {
        role: 'system',
        content: `Du bist ein Experte für die Analyse von Supermarkt-Prospekten. 
Analysiere Angebotsbilder aus Lidl-Prospekten und extrahiere strukturierte Daten.

WICHTIG:
- Wenn kein Angebot erkennbar ist → gib null zurück
- Wenn das Bild nur Logo, Navigation oder Werbung zeigt → gib null zurück
- Extrahiere NUR echte Produktangebote mit Preis

Rückgabe-Format (NUR JSON, kein zusätzlicher Text):
{
  "title": "Produktname",
  "price": 10.99,
  "unit": "5 Stück",
  "discount": "-31%",
  "image": "${imageUrl}"
}

Oder null wenn kein Angebot erkennbar.`
      },
      {
        role: 'user',
        content: [
          {
            type: 'text',
            text: `Analysiere dieses Angebotsbild aus einem Lidl-Prospekt. 
Extrahiere: Produkttitel, Preis (als Zahl), Einheit (falls vorhanden), Rabatt/Gratis-Angabe (z.B. "-31%", "AKTION +50% gratis").

Wenn kein Angebot erkennbar → null.
Rückgabe NUR als JSON.`
          },
          {
            type: 'image_url',
            image_url: {
              url: imageUrl
            }
          }
        ] as any
      }
    ];

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini', // Vision-fähiges Modell
        messages: messages as any,
        temperature: 0.3, // Niedrigere Temperatur für präzisere Extraktion
        max_tokens: 500,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OpenAI API error: ${response.status} ${response.statusText} - ${errorText}`);
    }

    const data = await response.json() as OpenAIResponse;
    const content = data.choices[0]?.message?.content || '';

    // Parse JSON aus Antwort
    if (content.trim().toLowerCase() === 'null') {
      return null;
    }

    // Versuche JSON zu extrahieren
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.warn(`[openai] Kein JSON in GPT-Antwort gefunden: ${content.substring(0, 100)}`);
      return null;
    }

    const parsed = JSON.parse(jsonMatch[0]) as LidlOffer;
    
    // Validierung
    if (!parsed.title || typeof parsed.price !== 'number' || !parsed.image) {
      console.warn(`[openai] Ungültige Offer-Daten:`, parsed);
      return null;
    }

    return parsed;

  } catch (error) {
    console.warn(`[openai] Fehler bei Bild-Analyse (${imageUrl.substring(0, 50)}...):`, error instanceof Error ? error.message : String(error));
    return null;
  }
}