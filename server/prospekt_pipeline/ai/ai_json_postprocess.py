"""JSON post-processing and normalization for AI-extracted offers."""
from __future__ import annotations

import re
from typing import List

from ..utils.logger import get_logger

LOGGER = get_logger("ai.postprocess")


class AIJSONPostprocess:
    """Post-processes and normalizes AI-extracted offers."""

    def normalize(self, offers: List[dict]) -> List[dict]:
        """Normalize offers to standard format.
        
        Args:
            offers: List of offer dictionaries
            
        Returns:
            Normalized list of offers
        """
        normalized: List[dict] = []

        for offer in offers:
            if not isinstance(offer, dict):
                continue

            normalized_offer = {
                "title": self._normalize_title(offer.get("title")),
                "price": self._normalize_price(offer.get("price"), offer.get("price_raw")),
                "price_raw": offer.get("price_raw") or self._format_price_raw(offer.get("price")),
                "unit": self._normalize_unit(offer.get("unit")),
                "brand": self._normalize_brand(offer.get("brand")),
                "category": self._normalize_category(offer.get("category")),
                "valid_from": offer.get("valid_from"),
                "valid_to": offer.get("valid_to"),
                "source_page": offer.get("page"),
                "confidence": self._normalize_confidence(offer.get("confidence")),
                "source": offer.get("source", "ai_vision"),
            }

            # Only add if title is valid
            if normalized_offer["title"] and len(normalized_offer["title"]) >= 3:
                normalized.append(normalized_offer)

        LOGGER.info("[POSTPROCESS] Normalized %d offers", len(normalized))
        return normalized

    def _normalize_title(self, title: str | None) -> str | None:
        """Normalize title.
        
        Args:
            title: Title string
            
        Returns:
            Normalized title or None
        """
        if not title:
            return None

        # Strip whitespace
        normalized = title.strip()

        # Remove multiple spaces
        normalized = re.sub(r"\s+", " ", normalized)

        # Remove leading/trailing special characters
        normalized = re.sub(r"^[^\w]+|[^\w]+$", "", normalized)

        if len(normalized) < 3:
            return None

        return normalized

    def _normalize_price(self, price: float | str | None, price_raw: str | None) -> float | None:
        """Normalize price to float.
        
        Args:
            price: Price as float, string, or None
            price_raw: Raw price string
            
        Returns:
            Normalized price as float or None
        """
        # Try direct price first
        if price is not None:
            try:
                return float(price)
            except (ValueError, TypeError):
                pass

        # Try to extract from price_raw
        if price_raw:
            try:
                # Remove currency symbols
                cleaned = price_raw.replace("€", "").replace("EUR", "").strip()
                
                # Handle German format (comma as decimal)
                if "," in cleaned and "." in cleaned:
                    # Determine format
                    if cleaned.count(".") > cleaned.count(","):
                        # Dots are thousands separators
                        cleaned = cleaned.replace(".", "").replace(",", ".")
                    else:
                        # Comma is decimal
                        cleaned = cleaned.replace(".", "").replace(",", ".")
                elif "," in cleaned:
                    cleaned = cleaned.replace(",", ".")
                
                # Remove unit indicators
                cleaned = re.sub(r"\s*(?:kg|l|L|g|ml|stück|stk)\s*", "", cleaned, flags=re.IGNORECASE)
                
                return float(cleaned)
            except (ValueError, AttributeError):
                pass

        return None

    def _format_price_raw(self, price: float | None) -> str | None:
        """Format price as raw string.
        
        Args:
            price: Price as float
            
        Returns:
            Formatted price string or None
        """
        if price is None:
            return None

        try:
            return f"{price:.2f}".replace(".", ",") + " €"
        except (ValueError, TypeError):
            return None

    def _normalize_unit(self, unit: str | None) -> str | None:
        """Normalize unit string.
        
        Args:
            unit: Unit string
            
        Returns:
            Normalized unit (kg, g, L, ml, Stück) or None
        """
        if not unit:
            return None

        unit_lower = unit.lower().strip()

        # Map to standard units
        unit_map = {
            "kg": "kg",
            "kilogram": "kg",
            "kilogramm": "kg",
            "g": "g",
            "gramm": "g",
            "gram": "g",
            "100g": "100g",
            "l": "L",
            "liter": "L",
            "ml": "ml",
            "milliliter": "ml",
            "stück": "Stück",
            "stk": "Stück",
            "stk.": "Stück",
            "piece": "Stück",
            "pieces": "Stück",
        }

        # Check for exact matches
        if unit_lower in unit_map:
            return unit_map[unit_lower]

        # Check for partial matches
        for key, value in unit_map.items():
            if key in unit_lower:
                return value

        # Return original if no match
        return unit

    def _normalize_brand(self, brand: str | None) -> str | None:
        """Normalize brand name.
        
        Args:
            brand: Brand string
            
        Returns:
            Normalized brand or None
        """
        if not brand:
            return None

        # Lowercase and strip
        normalized = brand.strip()

        if len(normalized) < 2:
            return None

        return normalized

    def _normalize_category(self, category: str | None) -> str | None:
        """Normalize category name.
        
        Args:
            category: Category string
            
        Returns:
            Normalized category or None
        """
        if not category:
            return None

        # Capitalize first letter
        normalized = category.strip().capitalize()

        if len(normalized) < 2:
            return None

        return normalized

    def _normalize_confidence(self, confidence: float | None) -> float:
        """Normalize confidence score.
        
        Args:
            confidence: Confidence value
            
        Returns:
            Normalized confidence (0.0-1.0)
        """
        if confidence is None:
            return 0.8  # Default for AI-extracted offers

        try:
            conf_float = float(confidence)
            # Ensure in range [0.0, 1.0]
            return max(0.0, min(1.0, conf_float))
        except (ValueError, TypeError):
            return 0.8

