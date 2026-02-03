"""Parser for existing JSON offer files to improve extraction quality."""
from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

from ..utils.logger import get_logger
from ..utils.offer_validator import is_valid_offer, clean_title

LOGGER = get_logger("parsers.json")


@dataclass
class JsonOffer:
    title: Optional[str]
    price: Optional[str]
    unit_price: Optional[str]
    confidence: float
    source_page: int = 1
    source: str = "json"


class JsonParser:
    """Parser for existing JSON offer files.
    
    These files often contain pre-structured offer data that can be used
    to improve extraction quality and fill gaps from other parsers.
    """

    def parse(self, json_data: str, source_file: Path) -> List[JsonOffer]:
        """Parse JSON data from file."""
        LOGGER.info("[JSON] Parsing JSON data from %s", source_file.name)
        
        try:
            data = json.loads(json_data)
        except Exception as exc:
            LOGGER.warning("[JSON] Failed to parse JSON from %s: %s", source_file.name, exc)
            return []
        
        offers: List[JsonOffer] = []
        
        # Handle different JSON structures
        if isinstance(data, dict):
            # Structure: {"offers": [...]} or {"products": [...]} or direct offer objects
            if "offers" in data:
                items = data["offers"]
            elif "products" in data:
                items = data["products"]
            elif "items" in data:
                items = data["items"]
            else:
                # Try to find any list in the dict
                items = [v for v in data.values() if isinstance(v, list)]
                items = items[0] if items else []
        elif isinstance(data, list):
            items = data
        else:
            LOGGER.warning("[JSON] Unexpected JSON structure in %s", source_file.name)
            return []
        
        for item in items:
            if not isinstance(item, dict):
                continue
            
            # Extract title (try multiple field names)
            title = (
                item.get("title") or
                item.get("name") or
                item.get("product") or
                item.get("productName") or
                item.get("bezeichnung") or
                str(item.get("text", ""))
            )
            
            if not title:
                continue
            
            title = clean_title(str(title))
            if not title or not is_valid_offer(title):
                continue
            
            # Extract price (try multiple field names and formats)
            price = self._extract_price(item)
            
            # Extract unit price
            unit_price = (
                item.get("unit_price") or
                item.get("unitPrice") or
                item.get("pricePerUnit") or
                item.get("preis_pro_einheit") or
                item.get("kg_price") or
                item.get("liter_price")
            )
            if unit_price:
                unit_price = str(unit_price)
            
            # High confidence for JSON data (it's already structured)
            confidence = 0.95
            if price and unit_price:
                confidence = 1.0  # Perfect structured data
            elif price:
                confidence = 0.98
            else:
                confidence = 0.9  # Still high, but missing price
            
            offers.append(
                JsonOffer(
                    title=title,
                    price=price,
                    unit_price=unit_price,
                    confidence=confidence,
                )
            )
        
        LOGGER.info("[JSON] Extracted %d offers from %s", len(offers), source_file.name)
        return offers

    def _extract_price(self, item: dict) -> Optional[str]:
        """Extract price from item dict, handling various formats."""
        # Try direct price fields
        price = (
            item.get("price") or
            item.get("preis") or
            item.get("currentPrice") or
            item.get("offerPrice") or
            item.get("salePrice")
        )
        
        if price is not None:
            # Convert to string and format
            price_str = str(price)
            # If it's a number, format it as "X,XX €"
            try:
                price_float = float(price_str.replace(",", "."))
                return f"{price_float:.2f}".replace(".", ",") + " €"
            except ValueError:
                # Already a string, check if it has €
                if "€" not in price_str:
                    return price_str + " €"
                return price_str
        
        # Try oldPrice and discount calculation
        old_price = item.get("oldPrice") or item.get("originalPrice")
        discount = item.get("discount") or item.get("discountPercent")
        if old_price and discount:
            try:
                old_float = float(str(old_price).replace(",", "."))
                discount_float = float(str(discount).replace("%", "").replace(",", "."))
                new_price = old_float * (1 - discount_float / 100)
                return f"{new_price:.2f}".replace(".", ",") + " €"
            except (ValueError, TypeError):
                pass
        
        return None

