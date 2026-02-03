"""Industrial-grade PDF parser using pypdfium2 for stable text extraction."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional

import pypdfium2 as pdfium

from ..utils.logger import get_logger
from ..utils.offer_validator import is_valid_offer, clean_title, extract_product_name

LOGGER = get_logger("parsers.pdf")

# Extended patterns for robust price detection
PRICE_PATTERN = re.compile(r"\d+[\.,]\d{1,2}\s*€")
PRICE_PATTERN_STRICT = re.compile(r"\b\d{1,3}(?:[\.,]\d{2})?\s*€\b")
PRICE_PATTERN_ALT = re.compile(r"(?:ab|von|statt)\s*(\d+[\.,]\d{1,2})\s*€", re.IGNORECASE)
UNIT_PATTERN = re.compile(r"(?:1\s*(?:kg|l|L|g|ml)\s*=\s*)?(\d+[\.,]\d{1,2})\s*€")
UNIT_PATTERN_ALT = re.compile(r"(\d+[\.,]\d{1,2})\s*(?:€|EUR)\s*(?:pro|/|je)\s*(?:kg|l|L|g|ml|stück|stk)", re.IGNORECASE)
DISCOUNT_PATTERN = re.compile(r"(?:-\s*)?(\d+)\s*%|(\d+[\.,]\d{1,2})\s*€\s*sparen", re.IGNORECASE)
PRODUCT_PATTERN = re.compile(r"[A-ZÄÖÜ][a-zäöüß]+(?:\s+[A-ZÄÖÜ]?[a-zäöüß]+)*")


@dataclass
class PdfOffer:
    title: Optional[str]
    price: Optional[str]
    unit_price: Optional[str]
    confidence: float
    source_page: int = 1
    source: str = "pdf"


class PdfParser:
    """Industrial-grade PDF parser using pypdfium2."""

    def parse(self, pdf_bytes: bytes) -> List[PdfOffer]:
        """Parse PDF with pypdfium2 text extraction."""
        if not pdf_bytes or len(pdf_bytes) < 10:
            LOGGER.warning("[PDF] PDF too small or empty (%d bytes)", len(pdf_bytes))
            return []

        LOGGER.info("[PDF] Parsing PDF text layer (%d bytes)", len(pdf_bytes))

        try:
            pdf = pdfium.PdfDocument(pdf_bytes)
            total_pages = len(pdf)
            LOGGER.info("[PDF] PDF has %d pages", total_pages)
        except Exception as exc:
            LOGGER.error("[PDF] Failed to open PDF: %s", exc)
            return []

        all_offers: List[PdfOffer] = []

        # Extract text from all pages
        for page_num in range(total_pages):
            try:
                page = pdf[page_num]
                textpage = page.get_textpage()
                text = textpage.get_text_range()

                if text and len(text.strip()) > 10:
                    offers = self._extract_from_page_text(text, page_num + 1)  # 1-indexed for source_page
                    # Filter out None offers
                    valid_offers = [o for o in offers if o is not None]
                    all_offers.extend(valid_offers)
            except Exception as exc:
                LOGGER.debug("[PDF] Failed to extract text from page %d: %s", page_num + 1, exc)
                continue

        # Deduplicate
        unique_offers = self._deduplicate(all_offers)

        LOGGER.info("[PDF] Extracted %d unique offers (from %d candidates)", len(unique_offers), len(all_offers))
        return unique_offers

    def _extract_from_page_text(self, text: str, page_num: int) -> List[PdfOffer]:
        """Extract offers from page text using multiple strategies."""
        offers: List[PdfOffer] = []

        # Strategy 1: Line-by-line scanning
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        for i, line in enumerate(lines):
            if PRICE_PATTERN.search(line):
                # Build context: previous + current + next line
                context_lines = []
                if i > 0:
                    context_lines.append(lines[i - 1])
                context_lines.append(line)
                if i < len(lines) - 1:
                    context_lines.append(lines[i + 1])

                block = " ".join(context_lines)
                offer = self._block_to_offer(block, page_num)
                if offer and offer.title and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)

        # Strategy 2: Paragraph-based (empty lines as separators)
        paragraphs = re.split(r"\n\s*\n", text)
        for para in paragraphs:
            para = para.strip()
            if len(para) < 5:
                continue
            if PRICE_PATTERN.search(para):
                offer = self._block_to_offer(para, page_num)
                if offer and offer.title and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)

        # Strategy 3: Sliding window (3-5 lines context)
        for i in range(len(lines)):
            context_lines = lines[max(0, i - 2) : i + 3]
            block = " ".join(context_lines)

            if PRICE_PATTERN.search(block):
                offer = self._block_to_offer(block, page_num)
                if offer and offer.title and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)

        return offers

    def _block_to_offer(self, block: str, page_num: int = 1) -> Optional[PdfOffer]:
        """Convert text block to offer with careful extraction."""
        if not block or len(block.strip()) < 5:
            return None
        
        price = self._find_price(block)
        unit = self._find_unit(block)

        # Careful title extraction
        title = extract_product_name(block)
        if not title:
            # Fallback: manual extraction
            title = block
            if price:
                title = title.replace(price, "")
            if unit:
                title = title.replace(unit, "")
            # Remove discount patterns
            title = re.sub(r"-\s*\d+\s*%", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\d+[\.,]\d{1,2}\s*€\s*sparen", "", title, flags=re.IGNORECASE)
            # Remove common junk
            title = re.sub(r"(?:seite|page|p\.?)\s*\d+", "", title, flags=re.IGNORECASE)
            title = re.sub(r"\d+\.\d+\.\d+", "", title)  # Remove dates
            title = clean_title(title.strip())

        if not title or len(title) < 3:
            return None
        
        # Additional validation: check for junk patterns
        if re.match(r'^[0-9\s\-\.]+$', title):  # Only numbers
            return None
        if re.match(r'^[A-Z0-9]{8,}$', title):  # Only uppercase codes
            return None

        # Confidence scoring
        confidence = 0.7
        if price and unit:
            confidence = 0.85
        elif price:
            confidence = 0.75
        else:
            confidence = 0.5

        # Bonus for product keywords
        if re.search(r"\b(?:kg|g|ml|l|L|bio|frisch|frische|packung|pack)\b", title, re.IGNORECASE):
            confidence += 0.05
        
        # Penalty for very short titles
        if len(title.split()) < 2:
            confidence -= 0.1

        return PdfOffer(
            title=title[:200] if title else None,
            price=price,
            unit_price=unit,
            confidence=max(0.3, min(confidence, 1.0)),  # Ensure minimum confidence
            source_page=page_num,
        )

    def _find_price(self, text: str) -> Optional[str]:
        """Find price in text with multiple patterns."""
        # Try strict pattern first
        match = PRICE_PATTERN_STRICT.search(text)
        if match:
            price_str = match.group(0)
            if self._validate_price(price_str):
                return price_str

        # Try alternative pattern
        match = PRICE_PATTERN_ALT.search(text)
        if match:
            price_str = f"{match.group(1)} €"
            if self._validate_price(price_str):
                return price_str

        # Fallback to standard pattern
        match = PRICE_PATTERN.search(text)
        if match:
            price_str = match.group(0)
            if self._validate_price(price_str):
                return price_str

        return None

    def _validate_price(self, price_str: str) -> bool:
        """Validate price is in reasonable range."""
        try:
            price_val = float(price_str.replace("€", "").replace(",", ".").strip())
            return 0.01 <= price_val <= 10000.0
        except ValueError:
            return False

    def _find_unit(self, text: str) -> Optional[str]:
        """Find unit price in text with multiple patterns."""
        # Pattern 1: "1 kg = X,XX €"
        match = re.search(r"1\s*(?:kg|l|L|g|ml)\s*=\s*(\d+[\.,]\d{1,2})\s*€", text, re.IGNORECASE)
        if match:
            unit = match.group(1)
            unit_type = re.search(r"1\s*(kg|l|L|g|ml)", text, re.IGNORECASE)
            unit_name = unit_type.group(1) if unit_type else "kg"
            return f"1 {unit_name} = {unit} €"

        # Pattern 2: Standard unit pattern
        match = UNIT_PATTERN.search(text)
        if match:
            return match.group(0)

        # Pattern 3: Alternative format "X,XX €/kg"
        match = UNIT_PATTERN_ALT.search(text)
        if match:
            return match.group(0)

        return None

    def _deduplicate(self, offers: List[PdfOffer]) -> List[PdfOffer]:
        """Remove duplicate offers based on title similarity."""
        from difflib import SequenceMatcher

        unique: List[PdfOffer] = []
        seen_titles: set[str] = set()

        for offer in offers:
            if not offer.title:
                continue

            title_lower = offer.title.lower().strip()

            # Check for exact duplicate
            if title_lower in seen_titles:
                continue

            # Check for similar titles (85% similarity threshold)
            is_duplicate = False
            for seen in seen_titles:
                similarity = SequenceMatcher(None, title_lower, seen).ratio()
                if similarity > 0.85:
                    is_duplicate = True
                    break

            if not is_duplicate:
                unique.append(offer)
                seen_titles.add(title_lower)

        return unique
