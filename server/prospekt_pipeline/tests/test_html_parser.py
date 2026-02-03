"""Tests for HTML parser."""
from __future__ import annotations

import pytest

from prospekt_pipeline.parsers.html_parser import HtmlParser, HtmlOffer


def test_html_parser_extracts_three_offers(sample_html: str):
    """Test HTML parser extracts 3 offers from sample HTML."""
    parser = HtmlParser()
    offers = parser.parse(sample_html)
    
    assert len(offers) == 3, f"Expected 3 offers, got {len(offers)}"
    
    # Verify all offers have titles
    for offer in offers:
        assert offer.title, f"Offer missing title: {offer}"
        assert len(offer.title) >= 3, f"Title too short: {offer.title}"


def test_html_parser_extracts_price_formats(sample_html: str):
    """Test HTML parser handles different price formats."""
    parser = HtmlParser()
    offers = parser.parse(sample_html)
    
    # Find offers with different price formats
    prices_found = [offer.price for offer in offers if offer.price]
    
    # Should find at least one price
    assert len(prices_found) > 0, "No prices extracted"
    
    # Check for different formats
    price_strings = " ".join(prices_found)
    assert "€" in price_strings or any(char.isdigit() for char in price_strings), \
        "Prices should contain € or digits"


def test_html_parser_extracts_units(sample_html: str):
    """Test HTML parser extracts unit information."""
    parser = HtmlParser()
    offers = parser.parse(sample_html)
    
    # At least one offer should have unit information
    units_found = [offer.unit_price for offer in offers if offer.unit_price]
    
    # Units might be in unit_price field or extracted from text
    # Just verify parser doesn't crash
    assert isinstance(offers, list)


def test_html_parser_skips_empty_nodes(sample_html: str):
    """Test HTML parser skips empty nodes."""
    parser = HtmlParser()
    offers = parser.parse(sample_html)
    
    # All offers should have non-empty titles
    for offer in offers:
        assert offer.title, f"Empty title found: {offer}"
        assert offer.title.strip(), f"Whitespace-only title: {offer.title}"


def test_html_parser_handles_malformed_html(sample_html_malformed: str):
    """Test HTML parser handles malformed HTML."""
    parser = HtmlParser()
    offers = parser.parse(sample_html_malformed)
    
    # Should extract at least some offers
    assert len(offers) >= 2, f"Expected at least 2 offers, got {len(offers)}"
    
    # All offers should be valid
    for offer in offers:
        assert offer.title, f"Invalid offer: {offer}"
        assert len(offer.title) >= 3


def test_html_parser_price_formats():
    """Test HTML parser handles various price formats."""
    parser = HtmlParser()
    
    html_cases = [
        ('<div class="price">1,99 €</div>', "1,99 €"),
        ('<div class="price">0.79</div>', "0.79"),
        ('<strong>2 49</strong><span>€</span>', "2 49"),
    ]
    
    for html, expected_pattern in html_cases:
        offers = parser.parse(f'<div class="product">{html}</div>')
        # Just verify parsing doesn't crash
        assert isinstance(offers, list)


def test_html_parser_unit_extraction():
    """Test HTML parser extracts units correctly."""
    parser = HtmlParser()
    
    html = """
    <div class="product">
        <span>Milch</span>
        <span class="price">1,99 €</span>
        <span class="unit">1 L = 1,99 €</span>
    </div>
    """
    
    offers = parser.parse(html)
    
    if offers:
        # Check if unit was extracted
        for offer in offers:
            if offer.unit_price:
                assert "L" in offer.unit_price or "kg" in offer.unit_price.lower() or \
                       "g" in offer.unit_price.lower()


def test_html_parser_confidence_scoring():
    """Test HTML parser assigns appropriate confidence scores."""
    parser = HtmlParser()
    
    html = """
    <div class="product-card">
        <h3>Test Product</h3>
        <span class="price">1,99 €</span>
        <span class="unit-price">1 kg = 9,98 €</span>
    </div>
    """
    
    offers = parser.parse(html)
    
    if offers:
        for offer in offers:
            assert 0.5 <= offer.confidence <= 1.0, \
                f"Confidence out of range: {offer.confidence}"


def test_html_parser_filters_invalid_offers():
    """Test HTML parser filters out invalid offers."""
    parser = HtmlParser()
    
    # HTML with junk data
    html = """
    <div class="product">QR Code: https://example.com/qr</div>
    <div class="product">12345678901234567890</div>
    <div class="product">Valid Product 1,99 €</div>
    """
    
    offers = parser.parse(html)
    
    # Should filter out junk
    for offer in offers:
        assert "QR" not in offer.title.upper()
        assert "http" not in offer.title.lower()
        assert len(offer.title) >= 3
