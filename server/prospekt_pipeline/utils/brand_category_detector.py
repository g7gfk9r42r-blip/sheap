"""Detect brand names and categories from offer titles."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Optional, Tuple

from .logger import get_logger

LOGGER = get_logger("utils.brand_category")

# Category keywords (German)
CATEGORY_KEYWORDS = {
    "Dairy": ["milch", "käse", "joghurt", "quark", "sahne", "butter", "margarine"],
    "Meat": ["fleisch", "wurst", "schinken", "salami", "hackfleisch", "steak", "schnitzel", "huhn", "hähnchen", "rind", "schwein"],
    "Fruit": ["apfel", "banane", "orange", "erdbeere", "traube", "kiwi", "birne", "pfirsich"],
    "Vegetables": ["tomate", "gurke", "paprika", "zucchini", "brokkoli", "karotte", "möhre", "salat", "kohl"],
    "Beverages": ["wasser", "saft", "cola", "bier", "wein", "limonade", "tee", "kaffee"],
    "Bakery": ["brot", "brötchen", "kuchen", "croissant", "brezel", "toast"],
    "Frozen": ["tiefkühl", "frozen", "eis", "pizza", "fischstäbchen"],
    "Snacks": ["chips", "schokolade", "kekse", "nüsse", "cracker"],
    "Pantry": ["nudeln", "reis", "mehl", "zucker", "öl", "essig", "gewürz"],
}

# Common brand patterns
BRAND_PATTERNS = [
    re.compile(r'\b([A-Z][a-z]+)\s+(?:Bio|Premium|Classic|Original)', re.IGNORECASE),
    re.compile(r'\b([A-Z]{2,})\b'),  # Uppercase abbreviations
]


def detect_brand_and_category(title: str, brand_heuristics: Optional[dict] = None) -> Tuple[Optional[str], Optional[str]]:
    """Detect brand and category from offer title.
    
    Returns:
        Tuple of (brand, category)
    """
    if not title:
        return None, None
    
    title_lower = title.lower()
    
    # Detect brand
    brand = None
    
    # Check brand heuristics first
    if brand_heuristics:
        known_brands = brand_heuristics.get("brands", [])
        for known_brand in known_brands:
            if known_brand.lower() in title_lower:
                brand = known_brand
                break
    
    # Try pattern matching
    if not brand:
        for pattern in BRAND_PATTERNS:
            match = pattern.search(title)
            if match:
                potential_brand = match.group(1)
                # Filter out common words
                if potential_brand.lower() not in ["ab", "von", "bis", "und", "oder", "mit", "ohne"]:
                    brand = potential_brand
                    break
    
    # Detect category
    category = None
    best_match_score = 0
    
    for cat_name, keywords in CATEGORY_KEYWORDS.items():
        score = sum(1 for keyword in keywords if keyword in title_lower)
        if score > best_match_score:
            best_match_score = score
            category = cat_name
    
    if brand:
        LOGGER.debug("[BRAND] Detected brand: %s", brand)
    if category:
        LOGGER.debug("[CATEGORY] Detected category: %s", category)
    
    return brand, category

