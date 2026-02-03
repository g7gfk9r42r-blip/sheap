"""Industrial-grade OCR parser with page sampling and block detection."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import List, Optional

import pypdfium2 as pdfium
from PIL import Image, ImageEnhance, ImageFilter
import pytesseract

from ..utils.logger import get_logger
from ..utils.ocr_cleaner import normalize_lines
from ..utils.offer_validator import is_valid_offer, clean_title, extract_product_name

LOGGER = get_logger("parsers.ocr")

PRICE_PATTERN = re.compile(r"\d+[\.,]\d{1,2}\s*€")
UNIT_PATTERN = re.compile(r"(?:1\s*(?:kg|l|L|g|ml)\s*=\s*)?(\d+[\.,]\d{1,2})\s*€")


@dataclass
class OcrOffer:
    title: Optional[str]
    price: Optional[str]
    unit_price: Optional[str]
    source_page: int
    confidence: float
    source: str = "ocr"


class OcrParser:
    """Industrial-grade OCR parser with intelligent page sampling."""

    def parse(self, pdf_bytes: bytes, max_pages: Optional[int] = None) -> List[OcrOffer]:
        """Process PDF with OCR using page sampling (10-15 pages max)."""
        LOGGER.fallback("[OCR] Running OCR on PDF (%d bytes)", len(pdf_bytes))

        try:
            pdf = pdfium.PdfDocument(pdf_bytes)
            total_pages = len(pdf)
            LOGGER.info("[OCR] PDF has %d pages", total_pages)
        except Exception as exc:
            LOGGER.error("[OCR] Failed to open PDF: %s", exc)
            return []

        # Intelligent page sampling: 10-15 pages max
        pages_to_process = self._select_pages_for_ocr(total_pages, max_pages)
        LOGGER.info("[OCR] Selected %d pages for OCR processing (sampling strategy)", len(pages_to_process))

        all_offers: List[OcrOffer] = []

        for page_num in pages_to_process:
            try:
                page = pdf[page_num]
                # Render page to image (150-200 DPI for speed)
                bitmap = page.render(scale=2.0)  # ~150 DPI equivalent
                pil_image = bitmap.to_pil()

                # Process with OCR
                offers = self._process_page(pil_image, page_num + 1)
                all_offers.extend(offers)
            except Exception as exc:
                LOGGER.debug("[OCR] Failed to process page %d: %s", page_num + 1, exc)
                continue

        # Deduplicate
        unique_offers = self._deduplicate(all_offers)

        LOGGER.fallback("[OCR] Recovered %d unique offers from %d pages", len(unique_offers), len(pages_to_process))
        return unique_offers

    def _select_pages_for_ocr(self, total_pages: int, max_pages: Optional[int]) -> List[int]:
        """Select 10-15 most relevant pages for OCR.
        
        Strategy:
        - First 5 pages (usually cover page + first offers)
        - Last 3 pages (usually last offers)
        - Every Nth page in between (sampling)
        """
        if max_pages is not None:
            return list(range(min(max_pages, total_pages)))

        if total_pages <= 15:
            # Small PDF: process all pages
            return list(range(total_pages))

        # Large PDF: sample 10-15 pages
        pages = []

        # First 5 pages
        pages.extend(range(min(5, total_pages)))

        # Last 3 pages
        if total_pages > 5:
            pages.extend(range(max(5, total_pages - 3), total_pages))

        # Sample middle pages (every Nth page)
        if total_pages > 8:
            middle_start = 5
            middle_end = total_pages - 3
            middle_range = middle_end - middle_start
            sample_interval = max(1, middle_range // 5)  # ~5 pages from middle

            for i in range(middle_start, middle_end, sample_interval):
                if i not in pages:
                    pages.append(i)

        # Limit to 15 pages max
        selected = sorted(set(pages))[:15]
        LOGGER.info("[OCR] Page sampling: %d pages selected from %d total", len(selected), total_pages)
        return selected

    def _process_page(self, image: Image.Image, page_num: int) -> List[OcrOffer]:
        """Process single page with OCR."""
        offers: List[OcrOffer] = []

        # Strategy 1: Standard preprocessing
        processed = self._preprocess(image, "standard")
        text = self._ocr_text(processed)
        if text:
            offers.extend(self._extract_from_text(text, page_num))

        # Strategy 2: Aggressive preprocessing (only if standard found < 3 offers)
        if len(offers) < 3:
            processed = self._preprocess(image, "aggressive")
            text = self._ocr_text(processed)
            if text:
                offers.extend(self._extract_from_text(text, page_num))

        return offers

    def _preprocess(self, image: Image.Image, strategy: str = "standard") -> Image.Image:
        """Preprocess image based on strategy."""
        if strategy == "standard":
            gray = image.convert("L")
            enhanced = ImageEnhance.Contrast(gray).enhance(2.0)
            return enhanced.filter(ImageFilter.MedianFilter(3))

        elif strategy == "aggressive":
            gray = image.convert("L")
            enhanced = ImageEnhance.Contrast(gray).enhance(3.0)
            denoised = enhanced.filter(ImageFilter.MedianFilter(5))
            return ImageEnhance.Sharpness(denoised).enhance(2.0)

        return image

    def _ocr_text(self, image: Image.Image) -> str:
        """Extract text using Tesseract OCR."""
        try:
            return pytesseract.image_to_string(image, lang="deu+eng")
        except Exception as exc:
            LOGGER.debug("[OCR] OCR failed: %s", exc)
            return ""

    def _extract_from_text(self, text: str, page_num: int) -> List[OcrOffer]:
        """Extract offers from OCR text."""
        if not text or len(text.strip()) < 10:
            return []

        offers: List[OcrOffer] = []
        lines = normalize_lines(text.splitlines())

        for line in lines:
            if PRICE_PATTERN.search(line):
                offer = self._line_to_offer(line, page_num)
                if offer and is_valid_offer(offer.title, offer.price):
                    offers.append(offer)

        return offers

    def _line_to_offer(self, line: str, page_num: int) -> Optional[OcrOffer]:
        """Convert OCR line to offer."""
        price = self._find_price(line)
        unit = self._find_unit(line)

        title = extract_product_name(line)
        if not title:
            title = clean_title(line)

        if not title or len(title) < 3:
            return None

        confidence = 0.5
        if price and unit:
            confidence = 0.7
        elif price:
            confidence = 0.6

        return OcrOffer(
            title=title[:200],
            price=price,
            unit_price=unit,
            source_page=page_num,
            confidence=confidence,
        )

    def _find_price(self, text: str) -> Optional[str]:
        """Find price in text."""
        match = PRICE_PATTERN.search(text)
        if match:
            price_str = match.group(0)
            try:
                price_val = float(price_str.replace("€", "").replace(",", ".").strip())
                if 0.01 <= price_val <= 10000.0:
                    return price_str
            except ValueError:
                pass
        return None

    def _find_unit(self, text: str) -> Optional[str]:
        """Find unit price in text."""
        match = re.search(r"1\s*(?:kg|l|L|g|ml)\s*=\s*(\d+[\.,]\d{1,2})\s*€", text, re.IGNORECASE)
        if match:
            unit = match.group(1)
            unit_type = re.search(r"1\s*(kg|l|L|g|ml)", text, re.IGNORECASE)
            unit_name = unit_type.group(1) if unit_type else "kg"
            return f"1 {unit_name} = {unit} €"
        return None

    def _deduplicate(self, offers: List[OcrOffer]) -> List[OcrOffer]:
        """Remove duplicate offers."""
        from difflib import SequenceMatcher

        unique: List[OcrOffer] = []
        seen_titles: set[str] = set()

        for offer in offers:
            if not offer.title:
                continue

            title_lower = offer.title.lower().strip()

            if title_lower in seen_titles:
                continue

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
