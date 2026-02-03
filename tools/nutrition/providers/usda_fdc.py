"""
USDA FoodData Central API provider for generic foods.
"""

import requests
import time
import os
from typing import Dict, Any, List, Optional


class USDAFoodDataCentralProvider:
    """
    Provider for USDA FoodData Central API.
    Requires API key (free): https://fdc.nal.usda.gov/api-key-signup.html
    """
    
    BASE_URL = "https://api.nal.usda.gov/fdc/v1"
    
    # Rate limiting (conservative)
    MIN_REQUEST_INTERVAL = 0.5  # seconds between requests
    
    def __init__(self, api_key: Optional[str] = None):
        """
        Initialize USDA FDC provider.
        
        Args:
            api_key: USDA FDC API key (or set USDA_FDC_API_KEY env var)
        """
        self.api_key = api_key or os.environ.get("USDA_FDC_API_KEY")
        if not self.api_key:
            print("Warning: USDA_FDC_API_KEY not set. USDA provider will be skipped.")
            print("Get a free key at: https://fdc.nal.usda.gov/api-key-signup.html")
        
        self._last_request_time = 0.0
    
    def _rate_limit(self):
        """Ensure we don't exceed rate limits."""
        elapsed = time.time() - self._last_request_time
        if elapsed < self.MIN_REQUEST_INTERVAL:
            time.sleep(self.MIN_REQUEST_INTERVAL - elapsed)
        self._last_request_time = time.time()
    
    def is_available(self) -> bool:
        """Check if API key is available."""
        return bool(self.api_key)
    
    def search(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Search USDA FDC for foods matching query.
        
        Args:
            query: Search query (food name)
            limit: Maximum results (default 5)
        
        Returns:
            List of standardized nutrition data dicts
        """
        if not self.is_available():
            return []
        
        self._rate_limit()
        
        try:
            url = f"{self.BASE_URL}/foods/search"
            params = {
                "api_key": self.api_key,
                "query": query,
                "pageSize": limit,
                "dataType": ["Foundation", "SR Legacy"],  # Most complete data
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            foods = data.get("foods", [])
            
            results = []
            for food in foods:
                parsed = self._parse_food(food, query)
                if parsed:
                    results.append(parsed)
            
            return results
        
        except Exception as e:
            print(f"Warning: USDA search failed for '{query}': {e}")
            return []
    
    def get_by_id(self, fdc_id: str) -> Optional[Dict[str, Any]]:
        """
        Get food by FDC ID.
        
        Args:
            fdc_id: FDC food ID
        
        Returns:
            Standardized nutrition data or None
        """
        if not self.is_available():
            return None
        
        self._rate_limit()
        
        try:
            url = f"{self.BASE_URL}/food/{fdc_id}"
            params = {"api_key": self.api_key}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            food = response.json()
            return self._parse_food(food, None)
        
        except Exception as e:
            print(f"Warning: USDA get_by_id failed for '{fdc_id}': {e}")
            return None
    
    def _parse_food(self, food: Dict[str, Any], query: Optional[str]) -> Optional[Dict[str, Any]]:
        """
        Parse USDA food into standardized format.
        
        Args:
            food: Raw USDA food data
            query: Original search query (for confidence scoring)
        
        Returns:
            Standardized nutrition dict or None if insufficient data
        """
        # Extract nutrients
        nutrients = food.get("foodNutrients", [])
        nutrient_map = {}
        
        for nutrient in nutrients:
            nutrient_id = nutrient.get("nutrientId")
            value = nutrient.get("value")
            
            if nutrient_id and value is not None:
                nutrient_map[nutrient_id] = value
        
        # Standard nutrient IDs (per 100g)
        # 1008 = Energy (kcal)
        # 1003 = Protein
        # 1004 = Total lipid (fat)
        # 1005 = Carbohydrate
        
        kcal = nutrient_map.get(1008)
        protein = nutrient_map.get(1003)
        fat = nutrient_map.get(1004)
        carbs = nutrient_map.get(1005)
        
        # Must have at least calories
        if not kcal or kcal <= 0:
            return None
        
        description = food.get("description", "")
        
        # Calculate confidence
        confidence = self._calculate_confidence(description, query) if query else 0.5
        
        return {
            "provider": "usda_fdc",
            "id": str(food.get("fdcId")),
            "name": description,
            "confidence": confidence,
            "nutrition_per_100g": {
                "kcal": round(kcal, 1),
                "protein_g": round(protein, 1) if protein else None,
                "fat_g": round(fat, 1) if fat else None,
                "carbs_g": round(carbs, 1) if carbs else None,
            },
            "metadata": {
                "data_type": food.get("dataType"),
                "food_category": food.get("foodCategory", {}).get("description"),
            }
        }
    
    def _calculate_confidence(self, food_name: str, query: str) -> float:
        """
        Calculate confidence score based on name similarity.
        
        Args:
            food_name: Food name from API
            query: Search query
        
        Returns:
            Confidence score (0.0 to 1.0)
        """
        if not food_name or not query:
            return 0.0
        
        food_lower = food_name.lower()
        query_lower = query.lower()
        
        # Exact match
        if query_lower == food_lower:
            return 1.0
        
        # Contains query
        if query_lower in food_lower:
            return 0.9
        
        # Word overlap
        query_words = set(query_lower.split())
        food_words = set(food_lower.split())
        
        if not query_words or not food_words:
            return 0.0
        
        overlap = len(query_words & food_words)
        total = len(query_words | food_words)
        
        jaccard = overlap / total if total > 0 else 0.0
        
        # Boost for key word matches
        key_words_match = any(word in food_lower for word in query_words if len(word) > 3)
        if key_words_match:
            jaccard = min(1.0, jaccard + 0.2)
        
        return max(0.3, jaccard)  # Minimum 0.3 if we got a result

