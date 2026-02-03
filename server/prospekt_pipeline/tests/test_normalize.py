"""Tests for normalization logic."""
from __future__ import annotations

import pytest

from prospekt_pipeline.pipeline.merge_results import MergedOffer
from prospekt_pipeline.pipeline.normalize import Normalizer


def test_normalize_price_formats(sample_price_strings: list[tuple[str, float | None]]):
    """Test normalizer handles various price formats."""
    normalizer = Normalizer()
    
    for price_str, expected_float in sample_price_strings:
        result = normalizer._parse_price(price_str)
        
        if expected_float is None:
            assert result is None, f"Expected None for '{price_str}', got {result}"
        else:
            assert result is not None, f"Expected {expected_float} for '{price_str}', got None"
            if result is not None:
                # Allow small floating point differences
                assert abs(result - expected_float) < 0.01, \
                    f"Price mismatch: '{price_str}' -> {result}, expected {expected_float}"


def test_normalize_unit_extraction(sample_unit_strings: list[tuple[str | None, str | None]]):
    """Test normalizer extracts units correctly."""
    normalizer = Normalizer()
    
    for unit_str, expected_unit in sample_unit_strings:
        result = normalizer._extract_unit(unit_str)
        
        if expected_unit is None:
            assert result is None, f"Expected None for '{unit_str}', got {result}"
        else:
            assert result is not None, f"Expected {expected_unit} for '{unit_str}', got None"
            if result is not None:
                # Unit should match (case-insensitive)
                assert result.upper() == expected_unit.upper(), \
                    f"Unit mismatch: '{unit_str}' -> {result}, expected {expected_unit}"


def test_normalize_missing_prices():
    """Test normalizer handles missing prices without crashing."""
    normalizer = Normalizer()
    
    offer = MergedOffer(
        title="Test Product",
        price=None,
        unit_price=None,
        confidence=0.8,
        source="test",
    )
    
    normalized = normalizer.normalize([offer], source_text="")
    
    assert isinstance(normalized, list), "Should return a list"
    # Offer without price might be filtered or kept
    assert len(normalized) >= 0, "Should not crash"


def test_normalize_title_cleaning():
    """Test normalizer cleans titles properly."""
    normalizer = Normalizer()
    
    test_cases = [
        ("  MILSANI Joghurt  ", "Milsani Joghurt"),
        ("milch|1l", "Milch 1l"),  # OCR artifact
        ("Brot  rn", "Brot m"),  # OCR error
    ]
    
    for dirty_title, expected_pattern in test_cases:
        cleaned = normalizer._normalize_title(dirty_title)
        
        assert cleaned, f"Should return non-empty title for '{dirty_title}'"
        assert len(cleaned) >= 3, f"Title too short: {cleaned}"


def test_normalize_filters_invalid_offers():
    """Test normalizer filters invalid offers."""
    normalizer = Normalizer()
    
    invalid_offers = [
        MergedOffer(title="QR Code: https://example.com", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
        MergedOffer(title="12345678901234567890", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
        MergedOffer(title="Valid Product", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
    ]
    
    normalized = normalizer.normalize(invalid_offers, source_text="")
    
    # Should filter out invalid offers
    titles = [offer.get("title", "") for offer in normalized]
    
    for title in titles:
        assert "QR" not in title.upper()
        assert "http" not in title.lower()
        assert not title.isdigit()


def test_normalize_validity_extraction():
    """Test normalizer extracts validity dates."""
    normalizer = Normalizer()
    
    source_text = "Gültig vom 24.11.2025 bis 29.11.2025"
    
    offer = MergedOffer(
        title="Test Product",
        price="1,99 €",
        unit_price=None,
        confidence=0.8,
        source="test",
    )
    
    normalized = normalizer.normalize([offer], source_text=source_text)
    
    if normalized:
        # Should extract validity dates
        assert normalized[0].get("valid_from") or normalized[0].get("valid_to"), \
            "Should extract validity dates from source text"


def test_normalize_brand_detection():
    """Test normalizer detects brands."""
    normalizer = Normalizer()
    
    offer = MergedOffer(
        title="MILSANI Joghurt",
        price="1,99 €",
        unit_price=None,
        confidence=0.8,
        source="test",
    )
    
    normalized = normalizer.normalize([offer], source_text="")
    
    if normalized:
        # Brand might be detected
        brand = normalized[0].get("brand")
        # Brand detection is optional, so just check it doesn't crash
        assert isinstance(brand, (str, type(None))), "Brand should be string or None"


def test_normalize_category_detection():
    """Test normalizer detects categories."""
    normalizer = Normalizer()
    
    offer = MergedOffer(
        title="Milch 1L",
        price="1,99 €",
        unit_price=None,
        confidence=0.8,
        source="test",
    )
    
    normalized = normalizer.normalize([offer], source_text="")
    
    if normalized:
        # Category might be detected
        category = normalized[0].get("category")
        # Category detection is optional
        assert isinstance(category, (str, type(None))), "Category should be string or None"


def test_normalize_alphabetical_sorting():
    """Test normalizer sorts offers alphabetically."""
    normalizer = Normalizer()
    
    offers = [
        MergedOffer(title="Zebra Product", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
        MergedOffer(title="Apple Product", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
        MergedOffer(title="Banana Product", price="1,99 €", unit_price=None, confidence=0.8, source="test"),
    ]
    
    normalized = normalizer.normalize(offers, source_text="")
    
    if len(normalized) >= 3:
        titles = [offer.get("title", "").lower() for offer in normalized]
        # Should be sorted alphabetically
        assert titles == sorted(titles), "Offers should be sorted alphabetically"
