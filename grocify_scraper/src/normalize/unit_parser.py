"""Unit parsing and normalization"""

import re
import logging
from typing import Optional, Dict, Any
from ..models import Quantity

logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)


class UnitParser:
    """Parse and normalize units"""
    
    UNIT_MAPPING = {
        "g": "g",
        "gramm": "g",
        "gram": "g",
        "kg": "kg",
        "kilogramm": "kg",
        "kilogram": "kg",
        "ml": "ml",
        "milliliter": "ml",
        "millilitre": "ml",
        "l": "l",
        "liter": "l",
        "litre": "l",
        "stück": "pcs",
        "stk": "pcs",
        "pcs": "pcs",
        "piece": "pcs",
        "pieces": "pcs",
    }
    
    @staticmethod
    def parse_quantity(raw_quantity: Dict[str, Any], title: str) -> Quantity:
        """
        Parse quantity from raw data or title.
        
        Args:
            raw_quantity: Raw quantity dict
            title: Product title
            
        Returns:
            Quantity object
        """
        # Try raw quantity first
        if raw_quantity.get("value") and raw_quantity.get("unit"):
            unit = UnitParser._normalize_unit(raw_quantity["unit"])
            return Quantity(
                value=float(raw_quantity["value"]),
                unit=unit,
            )
        
        # Extract from title
        return UnitParser._extract_from_title(title)
    
    @staticmethod
    def _extract_from_title(title: str) -> Quantity:
        """Extract quantity from title"""
        title_lower = title.lower()
        
        # Patterns: "500g", "1kg", "250ml", "2 Stück"
        patterns = [
            (r'(\d+)\s*g\b', 'g'),
            (r'(\d+)\s*kg\b', 'kg'),
            (r'(\d+)\s*ml\b', 'ml'),
            (r'(\d+)\s*l\b', 'l'),
            (r'(\d+)\s*stück\b', 'pcs'),
            (r'(\d+)\s*stk\b', 'pcs'),
        ]
        
        for pattern, unit in patterns:
            match = re.search(pattern, title_lower)
            if match:
                return Quantity(
                    value=float(match.group(1)),
                    unit=unit,
                )
        
        return Quantity()
    
    @staticmethod
    def _normalize_unit(unit: str) -> Optional[str]:
        """Normalize unit string"""
        unit_lower = unit.lower().strip()
        return UnitParser.UNIT_MAPPING.get(unit_lower, unit_lower)

