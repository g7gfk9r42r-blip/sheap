"""Normalization helpers for offers."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List

from ..utils.exceptions import NormalizationError
from ..utils.logger import get_logger
from ..utils.offer_validator import is_valid_offer
from ..utils.validity_extractor import extract_validity_range
from ..utils.brand_category_detector import detect_brand_and_category
from .merge_results import MergedOffer

LOGGER = get_logger("pipeline.normalize")

BRAND_FILE = Path(__file__).resolve().parent.parent / "utils" / "brand_heuristics.json"


@dataclass
class NormalizedOffer:
    title: str
    price: float | None
    price_raw: str | None
    unit: str | None
    valid_from: str | None
    valid_to: str | None
    brand: str | None
    category: str | None
    source_page: int | None
    confidence: float
    source: str

    def to_dict(self) -> Dict:
        return {
            "title": self.title,
            "price": self.price,
            "price_raw": self.price_raw,
            "unit": self.unit,
            "valid_from": self.valid_from,
            "valid_to": self.valid_to,
            "brand": self.brand,
            "category": self.category,
            "source_page": self.source_page,
            "confidence": round(self.confidence, 2),
            "source": self.source,
        }


class Normalizer:
    """Cleans string values and ensures completeness."""

    def __init__(self) -> None:
        self.heuristics = self._load_heuristics()

    def _load_heuristics(self) -> Dict:
        try:
            with open(BRAND_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            LOGGER.warning("brand_heuristics.json missing; using defaults")
            return {"brands": [], "weak_suffixes": []}

    def normalize(self, offers: List[MergedOffer], source_text: str = "") -> List[Dict]:
        """Normalize merged offers to final format with brand/category/validity detection."""
        if not offers:
            LOGGER.warning("[NORMALIZE] No offers to normalize; returning empty list")
            return []
        
        # Extract validity range from source text (PDF/HTML)
        valid_from, valid_to = extract_validity_range(source_text) if source_text else (None, None)
        
        normalized: List[Dict] = []
        filtered_count = 0
        
        for offer in offers:
            # Skip if title is missing or too short
            if not offer.title or len(offer.title.strip()) < 3:
                filtered_count += 1
                continue
            
            title = self._normalize_title(offer.title)
            
            # Double-check normalized title
            if not title or len(title) < 3 or title == "unbenanntes angebot":
                filtered_count += 1
                continue
            
            price = self._parse_price(offer.price)
            price_raw = offer.price  # Keep original price string
            unit = self._extract_unit(offer.unit_price)
            
            # Validate offer before adding
            price_str = offer.price if offer.price else None
            if not is_valid_offer(title, price_str):
                filtered_count += 1
                LOGGER.debug("[NORMALIZE] Filtered invalid offer: %s", title[:50])
                continue
            
            # Additional quality check: if price is missing, title must be very descriptive
            if price is None and len(title.split()) < 2:
                filtered_count += 1
                LOGGER.debug("[NORMALIZE] Filtered offer without price and short title: %s", title[:50])
                continue
            
            # Detect brand and category
            brand, category = detect_brand_and_category(title, self.heuristics)
            
            # Extract source page if available
            source_page = offer.source_page
            if source_page is None and ":" in offer.source:
                # Format: "ocr:p5" or "pdf:p3"
                try:
                    page_part = offer.source.split(":")[-1]
                    if page_part.startswith("p"):
                        source_page = int(page_part[1:])
                except (ValueError, IndexError):
                    pass
            
            normalized.append(
                NormalizedOffer(
                    title=title,
                    price=price,
                    price_raw=price_raw,
                    unit=unit,
                    valid_from=valid_from,
                    valid_to=valid_to,
                    brand=brand,
                    category=category,
                    source_page=source_page,
                    confidence=round(offer.confidence, 2),
                    source=offer.source,
                ).to_dict()
            )
        
        if filtered_count > 0:
            LOGGER.warning("[NORMALIZE] Filtered %d invalid offers (QR-codes, URLs, junk)", filtered_count)
        
        # Sort alphabetically for deterministic output
        normalized.sort(key=lambda x: x.get("title", "").lower())
        
        LOGGER.info("[NORMALIZE] Normalized %d valid offers (from %d total)", len(normalized), len(offers))
        return normalized
    
    def _extract_unit(self, unit_price: str | None) -> str | None:
        """Extract unit from unit price string."""
        if not unit_price:
            return None
        
        # Extract unit from patterns like "1 kg = 9,98 €" or "9,98 €/kg"
        unit_match = re.search(r'(kg|l|L|g|ml|stück|stk)', unit_price, re.IGNORECASE)
        if unit_match:
            unit = unit_match.group(1).lower()
            # Normalize
            if unit in ["l", "L"]:
                return "L"
            elif unit in ["stück", "stk"]:
                return "Stück"
            else:
                return unit.upper()
        
        return None

    def _normalize_title(self, title: str) -> str:
        """Normalize title with aggressive cleaning and brand awareness."""
        if not title:
            return "unbenanntes angebot"
        
        clean = title.strip()
        
        # Remove leading/trailing special characters
        import re
        clean = re.sub(r'^[^\w]+|[^\w]+$', '', clean)
        
        # Remove multiple spaces
        clean = re.sub(r'\s+', ' ', clean)
        
        # Remove common OCR artifacts
        clean = clean.replace('|', 'l').replace('¦', 'l')
        clean = re.sub(r'([a-z])\s+([a-z])', r'\1\2', clean)  # Remove spaces in words
        
        # Remove isolated numbers at start/end (page numbers)
        clean = re.sub(r'^\d+\s+|\s+\d+$', '', clean)
        
        if not clean:
            return "unbenanntes angebot"
        
        words = clean.split()
        
        # Check for weak single-word titles
        if len(words) == 1 and words[0].lower() in self.heuristics.get("weak_suffixes", []):
            clean = f"angebot {clean}"
        
        # Remove generic suffixes
        for suffix in self.heuristics.get("weak_suffixes", []):
            if clean.lower().endswith(suffix.lower()):
                clean = clean[:-len(suffix)].strip()
        
        # Preserve brand names (capitalize known brands)
        result = clean.lower()
        for brand in self.heuristics.get("brands", []):
            if brand.lower() in result:
                # Keep brand capitalization
                result = result.replace(brand.lower(), brand)
        
        # Capitalize first letter of each word (except known brands)
        words = result.split()
        capitalized_words = []
        for word in words:
            if word.lower() in [b.lower() for b in self.heuristics.get("brands", [])]:
                capitalized_words.append(word)  # Keep brand as-is
            else:
                capitalized_words.append(word.capitalize())
        
        result = ' '.join(capitalized_words)
        
        # Final cleanup
        result = result.strip()
        if not result or len(result) < 3:
            return "unbenanntes angebot"
        
        return result

    def _parse_price(self, value: str | None) -> float | None:
        """Parse price string to float with comprehensive format support.
        
        Handles formats like:
        - "4,99 €" / "4.99 €"
        - "1 kg = 9,98 €" (extracts price after =)
        - "0,89" / "0.89"
        - "Ab 0,99€" / "Ab 0.99€"
        - "2 für 3€" (extracts 3€)
        - "1,39 ct" (converts cents to euros)
        - "per Stück" / "je kg" (handles unit prices)
        """
        if not value:
            return None
        
        # Extract price from "X für Y€" format
        multi_match = re.search(r'(\d+)\s*für\s*(\d+[\.,]\d{1,2})\s*€', value, re.IGNORECASE)
        if multi_match:
            value = f"{multi_match.group(2)} €"
        
        # Extract price from "Ab X€" format
        ab_match = re.search(r'ab\s*(\d+[\.,]\d{1,2})\s*€', value, re.IGNORECASE)
        if ab_match:
            value = f"{ab_match.group(1)} €"
        
        # Extract price from unit price format like "1 kg = 9,98 €"
        if "=" in value:
            value = value.split("=")[-1].strip()
        
        # Handle cents (ct) - convert to euros
        if re.search(r'\d+[\.,]\d*\s*ct', value, re.IGNORECASE):
            # Extract number and divide by 100
            ct_match = re.search(r'(\d+[\.,]\d*)', value)
            if ct_match:
                try:
                    cents = float(ct_match.group(1).replace(",", "."))
                    return cents / 100.0
                except ValueError:
                    pass
        
        # Remove currency symbols and whitespace
        stripped = value.replace("€", "").replace("EUR", "").replace("EURO", "").strip()
        
        # Remove unit indicators (kg, l, L, g, ml, stück, stk) if present
        stripped = re.sub(r'\s*(?:kg|l|L|g|ml|stück|stk|per|je)\s*', '', stripped, flags=re.IGNORECASE)
        
        # Handle German decimal format (comma)
        if "," in stripped and "." in stripped:
            # Count dots and commas to determine format
            dot_count = stripped.count(".")
            comma_count = stripped.count(",")
            if dot_count > comma_count:
                # Dots are thousands separators, comma is decimal
                stripped = stripped.replace(".", "").replace(",", ".")
            else:
                # Usually comma is decimal in German format
                stripped = stripped.replace(".", "").replace(",", ".")
        elif "," in stripped:
            stripped = stripped.replace(",", ".")
        
        try:
            price = float(stripped)
            # Validate reasonable price range
            if 0.01 <= price <= 10000.0:
                return price
            else:
                LOGGER.warning("[NORMALIZE] Price out of range: %s -> %f", value, price)
                return None
        except ValueError:
            LOGGER.warning("[NORMALIZE] Unable to parse price from '%s'", value)
            return None
