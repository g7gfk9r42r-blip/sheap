"""Configuration for Grocify Scraper"""

from dataclasses import dataclass
from typing import Dict, List, Optional
from pathlib import Path


@dataclass
class SupermarketConfig:
    """Configuration for a single supermarket"""
    name: str
    has_pdf: bool
    has_list: bool
    pdf_url: Optional[str] = None
    pdf_pattern: Optional[str] = None  # Filename pattern for PDFs
    list_pattern: Optional[str] = None  # Filename pattern for lists
    loyalty_keywords: Dict[str, List[str]] = None  # Map condition types to keywords
    
    def __post_init__(self):
        if self.loyalty_keywords is None:
            self.loyalty_keywords = {
                "loyalty": ["k-card", "karte", "bonus", "payback", "treue"],
                "app": ["app", "digital", "online"],
                "membership": ["mitglied", "club", "plus"],
                "multi_buy": ["ab", "ab 2", "ab 3", "nur"],
            }


# Supermarket configurations
SUPERMARKETS = {
    "aldi_nord": SupermarketConfig(
        name="aldi_nord",
        has_pdf=True,
        has_list=True,
        loyalty_keywords={
            "loyalty": ["k-card"],
            "app": [],
            "multi_buy": ["ab"],
        }
    ),
    "aldi_sued": SupermarketConfig(
        name="aldi_sued",
        has_pdf=True,
        has_list=True,
        loyalty_keywords={
            "loyalty": ["k-card"],
            "app": [],
        }
    ),
    "biomarkt": SupermarketConfig(
        name="biomarkt",
        has_pdf=True,
        has_list=True,
    ),
    "edeka": SupermarketConfig(
        name="edeka",
        has_pdf=False,
        has_list=True,
    ),
    "kaufland": SupermarketConfig(
        name="kaufland",
        has_pdf=True,
        has_list=True,
        pdf_url="https://object.storage.eu01.onstackit.cloud/leaflets/pdfs/019b2c74-87c8-74ff-877e-16d069e65e1d/Prospekt-21-12-2025-24-12-2025-01.pdf",
        loyalty_keywords={
            "loyalty": ["k-card", "karte"],
            "app": [],
            "multi_buy": ["ab"],
        }
    ),
    "lidl": SupermarketConfig(
        name="lidl",
        has_pdf=True,
        has_list=False,
        loyalty_keywords={
            "loyalty": ["lidl plus"],
            "app": ["app"],
        }
    ),
    "nahkauf": SupermarketConfig(
        name="nahkauf",
        has_pdf=False,
        has_list=True,
    ),
    "netto": SupermarketConfig(
        name="netto",
        has_pdf=True,
        has_list=False,
    ),
    "norma": SupermarketConfig(
        name="norma",
        has_pdf=True,
        has_list=True,
    ),
    "penny": SupermarketConfig(
        name="penny",
        has_pdf=True,
        has_list=True,
    ),
    "rewe": SupermarketConfig(
        name="rewe",
        has_pdf=True,
        has_list=True,
        loyalty_keywords={
            "loyalty": ["rewe bonus", "bonus"],
            "app": ["app"],
        }
    ),
    "tegut": SupermarketConfig(
        name="tegut",
        has_pdf=True,
        has_list=False,
    ),
}


# Base paths
BASE_DIR = Path(__file__).parent.parent
SOURCES_DIR = BASE_DIR / "sources"
OUTPUT_DIR = BASE_DIR / "out"
REPORTS_DIR = OUTPUT_DIR / "reports"
OFFERS_DIR = OUTPUT_DIR / "offers"
RECIPES_DIR = OUTPUT_DIR / "recipes"


# Quality Gate thresholds
QUALITY_GATES = {
    "min_confidence": 0.5,
    "max_price_deviation": 0.5,  # 50% deviation from reference
    "min_title_length": 3,
    "max_title_length": 200,
    "max_price": 1000.0,  # Sanity check
    "min_price": 0.01,
}


# Flag definitions
FLAGS = {
    "AMBIGUOUS_PRICE": "Price could not be clearly determined",
    "MISSING_BRAND": "Brand information not found",
    "MULTI_PRICE_UNCLEAR": "Multiple prices found but unclear which is standard",
    "LOYALTY_WITHOUT_STANDARD": "Loyalty price found but no standard price",
    "INVALID_PRICE": "Price is invalid (negative, zero, or too high)",
    "MISSING_QUANTITY": "Quantity/unit information missing",
    "DUPLICATE_OFFER": "Duplicate offer detected",
    "LOW_CONFIDENCE": "Overall confidence below threshold",
    "ESTIMATED_NUTRITION": "Nutrition values are estimated",
    "MISSING_IMAGE": "No image URL available",
}

