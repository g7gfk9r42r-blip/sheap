"""
Nutrition data providers (APIs).
"""

from typing import Protocol, Optional, Dict, Any, List


class NutritionProvider(Protocol):
    """
    Protocol for nutrition data providers.
    """
    
    def search(self, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """
        Search for food items matching the query.
        
        Args:
            query: Search query (ingredient name)
            limit: Maximum number of results
        
        Returns:
            List of matches with nutrition data and metadata
        """
        ...
    
    def get_by_id(self, food_id: str) -> Optional[Dict[str, Any]]:
        """
        Get food item by ID.
        
        Args:
            food_id: Provider-specific food ID
        
        Returns:
            Nutrition data or None
        """
        ...

