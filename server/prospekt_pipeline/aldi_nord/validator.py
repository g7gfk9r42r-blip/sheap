"""Validate and filter offers."""
from __future__ import annotations

import re
from typing import List

from .models import Offer

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None


class OfferValidator:
    """Validate and filter offers."""

    def validate(self, offers: List[Offer]) -> List[Offer]:
        """Validate and filter offers."""
        valid = []

        for offer in offers:
            if self._is_valid(offer):
                valid.append(offer)

        # Remove duplicates
        return self._remove_duplicates(valid)

    def _is_valid(self, offer: Offer) -> bool:
        """Check if offer is valid."""
        # Must have title
        if not offer.title or len(offer.title.strip()) < 3:
            return False

        # Must have price OR meaningful title
        if not offer.price and len(offer.title.split()) < 2:
            return False

        # Filter QR codes and URLs
        title_lower = offer.title.lower()
        if any(pattern in title_lower for pattern in ["qr code", "http://", "https://", "www."]):
            return False

        # Filter code-like strings (long alphanumeric)
        if re.match(r"^[a-z0-9]{20,}$", title_lower):
            return False

        # Price validation
        if offer.price and (offer.price < 0.01 or offer.price > 200):
            return False

        return True

    def _remove_duplicates(self, offers: List[Offer]) -> List[Offer]:
        """Remove duplicate offers."""
        if fuzz:
            # Fuzzy deduplication
            unique = []
            for offer in offers:
                is_duplicate = False
                for existing in unique:
                    if offer.title and existing.title:
                        similarity = fuzz.ratio(offer.title.lower(), existing.title.lower())
                        if similarity > 90:
                            # Keep higher confidence
                            if offer.confidence > existing.confidence:
                                unique.remove(existing)
                                unique.append(offer)
                            is_duplicate = True
                            break
                if not is_duplicate:
                    unique.append(offer)
            return unique
        else:
            # Exact match fallback
            seen = set()
            unique = []
            for offer in offers:
                key = offer.title.lower() if offer.title else ""
                if key and key not in seen:
                    seen.add(key)
                    unique.append(offer)
            return unique

