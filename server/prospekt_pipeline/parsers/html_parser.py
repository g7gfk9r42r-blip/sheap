"""HTML parsing logic using BeautifulSoup."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional

from bs4 import BeautifulSoup

from ..utils.logger import get_logger
from ..utils.offer_validator import is_valid_offer, clean_title

LOGGER = get_logger("parsers.html")
PRICE_PATTERN = re.compile(r"\d+[\.,]\d{2}\s*€")
UNIT_PATTERN = re.compile(r"\d+[\.,]\d{2}\s*(?:kg|l|L|g|ml)")


def _clean_text(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


@dataclass
class HtmlOffer:
    title: str
    price: Optional[str]
    unit_price: Optional[str]
    discount: Optional[str]
    confidence: float
    source_page: int = 1
    source: str = "html"


class HtmlParser:
    """Robust HTML parser that tolerates layout changes."""

    def __init__(self) -> None:
        self.price_hints = {"€", "eur", "price", "preis"}

    def parse(self, html: str) -> List[HtmlOffer]:
        soup = BeautifulSoup(html, "html.parser")
        candidates: List[HtmlOffer] = []

        LOGGER.info("[HTML] Parsing HTML content")

        # Supermarket-specific heuristics: Try multiple selectors
        offer_nodes = soup.select(
            '[data-testid="offer-card"], [data-testid="product"], [data-testid="item"], '
            '.offer-card, .product-card, .item-card, .card, '
            'article, [class*="offer"], [class*="product"], [class*="item"], '
            '[class*="angebot"], [class*="preis"], [id*="offer"], [id*="product"]'
        )
        
        if not offer_nodes:
            LOGGER.warning("[HTML] No offer nodes found; using supermarket-specific heuristics")
            # Supermarket-specific fallback: div/span with price classes
            price_containers = soup.select('div[class*="price"], span[class*="price"]')
            # Also find strong tags containing €
            strong_prices = [s for s in soup.find_all('strong') if '€' in s.get_text()]
            price_containers.extend(strong_prices)
            
            # Also check for images with alt text (product names)
            img_products = soup.find_all('img', alt=True)
            # Combine price/value blocks
            all_elements = soup.find_all(['li', 'div', 'span', 'p', 'td', 'tr', 'section'])
            offer_nodes = [elem for elem in all_elements if PRICE_PATTERN.search(elem.get_text())]
            
            # Add price containers
            offer_nodes.extend(price_containers)
            
            # Add image-based products (if they have nearby prices)
            for img in img_products:
                parent = img.find_parent(['div', 'li', 'article', 'section'])
                if parent and PRICE_PATTERN.search(parent.get_text()):
                    offer_nodes.append(parent)

        for node in offer_nodes:
            title = self._extract_title(node)
            price = self._extract_price(node)
            unit_price = self._extract_unit_price(node)
            discount = self._extract_discount(node)
            if not title:
                continue
            
            # Clean and validate title
            title = clean_title(title)
            if not title or len(title.strip()) < 3:
                continue
            
            # Additional validation: check for junk patterns
            if re.match(r'^[0-9\s\-\.]+$', title):  # Only numbers
                continue
            if re.match(r'^[A-Z0-9]{8,}$', title):  # Only uppercase codes
                continue
            
            if not is_valid_offer(title, price):
                continue
            
            # Confidence scoring: html base = 1.0, adjust based on completeness
            confidence = 1.0
            if price and unit_price:
                confidence = 1.0  # Perfect data
            elif price:
                confidence = 0.95  # Missing unit price
            else:
                confidence = 0.85  # Missing price
            
            # Penalty for very short titles
            if len(title.split()) < 2:
                confidence -= 0.05
            
            # Ensure minimum confidence
            confidence = max(0.5, min(confidence, 1.0))
            
            candidates.append(
                HtmlOffer(
                    title=title,
                    price=price,
                    unit_price=unit_price,
                    discount=discount,
                    confidence=confidence,
                )
            )

        LOGGER.info("[HTML] Extracted %d candidates", len(candidates))
        return candidates

    def _extract_title(self, node) -> Optional[str]:  # type: ignore[override]
        # Try image alt text first (supermarket-specific)
        img = node.find('img', alt=True)
        if img and img.get('alt'):
            alt_text = _clean_text(img.get('alt', ''))
            if alt_text and len(alt_text) > 3:
                return alt_text
        
        # Try standard selectors
        selectors = (
            '[data-testid="offer-title"]',
            '.offer-title',
            '.product-title',
            '.card__title',
            'h1, h2, h3, h4',
        )
        for selector in selectors:
            elem = node.select_one(selector)
            if elem and elem.get_text(strip=True):
                return _clean_text(elem.get_text())
        
        # Fallback: Extract from text (remove price)
        text = node.get_text(" ", strip=True)
        text = _clean_text(text)
        if text and len(text.split()) > 1:
            # Remove price patterns
            text = PRICE_PATTERN.sub("", text).strip()
            if text:
                return text.split(" €")[0][:140]
        return None

    def _extract_price(self, node) -> Optional[str]:
        # Supermarket-specific price extraction
        # Try div/span with price classes
        price_node = node.select_one(
            'div[class*="price"], span[class*="price"], strong:contains("€"), '
            '.price, .offer-price, .price__value, .price-value, '
            '[data-testid="price"], [class*="preis"], '
            '[data-price], [itemprop="price"]'
        )
        if price_node and price_node.get_text(strip=True):
            text = _clean_text(price_node.get_text())
            match = PRICE_PATTERN.search(text)
            if match:
                return match.group(0)
        
        # Fallback: Search in entire node text
        text = node.get_text(" ", strip=True)
        # Find all prices and take first valid one
        matches = PRICE_PATTERN.findall(text)
        if matches:
            # Validate prices (between 0.01 and 10000)
            for match in matches:
                try:
                    price_val = float(match.replace("€", "").replace(",", ".").strip())
                    if 0.01 <= price_val <= 10000.0:
                        return match
                except ValueError:
                    continue
        return None

    def _extract_unit_price(self, node) -> Optional[str]:
        # Sehr aggressive Unit-Preis-Suche
        unit = node.select_one(
            '.unit-price, .price__per, .price-per, '
            '[data-testid="price-unit"], [class*="unit"], [class*="pro"], '
            '[class*="je"], [class*="kg"], [class*="liter"]'
        )
        if unit and unit.get_text(strip=True):
            text = _clean_text(unit.get_text())
            match = UNIT_PATTERN.search(text)
            if match:
                return match.group(0)
        
        # Fallback: Suche im gesamten Node-Text
        text = node.get_text(" ", strip=True)
        # Suche nach "1 kg = X,XX €" Pattern
        unit_match = re.search(r"1\s*(?:kg|l|L|g|ml)\s*=\s*(\d+[\.,]\d{1,2})\s*€", text, re.IGNORECASE)
        if unit_match:
            unit_type = re.search(r"1\s*(kg|l|L|g|ml)", text, re.IGNORECASE)
            unit_name = unit_type.group(1) if unit_type else "kg"
            return f"1 {unit_name} = {unit_match.group(1)} €"
        
        match = UNIT_PATTERN.search(text)
        return match.group(0) if match else None

    def _extract_discount(self, node) -> Optional[str]:
        badge = node.select_one('.badge, .discount, [data-testid="discount"]')
        if badge and badge.get_text(strip=True):
            return _clean_text(badge.get_text())
        return None
