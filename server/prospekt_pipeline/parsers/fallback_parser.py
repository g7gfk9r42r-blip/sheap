"""Aggressive fallback parser with multiple text scavenging strategies."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Iterable, List, Optional

from ..utils.logger import get_logger
from ..utils.offer_validator import is_valid_offer, clean_title, extract_product_name

LOGGER = get_logger("parsers.fallback")

# Erweiterte Patterns
PRICE_PATTERN = re.compile(r"\d+[\.,]\d{1,2}\s*€")
UNIT_PATTERN = re.compile(r"(?:1\s*(?:kg|l|L|g|ml)\s*=\s*)?(\d+[\.,]\d{1,2})\s*€")
DISCOUNT_PATTERN = re.compile(r"-\s*(\d+)\s*%|(\d+[\.,]\d{1,2})\s*€\s*sparen", re.IGNORECASE)


@dataclass
class FallbackOffer:
    title: Optional[str]
    price: Optional[str]
    unit_price: Optional[str]
    confidence: float
    source_page: int = 1
    source: str = "fallback"


class FallbackParser:
    """Aggressive fallback parser with multiple strategies."""

    def text_scavenge(self, lines: Iterable[str], source: str) -> List[FallbackOffer]:
        """Scavenge offers from raw text lines."""
        line_list = list(lines)
        offers: List[FallbackOffer] = []
        
        # Strategy 1: Single line scanning
        for line in line_list:
            line = line.strip()
            if not line:
                continue
            if PRICE_PATTERN.search(line):
                offer = self._line_to_offer(line, source)
                if offer and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)
        
        # Strategy 2: Multi-line blocks (2-3 lines)
        for i in range(len(line_list) - 1):
            block = " ".join(line_list[i:i + 2])
            if PRICE_PATTERN.search(block):
                offer = self._line_to_offer(block, source)
                if offer and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)
        
        # Strategy 3: Context-aware (previous + current line)
        for i in range(1, len(line_list)):
            context = f"{line_list[i-1]} {line_list[i]}"
            if PRICE_PATTERN.search(context):
                offer = self._line_to_offer(context, source)
                if offer and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)
        
        # Deduplicate
        unique_offers = self._deduplicate(offers)
        
        LOGGER.fallback("Fallback parser found %d unique offers in %s", len(unique_offers), source)
        return unique_offers

    def _line_to_offer(self, text: str, source: str) -> Optional[FallbackOffer]:
        """Convert text line to offer - sorgfältig."""
        price_match = PRICE_PATTERN.search(text)
        if not price_match:
            return None
        
        price_val = price_match.group(0)
        
        # Extract unit price - sorgfältig
        unit_match = UNIT_PATTERN.search(text)
        unit_val = unit_match.group(0) if unit_match else None
        
        # Sorgfältige Titel-Extraktion
        title = extract_product_name(text)
        if not title:
            # Fallback
            title = text
            if price_val:
                title = title.replace(price_val, "")
            if unit_val:
                title = title.replace(unit_val, "")
            # Remove discount patterns
            title = re.sub(r"-\s*\d+\s*%", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\d+[\.,]\d{1,2}\s*€\s*sparen", "", title, flags=re.IGNORECASE)
            title = clean_title(title.strip())
        
        if not title or len(title) < 3:
            return None
        
        # Additional validation: check for junk patterns
        if re.match(r'^[0-9\s\-\.]+$', title):  # Only numbers
            return None
        if re.match(r'^[A-Z0-9]{8,}$', title):  # Only uppercase codes
            return None
        
        # Check for minimum word count
        words = title.split()
        if len(words) < 1:
            return None
        
        # Confidence scoring - sorgfältiger
        confidence = 0.25  # Lower base for fallback
        if price_val and unit_val and title:
            confidence = 0.35  # Gut für Fallback
        elif price_val and title:
            confidence = 0.30  # Ok
        elif title:
            confidence = 0.25  # Basis
        
        # Bonus für Produkt-Keywords
        if re.search(r"\b(?:kg|g|ml|l|L|bio|frisch|packung|pack)\b", title, re.IGNORECASE):
            confidence += 0.03
        
        # Penalty for very short titles
        if len(words) < 2:
            confidence -= 0.05
        
        # Ensure minimum confidence
        confidence = max(0.15, min(confidence, 0.5))  # Max 0.5 für Fallback, min 0.15
        
        return FallbackOffer(
            title=title[:200] if title else None,
            price=price_val,
            unit_price=unit_val,
            confidence=confidence,
            source=f"fallback:{source}",
        )

    def _deduplicate(self, offers: List[FallbackOffer]) -> List[FallbackOffer]:
        """Remove duplicate offers."""
        from difflib import SequenceMatcher
        
        unique: List[FallbackOffer] = []
        seen_titles: set[str] = set()
        
        for offer in offers:
            if not offer.title:
                continue
            
            title_lower = offer.title.lower().strip()
            
            if title_lower in seen_titles:
                continue
            
            is_duplicate = False
            for seen in seen_titles:
                similarity = SequenceMatcher(None, title_lower, seen).ratio()
                if similarity > 0.85:
                    is_duplicate = True
                    break
            
            if not is_duplicate:
                unique.append(offer)
                seen_titles.add(title_lower)
        
        return unique
