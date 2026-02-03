"""Generate iPhone-optimized recipes from offers"""
import json
import os
import re
import urllib.request
import urllib.error
from typing import List, Dict, Any
from .basics_catalog import is_pantry, is_basic, get_basic_info


class RecipeGenerator:
    """Generate recipes using OpenAI"""
    
    def __init__(self, api_key: str = None):
        self.api_key = api_key or os.getenv('OPENAI_API_KEY')
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY required")
        
        self.base_url = "https://api.openai.com/v1/chat/completions"
    
    def build_prompt(self, offers: List[Dict], supermarket: str, target_count: int) -> str:
        """Build generation prompt"""
        # Sample offers
        offer_samples = offers[:30]
        offers_text = "\n".join([
            f"- {o['title']} ({o.get('brand', 'N/A')}): {o['price_now']}€ [ID: {o['offer_id']}] (Zone: {o.get('store_zone', 'N/A')})"
            for o in offer_samples
        ])
        
        prompt = f"""Generate EXACTLY {target_count} iPhone-optimized recipes using these {supermarket} offers.

OFFERS AVAILABLE:
{offers_text}

OUTPUT REQUIREMENTS:
- Pure JSON array ONLY
- Each recipe: short title (max 50 chars), 5-10 ingredients, 3-6 steps
- Prioritize offer items, supplement with basics/pantry
- Mark each ingredient availability: "offer"|"basic"|"pantry"

INGREDIENT SCHEMA:
{{
  "name": "Cherry-Tomaten",
  "amount": 250,
  "unit": "g",
  "availability": "offer",
  "offerRefs": ["{{"offerId": "...", "price": 0.99}}],
  "isOfferItem": true,
  "find_it_fast": {{
    "store_zone": "Obst & Gemüse",
    "search_terms": ["tomaten", "cherry"],
    "pack_hint": "250g Schale"
  }}
}}

RECIPE SCHEMA:
[
  {{
    "id": "{supermarket}_recipe_001",
    "title": "Mediterrane Bowl",
    "description": "Schnell & gesund",
    "supermarket": "{supermarket}",
    "servings": 2,
    "prep_time_min": 15,
    "cook_time_min": 10,
    "difficulty": "easy",
    "tags": ["quick", "healthy", "budget"],
    "ingredients": [...],
    "steps": ["Step 1", "Step 2", "Step 3"],
    "cost_estimate": {{"min": 3.0, "max": 5.0}},
    "image_prompt": "clean iPhone food photo, natural light, ...",
    "nutrition_placeholder": {{"needs_enrichment": true}}
  }}
]

Generate {target_count} recipes now:"""
        
        return prompt
    
    def generate(self, offers: List[Dict], supermarket: str, target_count: int = 40) -> List[Dict]:
        """Generate recipes"""
        print(f"🤖 Generating {target_count} recipes for {supermarket}")
        
        prompt = self.build_prompt(offers, supermarket, target_count)
        
        # Call OpenAI with retry
        for attempt in range(3):
            try:
                # Prepare request
                data = json.dumps({
                    "model": "gpt-4o-mini",
                    "messages": [
                        {"role": "system", "content": "You are a recipe generation expert. Output ONLY valid JSON arrays."},
                        {"role": "user", "content": prompt}
                    ],
                    "temperature": 0.8,
                    "max_tokens": 8000
                }).encode('utf-8')
                
                req = urllib.request.Request(
                    self.base_url,
                    data=data,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    }
                )
                
                with urllib.request.urlopen(req, timeout=60) as response:
                    response_data = json.loads(response.read().decode('utf-8'))
                    content = response_data['choices'][0]['message']['content']
                
                # Parse JSON
                recipes = self.parse_json_response(content)
                
                if len(recipes) >= target_count * 0.5:  # Accept if 50%+ generated
                    print(f"   ✅ Generated {len(recipes)} recipes")
                    return recipes[:target_count]
                else:
                    print(f"   ⚠️  Only {len(recipes)} recipes, retrying...")
            
            except Exception as e:
                print(f"   ❌ Attempt {attempt + 1} failed: {e}")
                if attempt == 2:
                    raise
        
        return []
    
    def parse_json_response(self, content: str) -> List[Dict]:
        """Parse JSON from LLM response"""
        # Remove markdown
        if '```' in content:
            content = re.sub(r'```json\s*', '', content)
            content = re.sub(r'```\s*', '', content)
        
        content = content.strip()
        
        try:
            data = json.loads(content)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict) and 'recipes' in data:
                return data['recipes']
            else:
                return [data]
        except json.JSONDecodeError as e:
            print(f"   JSON parse error: {e}")
            return []
    
    def enrich_with_offer_refs(self, recipes: List[Dict], offers: List[Dict]) -> List[Dict]:
        """Enrich recipes with proper offer references"""
        offer_map = {o['offer_id']: o for o in offers}
        
        for recipe in recipes:
            for ingredient in recipe.get('ingredients', []):
                # Check if ingredient references offers
                offer_refs = ingredient.get('offerRefs', [])
                if offer_refs:
                    # Enrich with full offer data
                    enriched_refs = []
                    for ref in offer_refs:
                        offer_id = ref.get('offerId')
                        if offer_id in offer_map:
                            offer = offer_map[offer_id]
                            enriched_refs.append({
                                'offerId': offer_id,
                                'title': offer['title'],
                                'brand': offer.get('brand'),
                                'price': offer['price_now'],
                                'price_before': offer.get('price_before'),
                                'store_zone': offer.get('store_zone')
                            })
                    ingredient['offerRefs'] = enriched_refs
                    ingredient['availability'] = 'offer'
                    ingredient['isOfferItem'] = True
                
                # Check if basic/pantry
                name = ingredient.get('name', '')
                if is_pantry(name):
                    ingredient['availability'] = 'pantry'
                    ingredient['isOfferItem'] = False
                    ingredient['offerRefs'] = []
                elif is_basic(name):
                    basic_info = get_basic_info(name)
                    ingredient.update(basic_info)
                    ingredient['isOfferItem'] = False
                    ingredient['offerRefs'] = []
        
        return recipes

