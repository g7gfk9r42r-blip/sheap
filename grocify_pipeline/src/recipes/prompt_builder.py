"""Recipe generation prompt builder"""
from typing import List, Dict


def build_recipe_prompt(offers: List[Dict], batch_num: int, batch_size: int, supermarket: str, weekkey: str) -> str:
    """Build prompt for recipe generation"""
    
    # Sample offers for context (max 50)
    offer_samples = offers[:50]
    offers_text = "\n".join([
        f"- {o['title']} ({o['price_now']}€) [ID: {o['offerId']}]"
        for o in offer_samples
    ])
    
    prompt = f"""Generate EXACTLY {batch_size} unique recipes using these {supermarket} offers from week {weekkey}.

AVAILABLE OFFERS:
{offers_text}

OUTPUT REQUIREMENTS:
- Pure JSON array ONLY - NO markdown, NO explanations
- Each recipe MUST reference offers by offerId in offerRefs
- Keep titles under 80 chars, descriptions under 200 chars
- Steps should be short (max 6 steps)
- Use realistic amounts (g, ml, stk)
- Variety: breakfast, lunch, dinner, snacks
- Include nutrition estimates

SCHEMA:
[
  {{
    "id": "{supermarket}-{batch_num}01",
    "title": "Recipe Title",
    "description": "Short appetizing description",
    "supermarket": "{supermarket}",
    "servings": 2,
    "time_total_min": 30,
    "difficulty": "easy",
    "tags": ["high_protein", "budget"],
    "ingredients": [
      {{
        "name": "Cherry-Tomaten",
        "amount": 250,
        "unit": "g",
        "offerRefs": [{{"offerId": "...", "brand": "...", "price_now": 0.44}}]
      }}
    ],
    "steps": ["Step 1", "Step 2", "Step 3"],
    "nutrition": {{
      "kcal_total": 800,
      "kcal_per_serving": 400,
      "protein_g": 25,
      "fat_g": 15,
      "carbs_g": 50,
      "kcal_source": "calculated",
      "kcal_confidence": "medium",
      "coverage": {{"ingredients_total": 5, "ingredients_enriched": 4, "ingredients_missing": 1}}
    }},
    "image": {{"localPath": "output/images/{supermarket}/{supermarket}-{batch_num}01.webp"}}
  }}
]

Generate {batch_size} recipes now as JSON array:"""
    
    return prompt

