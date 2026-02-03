"""Nutrition enrichment with ranges"""
import sys
from pathlib import Path
from typing import List, Dict

# Add parent to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from nutrition.usda_fdc import USDAFoodDataCentralProvider
    from nutrition.openfoodfacts import OpenFoodFactsProvider
    from nutrition.normalization import get_canonical_key
    from nutrition.cache import NutritionCache
    NUTRITION_AVAILABLE = True
except ImportError:
    NUTRITION_AVAILABLE = False


class NutritionEnricher:
    """Enrich recipes with nutrition ranges"""
    
    def __init__(self, cache_dir: Path):
        self.stats = {
            'total_ingredients': 0,
            'enriched': 0,
            'missing': 0,
            'cache_hits': 0
        }
        
        if not NUTRITION_AVAILABLE:
            print("⚠️  Nutrition modules not available, using placeholders")
            self.available = False
            return
        
        self.available = True
        self.cache = NutritionCache(str(cache_dir))
        self.usda = USDAFoodDataCentralProvider()
        self.off = OpenFoodFactsProvider()
    
    def fetch_nutrition(self, ingredient_name: str) -> dict:
        """Fetch nutrition for ingredient"""
        if not self.available:
            return None
        
        canonical = get_canonical_key(ingredient_name)
        
        # Check cache
        cached = self.cache.get(canonical)
        if cached:
            self.stats['cache_hits'] += 1
            return cached.get('nutrition')
        
        # Try USDA
        if self.usda.is_available():
            results = self.usda.search(canonical, limit=3)
            if results:
                # Get range from top results
                kcal_values = [r['nutrition_per_100g']['kcal'] for r in results if r.get('nutrition_per_100g')]
                if kcal_values:
                    nutrition = {
                        'kcal_per_100g_range': [min(kcal_values), max(kcal_values)],
                        'source': 'usda'
                    }
                    self.cache.set(canonical, nutrition, {'source': 'usda'})
                    return nutrition
        
        # Try OFF
        results = self.off.search(canonical, limit=3)
        if results:
            kcal_values = [r['nutrition_per_100g']['kcal'] for r in results if r.get('nutrition_per_100g')]
            if kcal_values:
                nutrition = {
                    'kcal_per_100g_range': [min(kcal_values), max(kcal_values)],
                    'source': 'openfoodfacts'
                }
                self.cache.set(canonical, nutrition, {'source': 'off'})
                return nutrition
        
        # Mark missing
        self.cache.add_missing(canonical, ingredient_name)
        return None
    
    def calculate_recipe_nutrition(self, ingredients: List[Dict]) -> Dict:
        """Calculate recipe nutrition with ranges"""
        total_kcal_min = 0.0
        total_kcal_max = 0.0
        enriched_count = 0
        total_count = 0
        
        for ing in ingredients:
            # Skip pantry
            if ing.get('availability') == 'pantry':
                continue
            
            total_count += 1
            self.stats['total_ingredients'] += 1
            
            name = ing.get('name', '')
            amount = ing.get('amount', 0)
            unit = ing.get('unit', 'g')
            
            # Get nutrition
            nutrition = self.fetch_nutrition(name)
            
            if nutrition and 'kcal_per_100g_range' in nutrition:
                # Convert to grams
                grams = amount
                if unit == 'kg':
                    grams = amount * 1000
                elif unit in ['ml', 'l']:
                    grams = amount if unit == 'ml' else amount * 1000
                
                # Calculate
                factor = grams / 100.0
                kcal_min, kcal_max = nutrition['kcal_per_100g_range']
                total_kcal_min += kcal_min * factor
                total_kcal_max += kcal_max * factor
                enriched_count += 1
                self.stats['enriched'] += 1
                
                # Store in ingredient
                ing['nutrition'] = {
                    'kcal_range': [round(kcal_min * factor, 1), round(kcal_max * factor, 1)],
                    'source': nutrition['source']
                }
            else:
                ing['nutrition'] = None
                self.stats['missing'] += 1
        
        # Build result
        return {
            'kcal_total_range': [round(total_kcal_min, 1), round(total_kcal_max, 1)] if enriched_count > 0 else None,
            'kcal_per_serving_range': None,  # Will be calculated from total
            'nutrition_source': 'calculated' if enriched_count > 0 else 'missing',
            'coverage': {
                'ingredients_total': total_count,
                'ingredients_enriched': enriched_count,
                'ingredients_missing': total_count - enriched_count
            },
            'disclaimer_short': 'Angaben ohne Gewähr. Nährwerte basieren auf Durchschnittswerten.'
        }
    
    def enrich_recipes(self, recipes: List[Dict]) -> List[Dict]:
        """Enrich all recipes"""
        if not self.available:
            # Add placeholder nutrition
            for recipe in recipes:
                recipe['nutrition'] = {
                    'kcal_total_range': None,
                    'kcal_per_serving_range': None,
                    'nutrition_source': 'missing',
                    'coverage': {'ingredients_total': len(recipe.get('ingredients', [])), 'ingredients_enriched': 0, 'ingredients_missing': 0},
                    'disclaimer_short': 'Nährwertberechnung nicht verfügbar.'
                }
            return recipes
        
        print(f"🔬 Enriching nutrition for {len(recipes)} recipes")
        
        for recipe in recipes:
            nutrition = self.calculate_recipe_nutrition(recipe.get('ingredients', []))
            
            # Calculate per serving
            servings = recipe.get('servings', 2)
            if nutrition['kcal_total_range']:
                kcal_min, kcal_max = nutrition['kcal_total_range']
                nutrition['kcal_per_serving_range'] = [
                    round(kcal_min / servings, 1),
                    round(kcal_max / servings, 1)
                ]
            
            recipe['nutrition'] = nutrition
        
        # Save cache
        if self.available:
            self.cache.save_all()
        
        print(f"   ✅ Enriched: {self.stats['enriched']}/{self.stats['total_ingredients']} ingredients")
        print(f"   💾 Cache hits: {self.stats['cache_hits']}")
        print(f"   ❌ Missing: {self.stats['missing']}")
        
        return recipes

