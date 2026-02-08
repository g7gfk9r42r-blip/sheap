"""Open Food Facts API client"""
import requests
import time
from typing import Optional, Dict, List
from ..utils.retry import retry_on_failure


class OpenFoodFactsClient:
    """Open Food Facts API client"""
    
    BASE_URL = "https://world.openfoodfacts.org/api/v2"
    USER_AGENT = "GrocifyPipeline/1.0"
    MIN_REQUEST_INTERVAL = 1.0  # seconds
    
    def __init__(self):
        self._last_request_time = 0.0
    
    def _rate_limit(self):
        """Respect rate limits"""
        elapsed = time.time() - self._last_request_time
        if elapsed < self.MIN_REQUEST_INTERVAL:
            time.sleep(self.MIN_REQUEST_INTERVAL - elapsed)
        self._last_request_time = time.time()
    
    @retry_on_failure(max_retries=2, delay=1.0)
    def search_product(self, query: str, limit: int = 5) -> List[Dict]:
        """
        Search for product
        
        Returns list of {name, kcal_per_100g, protein_g, fat_g, carbs_g, source}
        """
        self._rate_limit()
        
        try:
            response = requests.get(
                f"{self.BASE_URL}/search",
                params={
                    "search_terms": query,
                    "page_size": limit,
                    "fields": "product_name,brands,nutriments,code"
                },
                headers={"User-Agent": self.USER_AGENT},
                timeout=10
            )
            response.raise_for_status()
            
            data = response.json()
            products = data.get("products", [])
            
            results = []
            for product in products:
                parsed = self._parse_product(product)
                if parsed:
                    results.append(parsed)
            
            return results
        
        except Exception as e:
            print(f"OFF search failed for '{query}': {e}")
            return []
    
    def _parse_product(self, product: Dict) -> Optional[Dict]:
        """Parse OFF product"""
        nutriments = product.get("nutriments", {})
        
        # Get energy in kcal
        kcal = nutriments.get("energy-kcal_100g")
        if not kcal:
            # Try converting from kJ
            energy_kj = nutriments.get("energy_100g")
            if energy_kj and energy_kj > 100:
                kcal = energy_kj / 4.184
        
        if not kcal or kcal <= 0:
            return None
        
        protein = nutriments.get("proteins_100g")
        fat = nutriments.get("fat_100g")
        carbs = nutriments.get("carbohydrates_100g")
        
        product_name = product.get("product_name", "")
        brands = product.get("brands", "")
        full_name = f"{brands} {product_name}".strip() if brands else product_name
        
        return {
            "name": full_name,
            "kcal_per_100g": round(kcal, 1),
            "protein_g": round(protein, 1) if protein else None,
            "fat_g": round(fat, 1) if fat else None,
            "carbs_g": round(carbs, 1) if carbs else None,
            "source": "openfoodfacts",
            "source_id": product.get("code", "")
        }

