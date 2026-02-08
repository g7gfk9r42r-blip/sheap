"""Check ingredient availability"""

from typing import List, Dict, Any, Optional
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


# Grundsortiment - immer verfügbare Zutaten
BASIC_PANTRY = {
    "Salz": {"alwaysAvailable": True, "category": "spice"},
    "Pfeffer": {"alwaysAvailable": True, "category": "spice"},
    "Olivenöl": {"alwaysAvailable": True, "category": "fat"},
    "Butter": {"alwaysAvailable": True, "category": "fat"},
    "Zwiebeln": {"alwaysAvailable": True, "category": "vegetable"},
    "Knoblauch": {"alwaysAvailable": True, "category": "spice"},
    "Wasser": {"alwaysAvailable": True, "category": "liquid"},
    "Milch": {"alwaysAvailable": True, "category": "dairy"},
    "Mehl": {"alwaysAvailable": True, "category": "pantry"},
    "Zucker": {"alwaysAvailable": True, "category": "pantry"},
    "Essig": {"alwaysAvailable": True, "category": "pantry"},
    "Brühe": {"alwaysAvailable": True, "category": "pantry"},
    "Paprika": {"alwaysAvailable": True, "category": "spice"},
    "Oregano": {"alwaysAvailable": True, "category": "spice"},
    "Basilikum": {"alwaysAvailable": True, "category": "spice"},
}


class AvailabilityChecker:
    """Check ingredient availability"""
    
    def __init__(self, supermarket: str, week_key: str):
        self.supermarket = supermarket
        self.week_key = week_key
        self.offers = []
        self.valid_from = None
        self.valid_to = None
    
    def set_offers(self, offers: List[Dict[str, Any]]):
        """Set offers for availability checking"""
        self.offers = offers
        
        # Extract validity period from offers
        if offers:
            dates = []
            for offer in offers:
                if isinstance(offer, dict):
                    valid_from = offer.get("validFrom")
                    valid_to = offer.get("validTo")
                else:
                    valid_from = getattr(offer, "valid_from", None)
                    valid_to = getattr(offer, "valid_to", None)
                
                if valid_from:
                    dates.append(valid_from)
                if valid_to:
                    dates.append(valid_to)
            
            if dates:
                self.valid_from = min(dates)
                self.valid_to = max(dates)
    
    def check_ingredient(self, ingredient_name: str) -> Dict[str, Any]:
        """
        Check if ingredient is available.
        
        Returns:
            {
                "available": bool,
                "source": "offer"|"pantry"|"unknown",
                "offerId": str|null,
                "validFrom": str|null,
                "validTo": str|null,
            }
        """
        # Normalize name
        normalized_name = self._normalize_name(ingredient_name)
        
        # Check basic pantry
        if normalized_name in BASIC_PANTRY:
            return {
                "available": True,
                "source": "pantry",
                "offerId": None,
                "validFrom": None,
                "validTo": None,
                "alwaysAvailable": True,
            }
        
        # Check offers
        for offer in self.offers:
            offer_name = self._get_offer_name(offer)
            if self._name_match(normalized_name, offer_name):
                return {
                    "available": True,
                    "source": "offer",
                    "offerId": self._get_offer_id(offer),
                    "validFrom": self._get_valid_from(offer),
                    "validTo": self._get_valid_to(offer),
                    "alwaysAvailable": False,
                }
        
        # Unknown - assume available (might be in store)
        return {
            "available": True,
            "source": "unknown",
            "offerId": None,
            "validFrom": None,
            "validTo": None,
            "alwaysAvailable": False,
        }
    
    def _normalize_name(self, name: str) -> str:
        """Normalize ingredient name for matching"""
        return name.lower().strip()
    
    def _get_offer_name(self, offer) -> str:
        """Get offer name"""
        if isinstance(offer, dict):
            return offer.get("name") or offer.get("title", "")
        return getattr(offer, "title", "") or getattr(offer, "name", "")
    
    def _get_offer_id(self, offer) -> str:
        """Get offer ID"""
        if isinstance(offer, dict):
            return offer.get("id", "")
        return getattr(offer, "id", "")
    
    def _get_valid_from(self, offer) -> Optional[str]:
        """Get valid from date"""
        if isinstance(offer, dict):
            return offer.get("validFrom")
        return getattr(offer, "valid_from", None)
    
    def _get_valid_to(self, offer) -> Optional[str]:
        """Get valid to date"""
        if isinstance(offer, dict):
            return offer.get("validTo")
        return getattr(offer, "valid_to", None)
    
    def _name_match(self, name1: str, name2: str) -> bool:
        """Check if names match (fuzzy)"""
        from difflib import SequenceMatcher
        similarity = SequenceMatcher(None, name1, name2).ratio()
        return similarity > 0.7

