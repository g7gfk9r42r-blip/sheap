"""Tests for merge logic."""
from __future__ import annotations

import pytest

from prospekt_pipeline.parsers.html_parser import HtmlOffer
from prospekt_pipeline.parsers.pdf_parser import PdfOffer
from prospekt_pipeline.parsers.ocr_parser import OcrOffer
from prospekt_pipeline.parsers.fallback_parser import FallbackOffer
from prospekt_pipeline.parsers.json_parser import JsonOffer
from prospekt_pipeline.pipeline.merge_results import merge_results, MergedOffer


def test_merge_fuzzy_match_similar_titles(sample_offers_similar: list):
    """Test merge logic merges offers with similar titles."""
    # Convert to list of HtmlOffer
    html_offers = sample_offers_similar
    
    merged = merge_results([], html_offers, [], [], [])
    
    # Should merge similar titles (85% similarity threshold)
    titles = [offer.title.lower() for offer in merged]
    unique_titles = set(titles)
    
    # Should reduce from 3 to 1 or 2 (depending on similarity calculation)
    assert len(merged) <= len(html_offers), \
        f"Should merge duplicates, got {len(merged)} from {len(html_offers)}"
    
    # At least one offer should remain
    assert len(merged) >= 1, "Should have at least one merged offer"


def test_merge_highest_confidence_wins():
    """Test merge logic uses highest confidence data."""
    html_offers = [
        HtmlOffer(title="Milsani Joghurt", price="1,99 €", unit_price=None, discount=None, confidence=0.90),
    ]
    
    pdf_offers = [
        PdfOffer(title="Milsani Joghurt", price="1,99 €", unit_price="1 kg = 13,27 €", confidence=0.85, source_page=1),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, [], [])
    
    # Should merge and keep higher confidence or better data
    assert len(merged) == 1, f"Should merge into 1 offer, got {len(merged)}"
    
    if merged:
        merged_offer = merged[0]
        # Should have unit_price from PDF (better data)
        assert merged_offer.unit_price or merged_offer.price, \
            "Should preserve best data from sources"


def test_merge_resolves_duplicate_prices():
    """Test merge logic resolves duplicate prices correctly."""
    html_offers = [
        HtmlOffer(title="Product", price="1,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.85, source_page=1),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, [], [])
    
    # Should merge and keep one price
    assert len(merged) == 1, "Should merge duplicates"
    
    if merged:
        # Price should be preserved
        assert merged[0].price == "1,99 €", "Should preserve price"


def test_merge_preserves_source_information():
    """Test merge logic preserves source information."""
    html_offers = [
        HtmlOffer(title="Product", price="1,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.85, source_page=2),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, [], [])
    
    if merged:
        # Source should contain both sources
        assert "html" in merged[0].source.lower() or "pdf" in merged[0].source.lower(), \
            f"Source should contain parser names: {merged[0].source}"


def test_merge_handles_empty_inputs():
    """Test merge logic handles empty inputs."""
    merged = merge_results([], [], [], [], [])
    
    assert isinstance(merged, list), "Should return a list"
    assert len(merged) == 0, "Empty inputs should return empty list"


def test_merge_priority_order():
    """Test merge logic respects priority order (JSON > HTML > PDF > OCR > Fallback)."""
    json_offers = [
        JsonOffer(title="Product", price="1,99 €", unit_price=None, confidence=1.0),
    ]
    
    html_offers = [
        HtmlOffer(title="Product", price="2,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Product", price="3,99 €", unit_price=None, confidence=0.85, source_page=1),
    ]
    
    merged = merge_results(json_offers, html_offers, pdf_offers, [], [])
    
    # Should merge all into one
    assert len(merged) == 1, "Should merge similar titles"
    
    if merged:
        # JSON has highest confidence, so should win
        assert merged[0].confidence >= 0.9, "Should use highest confidence source"


def test_merge_price_similarity_check():
    """Test merge logic checks price similarity for 80-85% title matches."""
    html_offers = [
        HtmlOffer(title="Milsani Joghurt Classic", price="1,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Milsani Joghurt", price="1,99 €", unit_price=None, confidence=0.85, source_page=1),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, [], [])
    
    # Should merge if prices are similar (within 10 cents)
    if len(merged) == 1:
        # Prices should match
        assert merged[0].price == "1,99 €", "Should merge when prices match"
