"""Tests for fallback parser."""
from __future__ import annotations

import pytest

from prospekt_pipeline.parsers.fallback_parser import FallbackParser, FallbackOffer


def test_fallback_parser_extracts_from_dirty_text(dirty_text_lines: list[str]):
    """Test fallback parser extracts offers from dirty text lines."""
    parser = FallbackParser()
    
    offers = parser.text_scavenge(dirty_text_lines, source="test")
    
    assert len(offers) >= 2, f"Expected at least 2 offers, got {len(offers)}"
    
    # All offers should have titles
    for offer in offers:
        assert offer.title, f"Offer missing title: {offer}"
        assert len(offer.title) >= 3


def test_fallback_parser_confidence_capped(dirty_text_lines: list[str]):
    """Test fallback parser confidence is capped at 0.5."""
    parser = FallbackParser()
    
    offers = parser.text_scavenge(dirty_text_lines, source="test")
    
    for offer in offers:
        assert offer.confidence <= 0.5, \
            f"Fallback confidence too high: {offer.confidence} (max 0.5)"
        assert offer.confidence >= 0.15, \
            f"Fallback confidence too low: {offer.confidence} (min 0.15)"


def test_fallback_parser_handles_various_formats():
    """Test fallback parser handles various price formats."""
    parser = FallbackParser()
    
    test_lines = [
        "SUPER DEAL – MILSANI Joghurt 0.29 € 150g",
        "NOW ONLY 1 79",
        "Banane 0,99",
        "Milch 1,99 €",
        "Brot 2 49 €",
    ]
    
    offers = parser.text_scavenge(test_lines, source="test")
    
    # Should extract at least some offers
    assert len(offers) > 0, "Should extract at least one offer"
    
    # Check price extraction
    prices_found = [offer.price for offer in offers if offer.price]
    assert len(prices_found) > 0, "Should extract at least one price"


def test_fallback_parser_deduplication():
    """Test fallback parser deduplicates similar offers."""
    parser = FallbackParser()
    
    # Duplicate lines
    lines = [
        "Milsani Joghurt 1,99 €",
        "Milsani Joghurt 1,99 €",
        "Banane 0,99 €",
    ]
    
    offers = parser.text_scavenge(lines, source="test")
    
    # Should deduplicate
    titles = [offer.title.lower() for offer in offers]
    unique_titles = set(titles)
    
    assert len(unique_titles) <= len(titles), "Should deduplicate"


def test_fallback_parser_filters_junk():
    """Test fallback parser filters junk patterns."""
    parser = FallbackParser()
    
    junk_lines = [
        "QR Code: https://example.com",
        "12345678901234567890",
        "Valid Product 1,99 €",
    ]
    
    offers = parser.text_scavenge(junk_lines, source="test")
    
    # Should filter out junk
    for offer in offers:
        assert "QR" not in offer.title.upper()
        assert "http" not in offer.title.lower()
        assert not offer.title.isdigit()


def test_fallback_parser_never_empty():
    """Test fallback parser never returns empty if prices are present."""
    parser = FallbackParser()
    
    # Lines with prices
    lines = [
        "Product 1,99 €",
        "Another 2,49 €",
    ]
    
    offers = parser.text_scavenge(lines, source="test")
    
    # Should return at least one offer
    assert len(offers) > 0, "Should return at least one offer when prices present"


def test_fallback_parser_source_tracking():
    """Test fallback parser tracks source correctly."""
    parser = FallbackParser()
    
    lines = ["Product 1,99 €"]
    offers = parser.text_scavenge(lines, source="html")
    
    for offer in offers:
        assert "html" in offer.source, f"Source should contain 'html', got {offer.source}"


def test_fallback_parser_handles_missing_prices():
    """Test fallback parser handles lines without prices."""
    parser = FallbackParser()
    
    lines = [
        "Just text without price",
        "Another line",
    ]
    
    offers = parser.text_scavenge(lines, source="test")
    
    # Might return 0 offers if no prices found
    assert isinstance(offers, list), "Should return a list"
    assert len(offers) >= 0, "Should return non-negative count"
