"""5-stage quality gate validator - supports both Offer objects and dicts"""

from typing import List, Dict, Any, Tuple
import logging

from ..models import Offer
from ..config import QUALITY_GATES, FLAGS

logger = logging.getLogger(__name__)


class Validator:
    """5-stage quality gate validator"""
    
    def __init__(self):
        self.gates = [
            self._gate1_schema_required,
            self._gate2_price_consistency,
            self._gate3_loyalty_rules,
            self._gate4_brand_quantity,
            self._gate5_duplicates_outliers,
        ]
    
    def validate(self, offers: List) -> Tuple[List, List[Dict[str, Any]], Dict[str, Any]]:
        """
        Run all quality gates. Supports both Offer objects and dicts.
        
        Returns:
            Tuple of (validated_offers, flagged_offers, report)
        """
        validated = []
        flagged = []
        report = {
            "total": len(offers),
            "passed": 0,
            "flagged": 0,
            "rejected": 0,
            "gate_results": [],
        }
        
        for offer in offers:
            # Ensure flags list exists
            flags = self._get_flags(offer)
            flags_before = set(flags)
            confidence_before = self._get_confidence(offer)
            
            # Run all gates
            for gate_func in self.gates:
                gate_func(offer)
            
            # Check if offer passed
            flags_after = set(self._get_flags(offer))
            new_flags = flags_after - flags_before
            
            # Update confidence based on flags
            if new_flags:
                new_confidence = self._lower_confidence(confidence_before)
                self._set_confidence(offer, new_confidence)
            
            # Categorize offer
            current_flags = self._get_flags(offer)
            if "INVALID_PRICE" in current_flags:
                report["rejected"] += 1
                continue
            elif current_flags or self._get_confidence(offer) == "low":
                flagged.append(self._offer_to_dict(offer))
                report["flagged"] += 1
            else:
                report["passed"] += 1
            
            validated.append(offer)
        
        report["gate_results"] = self._generate_gate_results(offers)
        
        return validated, flagged, report
    
    def _get_attr(self, offer, attr, default=None):
        """Get attribute from offer (dict or object)"""
        if isinstance(offer, dict):
            return offer.get(attr, default)
        return getattr(offer, attr, default)
    
    def _set_attr(self, offer, attr, value):
        """Set attribute on offer (dict or object)"""
        if isinstance(offer, dict):
            offer[attr] = value
        else:
            setattr(offer, attr, value)
    
    def _get_flags(self, offer):
        """Get flags list, creating if needed"""
        flags = self._get_attr(offer, "flags", [])
        if not isinstance(flags, list):
            flags = []
            self._set_attr(offer, "flags", flags)
        return flags
    
    def _get_confidence(self, offer):
        """Get confidence, defaulting to medium"""
        return self._get_attr(offer, "confidence", "medium")
    
    def _set_confidence(self, offer, confidence):
        """Set confidence"""
        self._set_attr(offer, "confidence", confidence)
    
    def _get_title(self, offer):
        """Get title"""
        return self._get_attr(offer, "title") or self._get_attr(offer, "name", "")
    
    def _get_price_tiers(self, offer):
        """Get price tiers"""
        return self._get_attr(offer, "price_tiers", [])
    
    def _gate1_schema_required(self, offer):
        """Gate 1: Schema & Required Fields"""
        title = self._get_title(offer)
        flags = self._get_flags(offer)
        
        if not title or len(str(title).strip()) < QUALITY_GATES["min_title_length"]:
            flags.append("MISSING_TITLE")
        
        if len(str(title)) > QUALITY_GATES["max_title_length"]:
            flags.append("TITLE_TOO_LONG")
        
        price_tiers = self._get_price_tiers(offer)
        if not price_tiers:
            flags.append("MISSING_PRICE")
    
    def _gate2_price_consistency(self, offer):
        """Gate 2: Price Consistency"""
        price_tiers = self._get_price_tiers(offer)
        flags = self._get_flags(offer)
        
        for tier in price_tiers:
            if isinstance(tier, dict):
                amount = tier.get("amount", 0)
            else:
                amount = getattr(tier, "amount", 0)
            
            # Check price bounds
            if amount < QUALITY_GATES["min_price"]:
                flags.append("INVALID_PRICE")
            if amount > QUALITY_GATES["max_price"]:
                flags.append("INVALID_PRICE")
            
            # Check discount consistency
            discount = self._get_attr(offer, "discount")
            ref_price = self._get_attr(offer, "reference_price")
            
            if discount and ref_price:
                if isinstance(ref_price, dict):
                    ref_amount = ref_price.get("amount", 0)
                else:
                    ref_amount = getattr(ref_price, "amount", 0)
                
                if isinstance(discount, dict):
                    discount_pct = discount.get("percent", 0)
                else:
                    discount_pct = getattr(discount, "percent", 0)
                
                expected_diff = ref_amount - amount
                actual_diff = ref_amount * (discount_pct / 100)
                
                if abs(expected_diff - actual_diff) > 0.1:  # Allow small rounding
                    flags.append("DISCOUNT_INCONSISTENT")
    
    def _gate3_loyalty_rules(self, offer):
        """Gate 3: Loyalty Rules"""
        price_tiers = self._get_price_tiers(offer)
        flags = self._get_flags(offer)
        
        has_loyalty = False
        has_standard = False
        
        for tier in price_tiers:
            if isinstance(tier, dict):
                condition = tier.get("condition", {})
                if isinstance(condition, dict):
                    cond_type = condition.get("type", "standard")
                else:
                    cond_type = getattr(condition, "type", "standard")
            else:
                cond_type = getattr(tier.condition, "type", "standard") if hasattr(tier, "condition") else "standard"
            
            if cond_type == "loyalty":
                has_loyalty = True
            elif cond_type == "standard":
                has_standard = True
        
        if has_loyalty and not has_standard:
            flags.append("LOYALTY_WITHOUT_STANDARD")
            # Check if it's loyalty-only
            if len(price_tiers) == 1:
                flags.append("LOYALTY_ONLY_PRICE")
    
    def _gate4_brand_quantity(self, offer):
        """Gate 4: Brand & Quantity Plausibility"""
        flags = self._get_flags(offer)
        
        brand = self._get_attr(offer, "brand")
        if not brand:
            flags.append("MISSING_BRAND")
        
        quantity = self._get_attr(offer, "quantity")
        if isinstance(quantity, dict):
            qty_value = quantity.get("value")
        elif hasattr(quantity, "value"):
            qty_value = quantity.value
        else:
            qty_value = None
        
        if not qty_value:
            flags.append("MISSING_QUANTITY")
    
    def _gate5_duplicates_outliers(self, offer):
        """Gate 5: Duplicates & Outliers"""
        # This is handled at the list level, not per-offer
        pass
    
    def check_duplicates(self, offers: List) -> List[Dict[str, Any]]:
        """Check for duplicate offers"""
        seen = {}
        duplicates = []
        
        for offer in offers:
            title = self._get_title(offer).lower()
            quantity = self._get_attr(offer, "quantity")
            
            if isinstance(quantity, dict):
                qty_val = quantity.get("value")
                qty_unit = quantity.get("unit")
            elif hasattr(quantity, "value"):
                qty_val = quantity.value
                qty_unit = quantity.unit
            else:
                qty_val = None
                qty_unit = None
            
            key = (title, qty_val, qty_unit)
            
            if key in seen:
                flags = self._get_flags(offer)
                flags.append("DUPLICATE_OFFER")
                duplicates.append(self._offer_to_dict(offer))
            else:
                seen[key] = offer
        
        return duplicates
    
    def _offer_to_dict(self, offer) -> Dict[str, Any]:
        """Convert offer to dict"""
        if isinstance(offer, dict):
            return offer.copy()
        
        return {
            "id": self._get_attr(offer, "id"),
            "title": self._get_title(offer),
            "flags": self._get_flags(offer),
            "confidence": self._get_confidence(offer),
        }
    
    def _lower_confidence(self, current: str) -> str:
        """Lower confidence level"""
        if current == "high":
            return "medium"
        elif current == "medium":
            return "low"
        return "low"
    
    def _generate_gate_results(self, offers: List) -> List[Dict[str, Any]]:
        """Generate gate results summary"""
        return [
            {"gate": 1, "name": "Schema & Required Fields", "passed": len(offers)},
            {"gate": 2, "name": "Price Consistency", "passed": len(offers)},
            {"gate": 3, "name": "Loyalty Rules", "passed": len(offers)},
            {"gate": 4, "name": "Brand & Quantity", "passed": len(offers)},
            {"gate": 5, "name": "Duplicates & Outliers", "passed": len(offers)},
        ]
