"""
Nutrition Range Calculator

Calculates min/max/avg ranges for nutrition values based on multiple sources.
Provides more honest estimates when exact product match isn't available.
"""

from typing import List, Dict, Any, Optional
import statistics


class NutritionRange:
    """
    Represents a range of nutrition values.
    """
    
    def __init__(
        self,
        values: List[float],
        source_count: int = 0,
        sources: Optional[List[str]] = None
    ):
        """
        Initialize nutrition range from multiple values.
        
        Args:
            values: List of nutrition values from different sources
            source_count: Number of sources consulted
            sources: Optional list of source names
        """
        if not values:
            self.min = None
            self.max = None
            self.avg = None
            self.median = None
            self.variance = "unknown"
            self.confidence = "none"
        else:
            self.min = round(min(values), 1)
            self.max = round(max(values), 1)
            self.avg = round(statistics.mean(values), 1)
            self.median = round(statistics.median(values), 1)
            self.variance = self._calculate_variance_level(values)
            self.confidence = self._calculate_confidence(values, source_count)
        
        self.source_count = source_count
        self.sources = sources or []
    
    def _calculate_variance_level(self, values: List[float]) -> str:
        """
        Calculate variance level (low/medium/high).
        
        Args:
            values: List of values
        
        Returns:
            "low", "medium", or "high"
        """
        if len(values) < 2:
            return "unknown"
        
        avg = statistics.mean(values)
        if avg == 0:
            return "unknown"
        
        # Calculate coefficient of variation (CV)
        stdev = statistics.stdev(values)
        cv = (stdev / avg) * 100  # Percentage
        
        if cv < 10:
            return "low"      # <10% variation
        elif cv < 25:
            return "medium"   # 10-25% variation
        else:
            return "high"     # >25% variation
    
    def _calculate_confidence(self, values: List[float], source_count: int) -> str:
        """
        Calculate confidence level based on variance and source count.
        
        Args:
            values: List of values
            source_count: Number of sources
        
        Returns:
            "high", "medium", or "low"
        """
        if len(values) == 0:
            return "none"
        
        variance = self._calculate_variance_level(values)
        
        # High confidence: low variance + multiple sources
        if variance == "low" and source_count >= 3:
            return "high"
        
        # Medium confidence: medium variance or 2+ sources
        if variance in ["low", "medium"] and source_count >= 2:
            return "medium"
        
        # Low confidence: high variance or single source
        return "low"
    
    def to_dict(self) -> Dict[str, Any]:
        """Export as dictionary."""
        if self.min is None:
            return {
                "min": None,
                "max": None,
                "avg": None,
                "median": None,
                "variance": "unknown",
                "confidence": "none",
                "source_count": 0
            }
        
        return {
            "min": self.min,
            "max": self.max,
            "avg": self.avg,
            "median": self.median,
            "variance": self.variance,
            "confidence": self.confidence,
            "source_count": self.source_count
        }


