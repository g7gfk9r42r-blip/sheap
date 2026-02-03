"""Shared fixtures for prospekt pipeline tests."""
from __future__ import annotations

import tempfile
from pathlib import Path
from typing import Generator

import pytest


@pytest.fixture
def temp_dir() -> Generator[Path, None, None]:
    """Create a temporary directory for test files."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def sample_html() -> str:
    """Sample HTML with 3 offers."""
    return """
    <html>
    <body>
        <div class="product-card">
            <h3>Milsani Joghurt</h3>
            <span class="price">1,99 €</span>
            <span class="unit">150g</span>
        </div>
        <div class="offer-item">
            <div class="product-title">Banane</div>
            <strong>0.79 €</strong>
            <span>pro kg</span>
        </div>
        <article>
            <img alt="Milch 1L" src="milk.jpg"/>
            <div class="price-value">2 49</div>
            <span>€</span>
        </article>
        <div class="empty-node"></div>
    </body>
    </html>
    """


@pytest.fixture
def sample_html_malformed() -> str:
    """HTML with malformed elements."""
    return """
    <div class="product">
        <span>Apfel</span>
        <span>1,29 €</span>
    </div>
    <div class="product">
        <span>Birne</span>
        <span>2,49 €</span>
    </div>
    <div class="product">
        <span>Orange</span>
        <span>0,99 €</span>
    </div>
    """


@pytest.fixture
def fake_pdf_bytes() -> bytes:
    """Minimal valid PDF bytes for testing."""
    # Minimal PDF structure (just header and basic structure)
    return b"""%PDF-1.4
1 0 obj
<<
/Type /Catalog
/Pages 2 0 R
>>
endobj
2 0 obj
<<
/Type /Pages
/Kids [3 0 R]
/Count 1
>>
endobj
3 0 obj
<<
/Type /Page
/Parent 2 0 R
/MediaBox [0 0 612 792]
/Contents 4 0 R
>>
endobj
4 0 obj
<<
/Length 44
>>
stream
BT
/F1 12 Tf
100 700 Td
(Milsani Joghurt 1,99 €) Tj
ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000009 00000 n
0000000058 00000 n
0000000115 00000 n
0000000206 00000 n
trailer
<<
/Size 5
/Root 1 0 R
>>
startxref
300
%%EOF"""


@pytest.fixture
def empty_pdf_bytes() -> bytes:
    """Empty/invalid PDF bytes."""
    return b""


@pytest.fixture
def sample_ocr_text() -> str:
    """Sample OCR output text."""
    return """
    Apfel 1,99 € / kg
    Birne 2,49 €
    Orange 0,99 € pro Stück
    """


@pytest.fixture
def dirty_text_lines() -> list[str]:
    """Dirty text lines for fallback parser."""
    return [
        "SUPER DEAL – MILSANI Joghurt 0.29 € 150g",
        "NOW ONLY 1 79",
        "Banane 0,99",
        "Milch 1,99 €",
        "Brot 2 49 €",
    ]


@pytest.fixture
def sample_offers_similar() -> list:
    """Sample offers with similar titles for merge testing."""
    from prospekt_pipeline.parsers.html_parser import HtmlOffer
    
    return [
        HtmlOffer(
            title="Milsani Joghurt",
            price="1,99 €",
            unit_price="1 kg = 13,27 €",
            discount=None,
            confidence=0.95,
        ),
        HtmlOffer(
            title="Milsani Jogurt",  # Typo
            price="1,99 €",
            unit_price=None,
            discount=None,
            confidence=0.90,
        ),
        HtmlOffer(
            title="MILSANI Joghurt 150g",  # Different case + unit
            price="1,99 €",
            unit_price="1 kg = 13,27 €",
            discount=None,
            confidence=1.0,
        ),
    ]


@pytest.fixture
def sample_price_strings() -> list[tuple[str, float | None]]:
    """Sample price strings and expected float values."""
    return [
        ("1,99 €", 1.99),
        ("1 79€", 1.79),
        ("3€", 3.00),
        ("100g = 0,39€", 0.39),
        ("2 für 3€", 3.00),
        ("Ab 0,99€", 0.99),
        ("1,39 ct", 0.0139),
        ("", None),
        (None, None),
    ]


@pytest.fixture
def sample_unit_strings() -> list[tuple[str | None, str | None]]:
    """Sample unit price strings and expected unit values."""
    return [
        ("1 kg = 9,98 €", "KG"),
        ("9,98 €/kg", "KG"),
        ("1 L = 1,29 €", "L"),
        ("1,29 €/L", "L"),
        ("150g", "G"),
        ("pro Stück", "Stück"),
        (None, None),
        ("", None),
    ]

