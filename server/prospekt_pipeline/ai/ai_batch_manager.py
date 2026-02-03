"""Batch manager for merging AI extraction results."""
from __future__ import annotations

import re
from typing import List

from ..utils.logger import get_logger

LOGGER = get_logger("ai.batch_manager")

# Patterns for junk detection
JUNK_PATTERNS = [
    re.compile(r"qr[- ]?code", re.IGNORECASE),
    re.compile(r"https?://[^\s]+", re.IGNORECASE),
    re.compile(r"www\.[^\s]+", re.IGNORECASE),
    re.compile(r"[a-z0-9]{20,}", re.IGNORECASE),  # Long alphanumeric strings
    re.compile(r"^[0-9\s\-\.]+$"),  # Only numbers
    re.compile(r"^[A-Z0-9]{8,}$"),  # Only uppercase codes
]


class AIBatchManager:
    """Manages batching and merging of AI extraction results."""

    def merge_batches(self, batch_results: List[List[dict]]) -> List[dict]:
        """Merge multiple batch results into a single list.
        
        Args:
            batch_results: List of lists, each containing offers from one page
            
        Returns:
            Flattened and cleaned list of offers
        """
        # Flatten batches
        all_offers: List[dict] = []
        for batch in batch_results:
            all_offers.extend(batch)

        LOGGER.info("[BATCH] Flattened %d batches into %d total offers", len(batch_results), len(all_offers))

        # Remove obvious junk
        cleaned_offers = self._remove_junk(all_offers)
        
        # Sort by confidence (highest first)
        cleaned_offers.sort(key=lambda x: x.get("confidence", 0.0), reverse=True)

        LOGGER.info("[BATCH] After cleaning: %d offers", len(cleaned_offers))
        return cleaned_offers

    def _remove_junk(self, offers: List[dict]) -> List[dict]:
        """Remove obvious junk offers.
        
        Args:
            offers: List of offer dictionaries
            
        Returns:
            Filtered list without junk
        """
        cleaned: List[dict] = []
        junk_count = 0

        for offer in offers:
            if not isinstance(offer, dict):
                junk_count += 1
                continue

            title = offer.get("title", "")
            if not title or not isinstance(title, str):
                junk_count += 1
                continue

            # Check title length
            if len(title.strip()) < 3:
                junk_count += 1
                continue

            # Check for alphabetic characters
            if not re.search(r"[a-zA-ZäöüÄÖÜß]", title):
                junk_count += 1
                continue

            # Check for junk patterns
            is_junk = False
            for pattern in JUNK_PATTERNS:
                if pattern.search(title):
                    is_junk = True
                    break

            if is_junk:
                junk_count += 1
                continue

            # Check price exists (at least one price field)
            price = offer.get("price")
            price_raw = offer.get("price_raw")
            if price is None and (not price_raw or not price_raw.strip()):
                # Allow offers without price if title is very descriptive
                words = title.split()
                if len(words) < 3:
                    junk_count += 1
                    continue

            cleaned.append(offer)

        if junk_count > 0:
            LOGGER.info("[BATCH] Removed %d junk offers", junk_count)

        return cleaned

