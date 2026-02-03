"""Merge logic for offers originating from multiple parsers."""
from __future__ import annotations

from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Iterable, List

from ..parsers.html_parser import HtmlOffer
from ..parsers.pdf_parser import PdfOffer
from ..parsers.ocr_parser import OcrOffer
from ..parsers.fallback_parser import FallbackOffer
from ..parsers.json_parser import JsonOffer

from ..utils.logger import get_logger

LOGGER = get_logger("pipeline.merge")


@dataclass
class MergedOffer:
    title: str
    price: str | None
    unit_price: str | None
    confidence: float
    source: str
    source_page: int | None = None


def merge_results(
    json_offers: Iterable[JsonOffer],
    html_offers: Iterable[HtmlOffer],
    pdf_offers: Iterable[PdfOffer],
    ocr_offers: Iterable[OcrOffer],
    fallback_offers: Iterable[FallbackOffer],
    ai_offers: Iterable[HtmlOffer] = (),  # AI offers use HtmlOffer format
) -> List[MergedOffer]:
    """Merge parser results with fuzzy deduplication (85% similarity threshold)."""
    merged: dict[str, MergedOffer] = {}

    def _similarity(a: str, b: str) -> float:
        """Calculate similarity between two titles using fuzzy matching."""
        a_lower = a.lower().strip()
        b_lower = b.lower().strip()
        
        # Exact match
        if a_lower == b_lower:
            return 1.0
        
        # SequenceMatcher for general similarity
        ratio = SequenceMatcher(None, a_lower, b_lower).ratio()
        
        # Bonus for common words
        words_a = set(a_lower.split())
        words_b = set(b_lower.split())
        if words_a and words_b:
            common_words = words_a.intersection(words_b)
            if common_words:
                word_ratio = len(common_words) / max(len(words_a), len(words_b))
                # Combine both metrics
                ratio = max(ratio, word_ratio * 0.8)
        
        return ratio

    def _upsert(title: str | None, price: str | None, unit_price: str | None, source: str, confidence: float, source_page: int | None = None) -> None:
        """Upsert offer with fuzzy deduplication (85% similarity threshold)."""
        if not title:
            return
        key = title.lower().strip()
        
        # Check for duplicates using fuzzy matching (85% threshold)
        for existing_key, existing in merged.items():
            similarity = _similarity(key, existing_key)
            
            # Very similar (>85%) - definitely duplicate
            if similarity >= 0.85:
                # Update if higher confidence or missing data
                should_update = (
                    confidence > existing.confidence or
                    (not existing.price and price) or
                    (not existing.unit_price and unit_price) or
                    (existing.confidence < 0.5 and confidence >= 0.5)  # Prefer higher quality
                )
                if should_update:
                    existing.title = title  # Use newer title (might be cleaner)
                    existing.price = existing.price or price
                    existing.unit_price = existing.unit_price or unit_price
                    existing.confidence = max(existing.confidence, confidence)
                    existing.source_page = existing.source_page or source_page
                    if source not in existing.source:
                        existing.source = f"{existing.source},{source}"
                return
            
            # Similar (80-85%) - likely duplicate, check price similarity
            if similarity >= 0.80:
                if price and existing.price:
                    try:
                        price_a = float(price.replace("€", "").replace(",", ".").strip())
                        price_b = float(existing.price.replace("€", "").replace(",", ".").strip())
                        # Prices differ by less than 10 cents = same offer
                        if abs(price_a - price_b) < 0.10:
                            if confidence > existing.confidence or (not existing.unit_price and unit_price):
                                existing.title = title
                                existing.price = existing.price or price
                                existing.unit_price = existing.unit_price or unit_price
                                existing.confidence = max(existing.confidence, confidence)
                                existing.source_page = existing.source_page or source_page
                                if source not in existing.source:
                                    existing.source = f"{existing.source},{source}"
                            return
                    except (ValueError, AttributeError):
                        pass
        
        # New unique offer
        merged[key] = MergedOffer(title=title, price=price, unit_price=unit_price, confidence=confidence, source=source, source_page=source_page)

    # Strict priority: AI → JSON → HTML → PDF → OCR → Fallback
    # AI offers first (highest priority - Vision-AI extraction)
    for offer in ai_offers:
        ai_conf = max(0.95, offer.confidence)  # AI has very high confidence
        _upsert(offer.title, offer.price, offer.unit_price, "ai_vision", ai_conf, None)
    
    # JSON offers (existing structured data - second priority)
    for offer in json_offers:
        _upsert(offer.title, offer.price, offer.unit_price, "json", offer.confidence, None)
    
    # HTML offers (high quality structured data)
    for offer in html_offers:
        _upsert(offer.title, offer.price, offer.unit_price, "html", offer.confidence, None)

    # PDF offers
    for offer in pdf_offers:
        pdf_conf = max(0.7, offer.confidence) if offer.confidence > 0.5 else 0.7
        _upsert(offer.title, offer.price, offer.unit_price, "pdf", pdf_conf, getattr(offer, 'source_page', None))

    # OCR offers
    for offer in ocr_offers:
        ocr_conf = max(0.5, offer.confidence) if offer.confidence > 0.2 else 0.5
        _upsert(offer.title, offer.price, offer.unit_price, f"ocr:p{offer.source_page}", ocr_conf, offer.source_page)

    # Fallback offers
    for offer in fallback_offers:
        fallback_conf = max(0.3, offer.confidence) if offer.confidence > 0.0 else 0.3
        _upsert(offer.title, offer.price, offer.unit_price, offer.source, fallback_conf, None)

    result = list(merged.values())
    LOGGER.info("[MERGE] Merged %d unique offers from %d sources", len(result), 
                sum(bool(list(src)) for src in [ai_offers, json_offers, html_offers, pdf_offers, ocr_offers, fallback_offers]))
    return result
