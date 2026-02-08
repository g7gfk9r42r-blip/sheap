"""Image URL resolution"""

from typing import List, Optional
import logging

logger = logging.getLogger(__name__)


# Placeholder image URLs by category
PLACEHOLDER_IMAGES = {
    "produce": "https://via.placeholder.com/400x300/4CAF50/FFFFFF?text=Produce",
    "meat": "https://via.placeholder.com/400x300/E91E63/FFFFFF?text=Meat",
    "dairy": "https://via.placeholder.com/400x300/2196F3/FFFFFF?text=Dairy",
    "pantry": "https://via.placeholder.com/400x300/FF9800/FFFFFF?text=Pantry",
    "frozen": "https://via.placeholder.com/400x300/00BCD4/FFFFFF?text=Frozen",
    "drinks": "https://via.placeholder.com/400x300/9C27B0/FFFFFF?text=Drinks",
    "snacks": "https://via.placeholder.com/400x300/FF5722/FFFFFF?text=Snacks",
    "other": "https://via.placeholder.com/400x300/607D8B/FFFFFF?text=Food",
}


class ImageResolver:
    """Resolve image URLs"""
    
    @staticmethod
    def resolve(offer: Any, offers: List[Any] = None) -> tuple[str, List[str]]:
        """
        Resolve image URLs for offer/recipe.
        
        Args:
            offer: Offer object
            offers: List of all offers (for context)
            
        Returns:
            Tuple of (hero_image_url, images_list)
        """
        # Try to get image from offer source
        hero_url = ""
        images = []
        
        # Check if offer has image URL in source
        if hasattr(offer, 'source') and hasattr(offer.source, 'raw_text'):
            # Could extract image URLs from raw text if available
            pass
        
        # Use placeholder based on category
        category = getattr(offer, 'category', None) or "other"
        hero_url = PLACEHOLDER_IMAGES.get(category, PLACEHOLDER_IMAGES["other"])
        images = [hero_url]
        
        return hero_url, images