class NutritionRangeCalculator:
    """
    Calculates nutrition ranges from multiple API results.
    """
    
    @staticmethod
    def calculate_from_results(
        results: List[Dict[str, Any]],
        min_confidence: float = 0.3
    ) -> Dict[str, NutritionRange]:
        """
        Calculate nutrition ranges from multiple API results.
        
        Args:
            results: List of nutrition results from providers
            min_confidence: Minimum confidence to include result
        
        Returns:
            Dict with NutritionRange for each nutrient
        """
        # Filter by confidence
        valid_results = [
            r for r in results 
            if r.get("confidence", 0) >= min_confidence
        ]
        
        if not valid_results:
            return {
                "kcal": NutritionRange([]),
                "protein_g": NutritionRange([]),
                "fat_g": NutritionRange([]),
                "carbs_g": NutritionRange([])
            }
        
        # Collect values for each nutrient
        kcal_values = []
        protein_values = []
        fat_values = []
        carbs_values = []
        sources = []
        
        for result in valid_results:
            nutrition = result.get("nutrition_per_100g", {})
            
            if nutrition.get("kcal"):
                kcal_values.append(nutrition["kcal"])
            if nutrition.get("protein_g"):
                protein_values.append(nutrition["protein_g"])
            if nutrition.get("fat_g"):
                fat_values.append(nutrition["fat_g"])
            if nutrition.get("carbs_g"):
                carbs_values.append(nutrition["carbs_g"])
            
            source = f"{result.get('provider')}:{result.get('name', 'unknown')}"
            sources.append(source)
        
        return {
            "kcal": NutritionRange(kcal_values, len(valid_results), sources),
            "protein_g": NutritionRange(protein_values, len(valid_results), sources),
            "fat_g": NutritionRange(fat_values, len(valid_results), sources),
            "carbs_g": NutritionRange(carbs_values, len(valid_results), sources)
        }
    
    @staticmethod
    def scale_to_amount(
        ranges: Dict[str, NutritionRange],
        amount_g: float
    ) -> Dict[str, NutritionRange]:
        """
        Scale ranges from per-100g to actual amount.
        
        Args:
            ranges: Ranges per 100g
            amount_g: Amount in grams
        
        Returns:
            Scaled ranges
        """
        factor = amount_g / 100.0
        
        scaled = {}
        for nutrient, range_obj in ranges.items():
            if range_obj.min is not None:
                scaled_values = [
                    range_obj.min * factor,
                    range_obj.max * factor,
                    range_obj.avg * factor
                ]
                scaled[nutrient] = NutritionRange(
                    scaled_values,
                    range_obj.source_count,
                    range_obj.sources
                )
            else:
                scaled[nutrient] = NutritionRange([])
        
        return scaled
    
    @staticmethod
    def aggregate_recipe_ranges(
        ingredient_ranges: List[Dict[str, NutritionRange]]
    ) -> Dict[str, NutritionRange]:
        """
        Aggregate ingredient ranges to recipe totals.
        
        Args:
            ingredient_ranges: List of range dicts per ingredient
        
        Returns:
            Recipe-level ranges
        """
        # Sum min/max/avg across ingredients
        kcal_mins = []
        kcal_maxs = []
        kcal_avgs = []
        
        protein_mins = []
        protein_maxs = []
        protein_avgs = []
        
        fat_mins = []
        fat_maxs = []
        fat_avgs = []
        
        carbs_mins = []
        carbs_maxs = []
        carbs_avgs = []
        
        total_sources = 0
        
        for ranges in ingredient_ranges:
            kcal_range = ranges.get("kcal")
            if kcal_range and kcal_range.min is not None:
                kcal_mins.append(kcal_range.min)
                kcal_maxs.append(kcal_range.max)
                kcal_avgs.append(kcal_range.avg)
                total_sources += kcal_range.source_count
            
            protein_range = ranges.get("protein_g")
            if protein_range and protein_range.min is not None:
                protein_mins.append(protein_range.min)
                protein_maxs.append(protein_range.max)
                protein_avgs.append(protein_range.avg)
            
            fat_range = ranges.get("fat_g")
            if fat_range and fat_range.min is not None:
                fat_mins.append(fat_range.min)
                fat_maxs.append(fat_range.max)
                fat_avgs.append(fat_range.avg)
            
            carbs_range = ranges.get("carbs_g")
            if carbs_range and carbs_range.min is not None:
                carbs_mins.append(carbs_range.min)
                carbs_maxs.append(carbs_range.max)
                carbs_avgs.append(carbs_range.avg)
        
        # Create ranges from summed values
        return {
            "kcal": NutritionRange(
                [sum(kcal_mins), sum(kcal_maxs), sum(kcal_avgs)] if kcal_mins else [],
                total_sources
            ),
            "protein_g": NutritionRange(
                [sum(protein_mins), sum(protein_maxs), sum(protein_avgs)] if protein_mins else []
            ),
            "fat_g": NutritionRange(
                [sum(fat_mins), sum(fat_maxs), sum(fat_avgs)] if fat_mins else []
            ),
            "carbs_g": NutritionRange(
                [sum(carbs_mins), sum(carbs_maxs), sum(carbs_avgs)] if carbs_mins else []
            )
        }


def format_range_for_display(range_obj: NutritionRange, unit: str = "") -> str:
    """
    Format range for human-readable display.
    
    Args:
        range_obj: NutritionRange object
        unit: Unit string (e.g., "kcal", "g")
    
    Returns:
        Formatted string
    """
    if range_obj.min is None:
        return f"? {unit}"
    
    if range_obj.min == range_obj.max:
        return f"{range_obj.avg:.0f}{unit}"
    
    if range_obj.variance == "low":
        # Small variance, show avg ± range
        variance_val = (range_obj.max - range_obj.min) / 2
        return f"{range_obj.avg:.0f}±{variance_val:.0f}{unit}"
    else:
        # Larger variance, show range
        return f"{range_obj.min:.0f}-{range_obj.max:.0f}{unit}"

