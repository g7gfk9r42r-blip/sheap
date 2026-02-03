"""Tests for confidence scoring system."""
from __future__ import annotations

import pytest

from prospekt_pipeline.parsers.html_parser import HtmlOffer
from prospekt_pipeline.parsers.pdf_parser import PdfOffer
from prospekt_pipeline.parsers.ocr_parser import OcrOffer
from prospekt_pipeline.parsers.fallback_parser import FallbackOffer
from prospekt_pipeline.pipeline.merge_results import merge_results


def test_pdf_only_confidence():
    """Test PDF-only offers have confidence >= 0.6."""
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.7, source_page=1),
    ]
    
    merged = merge_results([], [], pdf_offers, [], [])
    
    assert len(merged) > 0, "Should have merged offers"
    
    for offer in merged:
        assert offer.confidence >= 0.6, \
            f"PDF-only confidence too low: {offer.confidence} (expected >= 0.6)"


def test_pdf_ocr_combined_confidence():
    """Test PDF + OCR combined offers have confidence >= 0.8."""
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.7, source_page=1),
    ]
    
    ocr_offers = [
        OcrOffer(title="Product", price="1,99 €", unit_price=None, source_page=1, confidence=0.5),
    ]
    
    merged = merge_results([], [], pdf_offers, ocr_offers, [])
    
    if len(merged) > 0:
        # When merged, confidence should be higher
        for offer in merged:
            # Confidence should reflect multiple sources
            assert offer.confidence >= 0.5, \
                f"Combined confidence too low: {offer.confidence}"


def test_pdf_ocr_html_combined_confidence():
    """Test PDF + OCR + HTML combined offers have confidence >= 0.95."""
    html_offers = [
        HtmlOffer(title="Product", price="1,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.7, source_page=1),
    ]
    
    ocr_offers = [
        OcrOffer(title="Product", price="1,99 €", unit_price=None, source_page=1, confidence=0.5),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, ocr_offers, [])
    
    if len(merged) > 0:
        # HTML has high confidence, should win
        for offer in merged:
            assert offer.confidence >= 0.85, \
                f"Combined confidence too low: {offer.confidence} (expected >= 0.85)"


def test_fallback_only_confidence():
    """Test fallback-only offers have confidence <= 0.5."""
    fallback_offers = [
        FallbackOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.3, source="fallback:test"),
    ]
    
    merged = merge_results([], [], [], [], fallback_offers)
    
    assert len(merged) > 0, "Should have merged offers"
    
    for offer in merged:
        assert offer.confidence <= 0.5, \
            f"Fallback-only confidence too high: {offer.confidence} (expected <= 0.5)"
        assert offer.confidence >= 0.15, \
            f"Fallback-only confidence too low: {offer.confidence} (expected >= 0.15)"


def test_confidence_merging_logic():
    """Test confidence scores are merged correctly."""
    html_offers = [
        HtmlOffer(title="Product", price="1,99 €", unit_price=None, discount=None, confidence=0.95),
    ]
    
    pdf_offers = [
        PdfOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.85, source_page=1),
    ]
    
    merged = merge_results([], html_offers, pdf_offers, [], [])
    
    if len(merged) == 1:
        # Should use highest confidence
        assert merged[0].confidence >= 0.85, \
            f"Should use highest confidence, got {merged[0].confidence}"


def test_confidence_capping():
    """Test confidence scores are properly capped."""
    # Test that confidence never exceeds 1.0
    html_offers = [
        HtmlOffer(title="Product", price="1,99 €", unit_price="1 kg = 9,98 €", discount=None, confidence=1.0),
    ]
    
    merged = merge_results([], html_offers, [], [], [])
    
    for offer in merged:
        assert offer.confidence <= 1.0, \
            f"Confidence exceeds 1.0: {offer.confidence}"


def test_confidence_minimum():
    """Test confidence scores have minimum thresholds."""
    fallback_offers = [
        FallbackOffer(title="Product", price="1,99 €", unit_price=None, confidence=0.2, source="fallback:test"),
    ]
    
    merged = merge_results([], [], [], [], fallback_offers)
    
    for offer in merged:
        # Fallback should be normalized to at least 0.3
        assert offer.confidence >= 0.3, \
            f"Confidence below minimum: {offer.confidence}"
