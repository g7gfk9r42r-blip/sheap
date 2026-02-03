"""Tests for OCR parser."""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from prospekt_pipeline.parsers.ocr_parser import OcrParser, OcrOffer


def test_ocr_parser_returns_structured_offer(sample_ocr_text: str):
    """Test OCR parser returns structured offer from mock OCR output."""
    parser = OcrParser()
    
    # Mock the OCR processing
    with patch('prospekt_pipeline.parsers.ocr_parser.pytesseract') as mock_tesseract:
        mock_tesseract.image_to_string.return_value = sample_ocr_text
        
        # Create a mock image
        from PIL import Image
        mock_image = Image.new('RGB', (100, 100))
        
        # Process the page
        offers = parser._process_page(mock_image, page_num=1)
        
        assert isinstance(offers, list), "Should return a list"
        assert len(offers) > 0, "Should extract at least one offer"
        
        for offer in offers:
            assert isinstance(offer, OcrOffer), f"Should return OcrOffer, got {type(offer)}"
            assert offer.title, f"Offer missing title: {offer}"
            assert offer.source_page == 1, f"Source page should be 1, got {offer.source_page}"


def test_ocr_parser_confidence_capped():
    """Test OCR parser confidence is capped appropriately."""
    parser = OcrParser()
    
    # Mock OCR text with price and unit
    ocr_text = "Apfel 1,99 € / kg"
    
    offers = parser._extract_from_text(ocr_text, page_num=1)
    
    for offer in offers:
        # OCR confidence should be reasonable (not too high)
        assert offer.confidence <= 0.9, f"OCR confidence too high: {offer.confidence}"
        assert offer.confidence >= 0.3, f"OCR confidence too low: {offer.confidence}"


def test_ocr_parser_multi_page_merge():
    """Test OCR parser merges results from multiple pages."""
    parser = OcrParser()
    
    # Mock multi-page OCR output
    page1_text = "Apfel 1,99 €\nBirne 2,49 €"
    page2_text = "Orange 0,99 €\nBanane 1,29 €"
    
    offers1 = parser._extract_from_text(page1_text, page_num=1)
    offers2 = parser._extract_from_text(page2_text, page_num=2)
    
    all_offers = offers1 + offers2
    
    # Should have offers from both pages
    assert len(all_offers) >= 2, f"Expected at least 2 offers, got {len(all_offers)}"
    
    # Check source pages
    page_numbers = {offer.source_page for offer in all_offers}
    assert 1 in page_numbers, "Should have offers from page 1"
    assert 2 in page_numbers, "Should have offers from page 2"


def test_ocr_parser_handles_empty_text():
    """Test OCR parser handles empty OCR text."""
    parser = OcrParser()
    
    offers = parser._extract_from_text("", page_num=1)
    
    assert isinstance(offers, list), "Should return a list"
    assert len(offers) == 0, "Empty text should return empty list"


def test_ocr_parser_extracts_price():
    """Test OCR parser extracts prices correctly."""
    parser = OcrParser()
    
    test_cases = [
        ("Apfel 1,99 €", "1,99 €"),
        ("Birne 2.49 €", "2.49 €"),
        ("Orange 0,99", "0,99"),
    ]
    
    for text, expected_pattern in test_cases:
        offer = parser._line_to_offer(text, page_num=1)
        if offer and offer.price:
            # Price should contain digits and € or be numeric
            assert any(char.isdigit() for char in offer.price), \
                f"Price should contain digits: {offer.price}"


def test_ocr_parser_filters_invalid_offers():
    """Test OCR parser filters invalid offers."""
    parser = OcrParser()
    
    # Text with junk
    junk_text = "QR Code: https://example.com 1,99 €"
    
    offers = parser._extract_from_text(junk_text, page_num=1)
    
    # Should filter out junk
    for offer in offers:
        if offer.title:
            assert "QR" not in offer.title.upper()
            assert "http" not in offer.title.lower()


def test_ocr_parser_page_sampling():
    """Test OCR parser uses intelligent page sampling."""
    parser = OcrParser()
    
    # Test page selection logic
    pages_15 = parser._select_pages_for_ocr(15, max_pages=None)
    assert len(pages_15) == 15, f"Should select all 15 pages, got {len(pages_15)}"
    
    pages_50 = parser._select_pages_for_ocr(50, max_pages=None)
    assert len(pages_50) <= 15, f"Should select max 15 pages, got {len(pages_50)}"
    assert 0 in pages_50, "Should include first page"
    assert 49 in pages_50 or 48 in pages_50 or 47 in pages_50, "Should include last pages"


def test_ocr_parser_confidence_minimum():
    """Test OCR parser enforces minimum confidence."""
    parser = OcrParser()
    
    test_text = "Product 1,99 €"
    offer = parser._line_to_offer(test_text, page_num=1)
    
    if offer:
        assert offer.confidence >= 0.3, f"Confidence below minimum: {offer.confidence}"
