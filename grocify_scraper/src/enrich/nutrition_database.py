"""Nutrition database with multiple sources"""

import logging
from typing import Dict, Any, Optional, Tuple
import requests

logger = logging.getLogger(__name__)


# Kategorie-basierte Nährwerte (pro 100g) - Fallback
CATEGORY_NUTRITION = {
    "meat": {"kcal": 200, "protein": 20, "carbs": 0, "fat": 12},
    "poultry": {"kcal": 165, "protein": 31, "carbs": 0, "fat": 3.6},
    "fish": {"kcal": 150, "protein": 22, "carbs": 0, "fat": 6},
    "dairy": {"kcal": 100, "protein": 3.5, "carbs": 4.5, "fat": 3.5},
    "cheese": {"kcal": 300, "protein": 25, "carbs": 1, "fat": 22},
    "vegetables": {"kcal": 25, "protein": 1.5, "carbs": 5, "fat": 0.2},
    "fruits": {"kcal": 50, "protein": 0.5, "carbs": 12, "fat": 0.2},
    "grains": {"kcal": 350, "protein": 12, "carbs": 70, "fat": 2},
    "pasta": {"kcal": 130, "protein": 5, "carbs": 25, "fat": 1},
    "bread": {"kcal": 250, "protein": 8, "carbs": 45, "fat": 3},
    "pantry": {"kcal": 400, "protein": 10, "carbs": 60, "fat": 10},
}


class NutritionDatabase:
    """Nutrition database with multiple sources"""
    
    def __init__(self):
        self.openfoodfacts_cache = {}
    
    def get_nutrition(
        self, 
        product_name: str, 
        brand: Optional[str] = None,
        category: Optional[str] = None
    ) -> Tuple[Dict[str, float], str]:
        """
        Get nutrition values from best available source.
        
        Returns:
            (nutrition_dict, confidence)
            nutrition_dict: {"kcal": float, "protein": float, "carbs": float, "fat": float}
            confidence: "high"|"medium"|"low"
        """
        # Try OpenFoodFacts first
        if brand and product_name:
            nutrition, confidence = self._try_openfoodfacts(product_name, brand)
            if confidence == "high":
                return nutrition, confidence
        
        # Try category-based lookup
        if category:
            nutrition = CATEGORY_NUTRITION.get(category, CATEGORY_NUTRITION["pantry"])
            return nutrition, "medium"
        
        # Fallback to pantry
        return CATEGORY_NUTRITION["pantry"], "low"
    
    def _try_openfoodfacts(self, product_name: str, brand: str) -> Tuple[Dict[str, float], str]:
        """Try to get nutrition from OpenFoodFacts API"""
        try:
            # Search by brand + product name
            search_term = f"{brand} {product_name}"
            url = "https://world.openfoodfacts.org/cgi/search.pl"
            params = {
                "search_terms": search_term,
                "search_simple": 1,
                "action": "process",
                "json": 1,
                "page_size": 1,
            }
            
            response = requests.get(url, params=params, timeout=5)
            if response.status_code == 200:
                data = response.json()
                products = data.get("products", [])
                
                if products:
                    product = products[0]
                    nutriments = product.get("nutriments", {})
                    
                    nutrition = {
                        "kcal": nutriments.get("energy-kcal_100g", 0) or 0,
                        "protein": nutriments.get("proteins_100g", 0) or 0,
                        "carbs": nutriments.get("carbohydrates_100g", 0) or 0,
                        "fat": nutriments.get("fat_100g", 0) or 0,
                    }
                    
                    # If we got at least kcal, it's high confidence
                    if nutrition["kcal"] > 0:
                        return nutrition, "high"
            
            return {}, "low"
            
        except Exception as e:
            logger.debug(f"OpenFoodFacts lookup failed: {e}")
            return {}, "low"
    
    def calculate_recipe_nutrition(
        self, 
        ingredients: List[Dict[str, Any]]
    ) -> Dict[str, Tuple[float, float]]:
        """
        Calculate nutrition for a recipe.
        
        Returns:
            {
                "kcal": (min, max),
                "protein": (min, max),
                "carbs": (min, max),
                "fat": (min, max),
            }
        """
        total_kcal = 0.0
        total_protein = 0.0
        total_carbs = 0.0
        total_fat = 0.0
        
        for ing in ingredients:
            name = ing.get("name", "")
            amount = ing.get("amount", 0)  # in grams
            unit = ing.get("unit", "g")
            
            # Convert to grams
            if unit == "kg":
                amount = amount * 1000
            elif unit == "l" or unit == "ml":
                # Approximate: 1ml ≈ 1g for most liquids
                amount = amount if unit == "ml" else amount * 1000
            
            # Get nutrition per 100g
            brand = ing.get("brand")
            category = ing.get("category")
            nutrition, confidence = self.get_nutrition(name, brand, category)
            
            # Calculate for this ingredient
            factor = amount / 100.0
            total_kcal += nutrition.get("kcal", 0) * factor
            total_protein += nutrition.get("protein", 0) * factor
            total_carbs += nutrition.get("carbs", 0) * factor
            total_fat += nutrition.get("fat", 0) * factor
        
        # Add 25% variance for uncertainty
        variance = 0.25
        
        return {
            "kcal": (total_kcal * (1 - variance), total_kcal * (1 + variance)),
            "protein": (total_protein * (1 - variance), total_protein * (1 + variance)),
            "carbs": (total_carbs * (1 - variance), total_carbs * (1 + variance)),
            "fat": (total_fat * (1 - variance), total_fat * (1 + variance)),
        }

