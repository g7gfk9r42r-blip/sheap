"""HTML parser for ALDI Nord prospekt pages."""
from __future__ import annotations

import re
from pathlib import Path
from typing import List, Optional

from bs4 import BeautifulSoup

from .models import Offer


class AldiNordHtmlParser:
    """Specialized HTML parser for ALDI Nord prospekt structure."""

    def parse(self, html_path: Path) -> List[Offer]:
        """Parse HTML file and extract offers."""
        if not html_path.exists():
            return []

        try:
            with open(html_path, "r", encoding="utf-8") as f:
                html_content = f.read()

            soup = BeautifulSoup(html_content, "html.parser")
            offers = []

            # Try multiple selectors for ALDI Nord structure
            selectors = [
                soup.find_all("div", class_=re.compile(r"product|offer|item|angebot", re.I)),
                soup.find_all("article", class_=re.compile(r"product|offer|item", re.I)),
                soup.find_all("li", class_=re.compile(r"product|offer|item", re.I)),
                soup.find_all("div", {"data-product": True}),
            ]

            seen_titles = set()

            for selector_results in selectors:
                for element in selector_results:
                    offer = self._extract_offer_from_element(element)
                    if offer and offer.title and offer.title.lower() not in seen_titles:
                        seen_titles.add(offer.title.lower())
                        offers.append(offer)

            # Fallback: search for price patterns in text
            if len(offers) < 5:
                offers.extend(self._extract_from_text(html_content))

            return offers[:200]  # Limit to 200 offers

        except Exception as e:
            print(f"[HTML] Error parsing {html_path}: {e}")
            return []

    def _extract_offer_from_element(self, element) -> Optional[Offer]:
        """Extract offer from a single HTML element."""
        text = element.get_text(separator=" ", strip=True)

        # Extract title (usually first meaningful text)
        title = self._extract_title(element, text)
        if not title or len(title) < 3:
            return None

        # Extract price
        price_raw, price = self._extract_price(text)

        # Extract unit
        unit = self._extract_unit(text)

        # Extract brand
        brand = self._extract_brand(title, text)

        # Extract category
        category = self._extract_category(title, text)

        return Offer(
            title=title,
            price=price,
            price_raw=price_raw,
            unit=unit,
            brand=brand,
            category=category,
            confidence=0.8 if price else 0.5,
            source="html",
        )

    def _extract_title(self, element, text: str) -> Optional[str]:
        """Extract product title."""
        # Try heading tags first
        for tag in ["h1", "h2", "h3", "h4", "strong", "b"]:
            heading = element.find(tag)
            if heading:
                title = heading.get_text(strip=True)
                if len(title) >= 3:
                    return title

        # Try data attributes
        for attr in ["data-title", "data-product", "title", "alt"]:
            title = element.get(attr)
            if title and len(title) >= 3:
                return title.strip()

        # Extract from text (first line before price)
        lines = text.split("\n")
        for line in lines[:3]:
            line = line.strip()
            if len(line) >= 3 and not re.match(r"^\d+[\.,]\d+", line):
                return line

        return None

    def _extract_price(self, text: str) -> tuple[Optional[str], Optional[float]]:
        """Extract price from text."""
        # Patterns: "1,99 €", "1.99€", "1 99", "EUR 1,99"
        patterns = [
            r"(\d+[\.,]\d{1,2})\s*€",
            r"€\s*(\d+[\.,]\d{1,2})",
            r"EUR\s*(\d+[\.,]\d{1,2})",
            r"(\d+)\s+(\d{2})\s*€",  # "1 99 €"
        ]

        for pattern in patterns:
            match = re.search(pattern, text)
            if match:
                price_str = match.group(1) if len(match.groups()) == 1 else f"{match.group(1)}.{match.group(2)}"
                price_str = price_str.replace(",", ".")
                try:
                    price = float(price_str)
                    if 0.01 <= price <= 200:
                        return match.group(0), price
                except ValueError:
                    pass

        return None, None

    def _extract_unit(self, text: str) -> Optional[str]:
        """Extract unit from text."""
        unit_patterns = [
            (r"(\d+)\s*(?:kg|KG)", "kg"),
            (r"(\d+)\s*(?:g|G)(?!\w)", "g"),
            (r"(\d+)\s*(?:l|L|Liter)", "L"),
            (r"(\d+)\s*(?:ml|mL)", "ml"),
            (r"pro\s*(?:Stück|stk|Stk)", "Stück"),
        ]

        for pattern, unit in unit_patterns:
            if re.search(pattern, text, re.I):
                return unit

        return None

    def _extract_brand(self, title: str, text: str) -> Optional[str]:
        """Extract brand from title or text."""
        brands = [
            "Knorr", "Coca Cola", "Rama", "MILSANI", "Gut & Günstig",
            "Frosta", "Dr. Oetker", "Nestlé", "Milka", "Haribo",
        ]

        combined = f"{title} {text}".lower()
        for brand in brands:
            if brand.lower() in combined:
                return brand

        return None

    def _extract_category(self, title: str, text: str) -> Optional[str]:
        """Extract category from keywords."""
        categories = {
            "Fleisch": ["fleisch", "wurst", "schinken", "salami", "hackfleisch"],
            "Obst": ["apfel", "banane", "orange", "erdbeere", "traube"],
            "Gemüse": ["tomate", "gurke", "paprika", "karotte", "zwiebel"],
            "Tiefkühl": ["tiefkühl", "frozen", "tiefkühltruhe"],
            "Milchprodukte": ["milch", "joghurt", "käse", "quark", "sahne"],
            "Getränke": ["getränk", "saft", "wasser", "cola", "bier"],
        }

        combined = f"{title} {text}".lower()
        for category, keywords in categories.items():
            if any(kw in combined for kw in keywords):
                return category

        return None

    def _extract_from_text(self, html_content: str) -> List[Offer]:
        """Fallback: extract offers from raw text."""
        offers = []
        lines = html_content.split("\n")

        for i, line in enumerate(lines):
            line = line.strip()
            if len(line) < 10:
                continue

            # Look for price patterns
            price_match = re.search(r"(\d+[\.,]\d{1,2})\s*€", line)
            if price_match:
                # Extract title (text before price)
                title = line[:price_match.start()].strip()
                if len(title) >= 3:
                    price_str = price_match.group(1).replace(",", ".")
                    try:
                        price = float(price_str)
                        if 0.01 <= price <= 200:
                            offers.append(Offer(
                                title=title,
                                price=price,
                                price_raw=price_match.group(0),
                                confidence=0.4,
                                source="html_text",
                            ))
                    except ValueError:
                        pass

        return offers[:50]  # Limit fallback results

