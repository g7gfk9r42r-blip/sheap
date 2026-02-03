"""
Open Food Facts API provider for branded/packaged foods.
"""

import requests
import time
from typing import Dict, Any, List, Optional
from urllib.parse import quote


class OpenFoodFactsProvider:
    """
    Provider for Open Food Facts API.
    Free, no API key needed, but respect rate limits.
    """
    
    BASE_URL = "https://world.openfoodfacts.org/api/v2"
    USER_AGENT = "NutritionEnrichmentPipeline/1.0 (Recipe App)"
    
    # Rate limiting
    MIN_REQUEST_INTERVAL = 1.0  # seconds between requests
    
    def __init__(self):
        self._last_request_time = 0.0
    
    def _rate_limit(self):
        """Ensure we don't exceed rate limits."""
        elapsed = time.time() - self._last_request_time
        if elapsed < self.MIN_REQUEST_INTERVAL:
            time.sleep(self.MIN_REQUEST_INTERVAL - elapsed)
        self._last_request_time = time.time()
    
    def search(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Search Open Food Facts for products matching query.
        
        Args:
            query: Search query (product/ingredient name)
            limit: Maximum results (default 5)
        
        Returns:
            List of standardized nutrition data dicts
        """
        self._rate_limit()
        
        try:
            # Search endpoint
            url = f"{self.BASE_URL}/search"
            params = {
                "search_terms": query,
                "page_size": limit,
                "fields": "product_name,brands,nutriments,code,nutriscore_grade"
            }
            
            headers = {"User-Agent": self.USER_AGENT}
            
            response = requests.get(url, params=params, headers=headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            products = data.get("products", [])
            
            results = []
            for product in products:
                parsed = self._parse_product(product, query)
                if parsed:
                    results.append(parsed)
            
            return results
        
        except Exception as e:
            print(f"Warning: OFF search failed for '{query}': {e}")
            return []
    
    def get_by_id(self, barcode: str) -> Optional[Dict[str, Any]]:
        """
        Get product by barcode.
        
        Args:
            barcode: Product barcode
        
        Returns:
            Standardized nutrition data or None
        """
        self._rate_limit()
        
        try:
            url = f"{self.BASE_URL}/product/{barcode}"
            headers = {"User-Agent": self.USER_AGENT}
            
            response = requests.get(url, headers=headers, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            
            if data.get("status") == 1 and "product" in data:
                return self._parse_product(data["product"], None)
            
            return None
        
        except Exception as e:
            print(f"Warning: OFF get_by_id failed for '{barcode}': {e}")
            return None
    
    def _parse_product(self, product: Dict[str, Any], query: Optional[str]) -> Optional[Dict[str, Any]]:
        """
        Parse OFF product into standardized format.
        
        Args:
            product: Raw OFF product data
            query: Original search query (for confidence scoring)
        
        Returns:
            Standardized nutrition dict or None if insufficient data
        """
        nutriments = product.get("nutriments", {})
        
        # Extract per 100g values
        kcal = nutriments.get("energy-kcal_100g") or nutriments.get("energy_100g")
        if kcal and isinstance(kcal, (int, float)) and kcal > 500:
            # energy_100g might be in kJ, convert to kcal
            kcal = kcal / 4.184 if kcal > 1000 else kcal
        
        protein = nutriments.get("proteins_100g")
        fat = nutriments.get("fat_100g")
        carbs = nutriments.get("carbohydrates_100g")
        
        # Must have at least calories
        if not kcal or kcal <= 0:
            return None
        
        product_name = product.get("product_name", "")
        brands = product.get("brands", "")
        full_name = f"{brands} {product_name}".strip() if brands else product_name
        
        # Calculate confidence
        confidence = self._calculate_confidence(full_name, query) if query else 0.5
        
        return {
            "provider": "openfoodfacts",
            "id": product.get("code"),
            "name": full_name,
            "confidence": confidence,
            "nutrition_per_100g": {
                "kcal": round(kcal, 1),
                "protein_g": round(protein, 1) if protein else None,
                "fat_g": round(fat, 1) if fat else None,
                "carbs_g": round(carbs, 1) if carbs else None,
            },
            "metadata": {
                "brands": brands,
                "product_name": product_name,
                "nutriscore": product.get("nutriscore_grade"),
            }
        }
    
    def _calculate_confidence(self, product_name: str, query: str) -> float:
        """
        Calculate confidence score based on name similarity.
        
        Args:
            product_name: Product name from API
            query: Search query
        
        Returns:
            Confidence score (0.0 to 1.0)
        """
        if not product_name or not query:
            return 0.0
        
        product_lower = product_name.lower()
        query_lower = query.lower()
        
        # Exact match
        if query_lower == product_lower:
            return 1.0
        
        # Contains query
        if query_lower in product_lower:
            return 0.9
        
        # Word overlap
        query_words = set(query_lower.split())
        product_words = set(product_lower.split())
        
        if not query_words or not product_words:
            return 0.0
        
        overlap = len(query_words & product_words)
        total = len(query_words | product_words)
        
        jaccard = overlap / total if total > 0 else 0.0
        
        return max(0.3, jaccard)  # Minimum 0.3 if we got a result

