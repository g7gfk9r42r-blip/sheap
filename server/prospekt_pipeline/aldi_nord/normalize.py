"""Normalize offers: prices, units, brands, categories."""
from __future__ import annotations

import re
from typing import List

from .models import Offer


class OfferNormalizer:
    """Normalize offer data."""

    def normalize(self, offers: List[Offer]) -> List[Offer]:
        """Normalize all offers."""
        normalized = []
        for offer in offers:
            normalized_offer = self._normalize_offer(offer)
            if normalized_offer:
                normalized.append(normalized_offer)

        return normalized

    def _normalize_offer(self, offer: Offer) -> Offer:
        """Normalize single offer."""
        # Normalize title
        title = self._normalize_title(offer.title) if offer.title else ""
        if not title or len(title) < 3:
            return None

        # Normalize price
        price = offer.price
        price_raw = offer.price_raw
        if not price and price_raw:
            price = self._parse_price(price_raw)

        # Normalize unit
        unit = self._normalize_unit(offer.unit) if offer.unit else None

        # Detect brand if missing
        brand = offer.brand
        if not brand:
            brand = self._detect_brand(title)

        # Detect category if missing
        category = offer.category
        if not category:
            category = self._detect_category(title)

        return Offer(
            title=title,
            price=price,
            price_raw=price_raw,
            unit=unit,
            brand=brand,
            category=category,
            confidence=offer.confidence,
            source=offer.source,
            source_page=offer.source_page,
            valid_from=offer.valid_from,
            valid_to=offer.valid_to,
        )

    def _normalize_title(self, title: str) -> str:
        """Clean and normalize title."""
        # Remove extra whitespace
        title = re.sub(r"\s+", " ", title).strip()

        # Remove special characters at start/end
        title = re.sub(r"^[^\w]+|[^\w]+$", "", title)

        # Capitalize first letter
        if title:
            title = title[0].upper() + title[1:]

        return title

    def _parse_price(self, price_str: str) -> float | None:
        """Parse price string to float."""
        if not price_str:
            return None

        # Remove currency symbols
        price_str = re.sub(r"[€EUR]", "", price_str, flags=re.I).strip()

        # Handle German format (comma as decimal)
        if "," in price_str and "." in price_str:
            # Determine format
            if price_str.count(".") > price_str.count(","):
                # Dots are thousands separators
                price_str = price_str.replace(".", "").replace(",", ".")
            else:
                # Comma is decimal
                price_str = price_str.replace(".", "").replace(",", ".")
        elif "," in price_str:
            price_str = price_str.replace(",", ".")

        try:
            price = float(price_str)
            if 0.01 <= price <= 200:
                return price
        except ValueError:
            pass

        return None

    def _normalize_unit(self, unit: str) -> str:
        """Normalize unit string."""
        unit_lower = unit.lower().strip()

        unit_map = {
            "kg": "kg",
            "kilogram": "kg",
            "kilogramm": "kg",
            "g": "g",
            "gramm": "g",
            "gram": "g",
            "l": "L",
            "liter": "L",
            "ml": "ml",
            "milliliter": "ml",
            "stück": "Stück",
            "stk": "Stück",
            "stk.": "Stück",
        }

        if unit_lower in unit_map:
            return unit_map[unit_lower]

        # Check for partial matches
        for key, value in unit_map.items():
            if key in unit_lower:
                return value

        return unit

    def _detect_brand(self, title: str) -> str | None:
        """Detect brand from title."""
        brands = [
            "Knorr", "Coca Cola", "Rama", "MILSANI", "Gut & Günstig",
            "Frosta", "Dr. Oetker", "Nestlé", "Milka", "Haribo",
            "Edeka", "Rewe", "Penny", "Lidl",
        ]

        title_lower = title.lower()
        for brand in brands:
            if brand.lower() in title_lower:
                return brand

        return None

    def _detect_category(self, title: str) -> str | None:
        """Detect category from title."""
        categories = {
            "Fleisch": ["fleisch", "wurst", "schinken", "salami", "hackfleisch", "schnitzel"],
            "Obst": ["apfel", "banane", "orange", "erdbeere", "traube", "kiwi"],
            "Gemüse": ["tomate", "gurke", "paprika", "karotte", "zwiebel", "kartoffel"],
            "Tiefkühl": ["tiefkühl", "frozen", "tiefkühltruhe"],
            "Milchprodukte": ["milch", "joghurt", "käse", "quark", "sahne", "butter"],
            "Getränke": ["getränk", "saft", "wasser", "cola", "bier", "limo"],
            "Backwaren": ["brot", "brötchen", "croissant", "kuchen"],
        }

        title_lower = title.lower()
        for category, keywords in categories.items():
            if any(kw in title_lower for kw in keywords):
                return category

        return None

