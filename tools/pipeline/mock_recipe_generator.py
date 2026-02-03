"""Mock recipe generator for testing without OpenAI API"""
import random
from typing import List, Dict


RECIPE_TEMPLATES = [
    {
        "title_template": "{ingredient1} Bowl",
        "description": "Frische Bowl mit {ingredient1}",
        "tags": ["quick", "healthy"],
        "difficulty": "easy"
    },
    {
        "title_template": "{ingredient1} mit {ingredient2}",
        "description": "Klassisches Gericht mit {ingredient1} und {ingredient2}",
        "tags": ["traditional", "budget"],
        "difficulty": "medium"
    },
    {
        "title_template": "Schnelle {ingredient1} Pfanne",
        "description": "Schnell zubereitet mit frischen Zutaten",
        "tags": ["quick", "easy"],
        "difficulty": "easy"
    },
]


class MockRecipeGenerator:
    """Generate mock recipes from offers for testing"""
    
    def generate(self, offers: List[Dict], supermarket: str, target_count: int) -> List[Dict]:
        """Generate mock recipes"""
        print(f"🎭 Mock: Generating {target_count} recipes from {len(offers)} offers")
        
        recipes = []
        
        for i in range(target_count):
            # Select random offers
            selected_offers = random.sample(offers, min(3, len(offers)))
            template = random.choice(RECIPE_TEMPLATES)
            
            # Build title
            ingredient1 = selected_offers[0]['title'].split()[0] if selected_offers else "Produkt"
            ingredient2 = selected_offers[1]['title'].split()[0] if len(selected_offers) > 1 else "Zutaten"
            
            title = template['title_template'].format(ingredient1=ingredient1, ingredient2=ingredient2)
            description = template['description'].format(ingredient1=ingredient1, ingredient2=ingredient2)
            
            # Build ingredients
            ingredients = []
            for offer in selected_offers:
                ingredients.append({
                    "name": offer['title'],
                    "amount": random.choice([200, 250, 300, 400, 500]),
                    "unit": "g",
                    "availability": "offer",
                    "offerRefs": [{
                        "offerId": offer['offer_id'],
                        "title": offer['title'],
                        "brand": offer.get('brand'),
                        "price": offer['price_now'],
                        "price_before": offer.get('price_before'),
                        "store_zone": offer.get('store_zone')
                    }],
                    "isOfferItem": True,
                    "find_it_fast": {
                        "store_zone": offer.get('store_zone', 'Zentrale Gänge'),
                        "search_terms": [offer['title'].lower().split()[0]],
                        "pack_hint": None
                    }
                })
            
            # Add pantry items
            pantry_items = ["Salz", "Pfeffer", "Olivenöl"]
            for pantry in random.sample(pantry_items, 2):
                ingredients.append({
                    "name": pantry,
                    "amount": random.choice([1, 2]),
                    "unit": "tl",
                    "availability": "pantry",
                    "offerRefs": [],
                    "isOfferItem": False,
                    "find_it_fast": {
                        "store_zone": "Pantry",
                        "search_terms": [pantry.lower()],
                        "pack_hint": None
                    }
                })
            
            # Build steps
            steps = [
                f"Zutaten vorbereiten und {ingredient1} waschen.",
                f"{ingredient1} in Stücke schneiden.",
                "In einer Pfanne erhitzen.",
                "Mit Salz und Pfeffer würzen.",
                "Servieren und genießen."
            ]
            
            recipe = {
                "id": f"{supermarket}_recipe_{i+1:03d}",
                "title": title[:50],
                "description": description[:200],
                "supermarket": supermarket,
                "servings": random.choice([2, 4]),
                "prep_time_min": random.choice([10, 15, 20]),
                "cook_time_min": random.choice([15, 20, 25, 30]),
                "difficulty": template['difficulty'],
                "tags": template['tags'],
                "ingredients": ingredients,
                "steps": steps,
                "cost_estimate": {"min": 0.0, "max": 0.0},  # Will be calculated
                "image_prompt": f"clean iPhone food photo of {title}, natural light, appetizing, high detail",
                "nutrition_placeholder": {"needs_enrichment": True}
            }
            
            recipes.append(recipe)
        
        print(f"   ✅ Generated {len(recipes)} mock recipes")
        return recipes
    
    def enrich_with_offer_refs(self, recipes: List[Dict], offers: List[Dict]) -> List[Dict]:
        """Already enriched in mock generator"""
        return recipes

