"""Build baseline offers JSON from HTML and PDF for Vision AI reference."""
from __future__ import annotations

import json
from pathlib import Path
from typing import List

from .html_parser import AldiNordHtmlParser
from .models import Offer
from .pdf_parser import AldiNordPdfParser


class BaselineBuilder:
    """Build baseline offers from HTML and PDF for Vision AI reference."""

    def __init__(self):
        """Initialize baseline builder."""
        self.html_parser = AldiNordHtmlParser()
        self.pdf_parser = AldiNordPdfParser()

    def build_baseline(self, folder: Path) -> List[Offer]:
        """Build baseline offers from HTML and PDF."""
        baseline = []

        # 1. Parse HTML
        html_path = folder / "raw.html"
        if html_path.exists():
            html_offers = self.html_parser.parse(html_path)
            baseline.extend(html_offers)
            print(f"[BASELINE] HTML: {len(html_offers)} offers")

        # 2. Parse PDF Text Layer
        pdf_path = folder / "raw.pdf"
        if pdf_path.exists():
            pdf_offers = self.pdf_parser.parse(pdf_path)
            baseline.extend(pdf_offers)
            print(f"[BASELINE] PDF: {len(pdf_offers)} offers")

        # 3. Deduplicate
        baseline = self._deduplicate(baseline)
        print(f"[BASELINE] Total unique: {len(baseline)} offers")

        return baseline

    def save_baseline(self, folder: Path, offers: List[Offer]) -> Path:
        """Save baseline to JSON file."""
        baseline_path = folder / "baseline_offers.json"

        # Convert to dict
        offers_data = [offer.to_dict() for offer in offers]

        baseline_data = {
            "baseline_offers": offers_data,
            "total_count": len(offers_data),
            "sources": list(set(offer.source for offer in offers)),
        }

        baseline_path.write_text(
            json.dumps(baseline_data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        print(f"[BASELINE] Saved to {baseline_path.name}")
        return baseline_path

    def load_baseline(self, baseline_path: Path) -> List[Offer]:
        """Load baseline from JSON file."""
        if not baseline_path.exists():
            return []

        data = json.loads(baseline_path.read_text(encoding="utf-8"))
        offers_data = data.get("baseline_offers", [])

        offers = []
        for item in offers_data:
            offer = Offer(
                title=item.get("title", ""),
                price=item.get("price"),
                price_raw=item.get("price_raw"),
                unit=item.get("unit"),
                brand=item.get("brand"),
                category=item.get("category"),
                confidence=item.get("confidence", 0.5),
                source=item.get("source", "baseline"),
                source_page=item.get("source_page"),
            )
            offers.append(offer)

        return offers

    def _deduplicate(self, offers: List[Offer]) -> List[Offer]:
        """Simple deduplication by title."""
        seen = set()
        unique = []
        for offer in offers:
            key = offer.title.lower().strip() if offer.title else ""
            if key and key not in seen:
                seen.add(key)
                unique.append(offer)
        return unique

