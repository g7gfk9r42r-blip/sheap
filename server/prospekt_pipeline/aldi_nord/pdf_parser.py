"""PDF parser for ALDI Nord prospekt using pdfminer."""
from __future__ import annotations

import re
from pathlib import Path
from typing import List, Optional

try:
    from pdfminer.high_level import extract_text
except ImportError:
    print("[PDF] pdfminer not installed. PDF parsing disabled.")
    extract_text = None

from .models import Offer


class AldiNordPdfParser:
    """PDF parser for ALDI Nord prospekt."""

    def parse(self, pdf_path: Path) -> List[Offer]:
        """Parse PDF file and extract offers."""
        if not pdf_path.exists() or extract_text is None:
            return []

        try:
            text = extract_text(str(pdf_path))
            if not text or len(text) < 100:
                return []

            offers = []
            lines = text.split("\n")

            current_title = None
            current_price = None
            current_price_raw = None

            for i, line in enumerate(lines):
                line = line.strip()
                if not line:
                    continue

                # Look for price patterns
                price_match = re.search(r"(\d+[\.,]\d{1,2})\s*€", line)
                if price_match:
                    price_str = price_match.group(1).replace(",", ".")
                    try:
                        price = float(price_str)
                        if 0.01 <= price <= 200:
                            current_price = price
                            current_price_raw = price_match.group(0)

                            # Look for title in previous lines
                            if not current_title:
                                for j in range(max(0, i - 3), i):
                                    prev_line = lines[j].strip()
                                    if len(prev_line) >= 3 and not re.match(r"^\d+[\.,]\d+", prev_line):
                                        current_title = prev_line
                                        break

                            if current_title:
                                offer = Offer(
                                    title=current_title,
                                    price=current_price,
                                    price_raw=current_price_raw,
                                    confidence=0.6,
                                    source="pdf",
                                )
                                offers.append(offer)
                                current_title = None
                                current_price = None
                                current_price_raw = None
                    except ValueError:
                        pass
                else:
                    # Potential title line
                    if len(line) >= 3 and not re.match(r"^\d+[\.,]\d+", line):
                        current_title = line

            # Deduplicate
            seen = set()
            unique_offers = []
            for offer in offers:
                key = offer.title.lower() if offer.title else ""
                if key and key not in seen:
                    seen.add(key)
                    unique_offers.append(offer)

            return unique_offers[:200]  # Limit to 200 offers

        except Exception as e:
            print(f"[PDF] Error parsing {pdf_path}: {e}")
            return []

