"""Brand resolution and confidence scoring"""

from typing import Optional, Literal
import logging

logger = logging.getLogger(__name__)

# Common brand patterns (uppercase, known brands)
KNOWN_BRANDS = {
    "REWE", "EDEKA", "ALDI", "LIDL", "KAUFLAND", "NETTO", "PENNY", "NORMA",
    "MILKA", "NUTELLA", "COCA COLA", "PEPSI", "MÜLLER", "DANONE", "NESTLE",
    "WEIHENSTEPHAN", "MEGGLE", "BRESSO", "LEERDAMMER", "SONNENTOR", "BIOLUST",
}


class BrandResolver:
    """Resolve and score brand confidence"""
    
    @staticmethod
    def resolve_brand(raw_brand: Optional[str], title: str) -> tuple[Optional[str], Literal["high", "medium", "low"]]:
        """
        Resolve brand from raw input.
        
        Args:
            raw_brand: Raw brand string
            title: Product title
            
        Returns:
            Tuple of (brand, confidence)
        """
        # If we have a raw brand, use it
        if raw_brand:
            cleaned = raw_brand.strip().upper()
            if cleaned:
                # Check if it's a known brand
                if cleaned in KNOWN_BRANDS:
                    return cleaned, "high"
                # Check if it matches a known brand (case-insensitive)
                for known in KNOWN_BRANDS:
                    if known.lower() in cleaned.lower() or cleaned.lower() in known.lower():
                        return known, "high"
                # Unknown but provided
                return cleaned, "medium"
        
        # Try to extract from title
        title_upper = title.upper()
        for brand in KNOWN_BRANDS:
            if brand in title_upper:
                return brand, "medium"
        
        # Check for uppercase words at start of title
        words = title.split()
        if words and words[0].isupper() and len(words[0]) >= 2:
            potential_brand = words[0].upper()
            if 2 <= len(potential_brand) <= 20:
                return potential_brand, "low"
        
        return None, "low"
    
    @staticmethod
    def should_flag_missing_brand(brand: Optional[str], confidence: str, category: Optional[str]) -> bool:
        """Determine if missing brand should be flagged"""
        # Some categories don't need brands (produce, generic items)
        no_brand_categories = ["produce", "vegetables", "fruits"]
        
        if category and category.lower() in no_brand_categories:
            return False
        
        return brand is None or confidence == "low"

