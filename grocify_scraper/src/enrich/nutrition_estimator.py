"""Nutrition value estimation"""

from typing import Dict, Any, Optional
import logging
from ..models import NutritionRange, Nutrition

logger = logging.getLogger(__name__)


# Category-based nutrition estimates (per 100g)
CATEGORY_NUTRITION = {
    "produce": {"kcal": (20, 50), "protein": (0.5, 2), "carbs": (3, 10), "fat": (0, 0.5)},
    "meat": {"kcal": (150, 250), "protein": (15, 25), "carbs": (0, 2), "fat": (5, 20)},
    "dairy": {"kcal": (50, 150), "protein": (3, 10), "carbs": (3, 5), "fat": (1, 10)},
    "pantry": {"kcal": (300, 500), "protein": (5, 15), "carbs": (50, 80), "fat": (1, 10)},
    "frozen": {"kcal": (100, 300), "protein": (5, 15), "carbs": (10, 40), "fat": (2, 15)},
    "drinks": {"kcal": (0, 50), "protein": (0, 1), "carbs": (0, 12), "fat": (0, 0)},
    "snacks": {"kcal": (400, 600), "protein": (5, 10), "carbs": (40, 60), "fat": (15, 35)},
}


class NutritionEstimator:
    """Estimate nutrition values"""
    
    @staticmethod
    def estimate(offer: Any, servings: int = 2) -> Nutrition:
        """
        Estimate nutrition for a recipe using offers.
        
        Args:
            offer: Offer object (for category)
            servings: Number of servings
            
        Returns:
            Nutrition object with ranges
        """
        category = offer.category or "other"
        base_nutrition = CATEGORY_NUTRITION.get(category, CATEGORY_NUTRITION["pantry"])
        
        # Estimate per serving (assuming ~400-600g total)
        total_weight = 500  # grams
        
        kcal_min = (base_nutrition["kcal"][0] * total_weight / 100) / servings
        kcal_max = (base_nutrition["kcal"][1] * total_weight / 100) / servings
        
        protein_min = (base_nutrition["protein"][0] * total_weight / 100) / servings
        protein_max = (base_nutrition["protein"][1] * total_weight / 100) / servings
        
        carbs_min = (base_nutrition["carbs"][0] * total_weight / 100) / servings
        carbs_max = (base_nutrition["carbs"][1] * total_weight / 100) / servings
        
        fat_min = (base_nutrition["fat"][0] * total_weight / 100) / servings
        fat_max = (base_nutrition["fat"][1] * total_weight / 100) / servings
        
        # Add 25% variance (max allowed)
        variance = 0.25
        kcal_range = NutritionRange(
            min=max(0, int(kcal_min * (1 - variance))),
            max=int(kcal_max * (1 + variance)),
        )
        protein_range = NutritionRange(
            min=max(0, protein_min * (1 - variance)),
            max=protein_max * (1 + variance),
        )
        carbs_range = NutritionRange(
            min=max(0, carbs_min * (1 - variance)),
            max=carbs_max * (1 + variance),
        )
        fat_range = NutritionRange(
            min=max(0, fat_min * (1 - variance)),
            max=fat_max * (1 + variance),
        )
        
        # Ensure ranges are not too wide (max 25% variance)
        if kcal_range.max - kcal_range.min > kcal_range.min * 0.5:
            # Too wide, tighten
            mid = (kcal_range.min + kcal_range.max) / 2
            kcal_range = NutritionRange(
                min=max(0, int(mid * 0.75)),
                max=int(mid * 1.25),
            )
        
        return Nutrition(
            kcal=kcal_range,
            protein_g=protein_range,
            carbs_g=carbs_range,
            fat_g=fat_range,
        )
    
    @staticmethod
    def estimate_simple(num_ingredients: int, servings: int = 2) -> Nutrition:
        """Estimate nutrition for simple pantry recipes"""
        # Simple estimate: ~300-500 kcal per serving for basic recipes
        kcal_range = NutritionRange(
            min=250,
            max=600,
        )
        protein_range = NutritionRange(
            min=5,
            max=25,
        )
        carbs_range = NutritionRange(
            min=30,
            max=80,
        )
        fat_range = NutritionRange(
            min=5,
            max=25,
        )
        
        return Nutrition(
            kcal=kcal_range,
            protein_g=protein_range,
            carbs_g=carbs_range,
            fat_g=fat_range,
        )

