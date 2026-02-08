"""Main normalizer - orchestrates all normalization"""

import hashlib
from typing import Dict, Any, List
import logging

from ..models import Offer, PriceTier, ReferencePrice, Quantity, Price, Source, Discount
from .price_parser import PriceParser
from .brand_resolver import BrandResolver
from .unit_parser import UnitParser

logger = logging.getLogger(__name__)


class Normalizer:
    """Normalize raw offers into Offer objects"""
    
    def __init__(self, supermarket: str, week_key: str):
        self.supermarket = supermarket
        self.week_key = week_key
    
    def normalize(self, raw_offers: List[Dict[str, Any]]) -> List[Offer]:
        """
        Normalize raw offers.
        
        Args:
            raw_offers: List of raw offer dictionaries
            
        Returns:
            List of normalized Offer objects
        """
        normalized = []
        
        for i, raw in enumerate(raw_offers):
            try:
                if not isinstance(raw, dict):
                    logger.warning(f"Offer {i} is not a dict, skipping")
                    continue
                offer = self._normalize_one(raw, i)
                if offer:
                    normalized.append(offer)
            except Exception as e:
                logger.error(f"Failed to normalize offer {i}: {e}")
                import traceback
                logger.debug(traceback.format_exc())
                continue
        
        return normalized
    
    def _normalize_one(self, raw: Dict[str, Any], index: int) -> Optional[Offer]:
        """Normalize a single offer"""
        # Extract title - try multiple fields
        title = (
            raw.get("title") or 
            raw.get("name") or 
            raw.get("product") or 
            raw.get("label") or
            ""
        )
        if isinstance(title, str):
            title = title.strip()
        else:
            title = str(title).strip() if title else ""
        
        if not title or len(title) < 2:
            logger.debug(f"Offer {index} has no valid title, skipping")
            return None
        
        # Generate ID
        offer_id = self._generate_id(title, raw)
        
        # Normalize prices
        raw_prices = raw.get("prices", [])
        if not isinstance(raw_prices, list):
            raw_prices = []
        
        # If no prices array, try to extract from single price field
        if not raw_prices:
            single_price = raw.get("price")
            if single_price is not None:
                try:
                    price_val = float(single_price) if not isinstance(single_price, (int, float)) else float(single_price)
                    if price_val > 0:
                        raw_prices = [{
                            "amount": price_val,
                            "condition": {"type": "standard"},
                            "is_reference": False,
                        }]
                except (ValueError, TypeError):
                    pass
        
        if not raw_prices:
            logger.debug(f"Offer {index} has no prices, skipping")
            return None
        
        try:
            price_tiers, reference_price = PriceParser.normalize_prices(raw_prices)
        except Exception as e:
            logger.error(f"Failed to normalize prices for offer {index}: {e}")
            return None
        
        if not price_tiers:
            logger.debug(f"Offer {index} has no valid price tiers after normalization")
            return None
        
        # Set base price (first standard price, or first price)
        base_price = Price(amount=price_tiers[0].amount, currency="EUR")
        
        # Normalize brand
        raw_brand = raw.get("brand")
        brand, brand_confidence = BrandResolver.resolve_brand(raw_brand, title)
        
        # Normalize quantity
        raw_quantity = raw.get("quantity", {})
        quantity = UnitParser.parse_quantity(raw_quantity, title)
        
        # Extract category (if provided)
        category = raw.get("category")
        
        # Calculate discount (if reference price exists)
        discount = None
        if reference_price and base_price.amount:
            diff = reference_price.amount - base_price.amount
            if diff > 0:
                percent = (diff / reference_price.amount) * 100
                discount = Discount(percent=round(percent, 1), derived=True)
        
        # Build source
        source_dict = raw.get("source", {})
        source = Source(
            primary=source_dict.get("primary", "list"),
            pdf_file=source_dict.get("pdf_file"),
            list_file=source_dict.get("list_file"),
            page=source_dict.get("page"),
            raw_text=source_dict.get("raw_text"),
        )
        
        # Initial flags
        flags = raw.get("flags", [])
        
        # Build offer
        offer = Offer(
            id=offer_id,
            supermarket=self.supermarket,
            week_key=self.week_key,
            title=title,
            brand=brand,
            brand_confidence=brand_confidence,
            category=category,
            quantity=quantity,
            base_price=base_price,
            reference_price=reference_price,
            price_tiers=price_tiers,
            discount=discount,
            source=source,
            confidence=raw.get("confidence", "medium"),
            flags=flags,
            inferred=raw.get("inferred", {}),
        )
        
        return offer
    
    def _generate_id(self, title: str, raw: Dict[str, Any]) -> str:
        """Generate stable ID for offer"""
        # Use title + supermarket + first price
        price_str = ""
        if raw.get("prices"):
            first_price = raw["prices"][0].get("amount")
            if first_price:
                price_str = str(first_price)
        
        id_string = f"{self.supermarket}-{title}-{price_str}"
        return hashlib.sha256(id_string.encode()).hexdigest()[:16]

