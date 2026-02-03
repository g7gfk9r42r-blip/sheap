"""Merge offers from multiple sources (HTML, PDF, Vision)."""
from __future__ import annotations

from typing import List

from .models import Offer

try:
    from rapidfuzz import fuzz
except ImportError:
    fuzz = None


def merge_offers(
    html_offers: List[Offer],
    pdf_offers: List[Offer],
    vision_offers: List[Offer],
    baseline_offers: List[Offer] = None,
) -> List[Offer]:
    """Merge offers from all sources with priority rules."""
    merged_dict = {}

    # Priority: Vision (≥0.95) > HTML > PDF > Baseline
    all_offers = vision_offers + html_offers + pdf_offers
    if baseline_offers:
        all_offers.extend(baseline_offers)

    for offer in all_offers:
        if not offer.title:
            continue

        key = offer.title.lower().strip()

        # Check for existing similar offer
        existing_key = None
        if fuzz:
            for existing in merged_dict:
                similarity = fuzz.ratio(key, existing.lower())
                if similarity > 85:
                    existing_key = existing
                    break
        else:
            # Exact match fallback
            if key in merged_dict:
                existing_key = key

        if existing_key:
            # Merge: keep higher confidence or more complete data
            existing = merged_dict[existing_key]
            if offer.confidence >= 0.95 or (offer.confidence > existing.confidence and offer.price):
                merged_dict[existing_key] = offer
        else:
            # New offer
            merged_dict[key] = offer

    return list(merged_dict.values())

