"""USDA FoodData Central API client"""
import requests
import os
from typing import Optional, Dict, List
from ..utils.retry import retry_on_failure


class USDAClient:
    """USDA FoodData Central API client"""
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("USDA_API_KEY")
        self.base_url = "https://api.nal.usda.gov/fdc/v1"
    
    def is_available(self) -> bool:
        return bool(self.api_key)
    
    @retry_on_failure(max_retries=2, delay=1.0)
    def search_food(self, query: str, limit: int = 5) -> List[Dict]:
        """
        Search for food
        
        Returns list of {name, kcal_per_100g, protein_g, fat_g, carbs_g, source}
        """
        if not self.is_available():
            return []
        
        try:
            response = requests.get(
                f"{self.base_url}/foods/search",
                params={
                    "api_key": self.api_key,
                    "query": query,
                    "pageSize": limit,
                    "dataType": ["Foundation", "SR Legacy"]
                },
                timeout=10
            )
            response.raise_for_status()
            
            data = response.json()
            foods = data.get("foods", [])
            
            results = []
            for food in foods:
                parsed = self._parse_food(food)
                if parsed:
                    results.append(parsed)
            
            return results
        
        except Exception as e:
            print(f"USDA search failed for '{query}': {e}")
            return []
    
    def _parse_food(self, food: Dict) -> Optional[Dict]:
        """Parse USDA food item"""
        nutrients = food.get("foodNutrients", [])
        
        # Extract nutrient IDs
        nutrient_map = {}
        for nutrient in nutrients:
            nutrient_id = nutrient.get("nutrientId")
            value = nutrient.get("value")
            if nutrient_id and value is not None:
                nutrient_map[nutrient_id] = value
        
        # Standard IDs (per 100g)
        kcal = nutrient_map.get(1008)  # Energy (kcal)
        protein = nutrient_map.get(1003)  # Protein
        fat = nutrient_map.get(1004)  # Total lipid (fat)
        carbs = nutrient_map.get(1005)  # Carbohydrate
        
        if not kcal or kcal <= 0:
            return None
        
        return {
            "name": food.get("description", ""),
            "kcal_per_100g": round(kcal, 1),
            "protein_g": round(protein, 1) if protein else None,
            "fat_g": round(fat, 1) if fat else None,
            "carbs_g": round(carbs, 1) if carbs else None,
            "source": "usda",
            "source_id": str(food.get("fdcId", ""))
        }

