"""Price parsing and normalization"""

from typing import List, Dict, Any, Optional
import logging
from ..models import PriceTier, Condition, ReferencePrice

logger = logging.getLogger(__name__)


class PriceParser:
    """Parse and normalize prices"""
    
    @staticmethod
    def normalize_prices(raw_prices: List[Dict[str, Any]]) -> tuple[List[PriceTier], Optional[ReferencePrice]]:
        """
        Normalize raw prices into PriceTier objects.
        
        Args:
            raw_prices: List of raw price dictionaries
            
        Returns:
            Tuple of (price_tiers, reference_price)
        """
        price_tiers = []
        reference_price = None
        
        for raw_price in raw_prices:
            amount = raw_price.get("amount")
            if amount is None or amount <= 0:
                continue
            
            is_reference = raw_price.get("is_reference", False)
            condition_dict = raw_price.get("condition", {})
            
            if is_reference:
                # This is a reference price (UVP, etc.)
                ref_type = condition_dict.get("type") or "UVP"
                reference_price = ReferencePrice(
                    amount=amount,
                    currency="EUR",
                    type=ref_type,
                )
            else:
                # This is a regular price tier
                condition = Condition(
                    type=condition_dict.get("type", "standard"),
                    label=condition_dict.get("label"),
                    requires_card=condition_dict.get("requires_card", False),
                    requires_app=condition_dict.get("requires_app", False),
                    min_qty=condition_dict.get("min_qty"),
                    notes=condition_dict.get("notes"),
                )
                
                price_tier = PriceTier(
                    amount=amount,
                    currency="EUR",
                    condition=condition,
                )
                price_tiers.append(price_tier)
        
        # Ensure standard price is first
        standard_tiers = [pt for pt in price_tiers if pt.condition.type == "standard"]
        other_tiers = [pt for pt in price_tiers if pt.condition.type != "standard"]
        price_tiers = standard_tiers + other_tiers
        
        return price_tiers, reference_price
    
    @staticmethod
    def validate_price_structure(price_tiers: List[PriceTier]) -> tuple[bool, List[str]]:
        """
        Validate price structure.
        
        Returns:
            Tuple of (is_valid, flags)
        """
        flags = []
        
        # Check for standard price
        has_standard = any(pt.condition.type == "standard" for pt in price_tiers)
        has_loyalty = any(pt.condition.type == "loyalty" for pt in price_tiers)
        
        if not has_standard and has_loyalty:
            flags.append("LOYALTY_WITHOUT_STANDARD")
        
        # Check for multiple standard prices
        standard_count = sum(1 for pt in price_tiers if pt.condition.type == "standard")
        if standard_count > 1:
            flags.append("MULTI_PRICE_UNCLEAR")
        
        # Check for ambiguous loyalty prices
        loyalty_tiers = [pt for pt in price_tiers if pt.condition.type == "loyalty"]
        if len(loyalty_tiers) > 1:
            # Check if they have clear labels
            labels = [pt.condition.label for pt in loyalty_tiers if pt.condition.label]
            if len(set(labels)) < len(loyalty_tiers):
                flags.append("AMBIGUOUS_PRICE")
        
        return len(flags) == 0, flags

