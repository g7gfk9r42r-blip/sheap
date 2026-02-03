"""Main processor for ALDI Nord prospekt parsing."""
from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import List

from .baseline_builder import BaselineBuilder
from .html_parser import AldiNordHtmlParser
from .images_vision_parser import AldiNordVisionParser
from .merge_offers import merge_offers
from .models import Offer
from .normalize import OfferNormalizer
from .pdf_parser import AldiNordPdfParser
from .reference_vision_parser import ReferenceVisionParser
from .validator import OfferValidator


class AldiNordProcessor:
    """Orchestrates the complete ALDI Nord parsing process."""

    def __init__(self):
        """Initialize processor with all parsers."""
        self.html_parser = AldiNordHtmlParser()
        self.pdf_parser = AldiNordPdfParser()
        self.vision_parser = AldiNordVisionParser()
        self.baseline_builder = BaselineBuilder()
        self.reference_vision_parser = ReferenceVisionParser()
        self.normalizer = OfferNormalizer()
        self.validator = OfferValidator()

    def process(self, folder: Path) -> dict:
        """Process a single ALDI Nord prospekt folder."""
        print(f"\n{'='*60}")
        print(f"[ALDI NORD] Processing: {folder.name}")
        print(f"{'='*60}")

        # Check if folder has required files
        html_path = folder / "raw.html"
        
        # Find PDF files (can be raw.pdf or any .pdf file)
        pdf_path = None
        if (folder / "raw.pdf").exists():
            pdf_path = folder / "raw.pdf"
        else:
            # Find all PDF files and pick the best one
            pdf_files = list(folder.glob("*.pdf"))
            if pdf_files:
                # Prefer files with "promotion" or "angebot" in name (better quality)
                preferred = [f for f in pdf_files if any(keyword in f.name.lower() for keyword in ["promotion", "angebot", "cw"])]
                if preferred:
                    pdf_path = preferred[0]
                    print(f"[ALDI NORD] Found preferred PDF: {pdf_path.name}")
                else:
                    pdf_path = pdf_files[0]
                    print(f"[ALDI NORD] Found PDF: {pdf_path.name}")
        
        images_dir = folder / "images"

        if not html_path.exists() and not pdf_path:
            print(f"[ALDI NORD] ⚠️  No HTML or PDF found. Skipping.")
            return self._write_empty_result(folder)

        # 1. Parse HTML (can be raw.html or any .html file)
        html_offers = []
        if html_path.exists():
            print(f"[HTML] Parsing {html_path.name}...")
            html_offers = self.html_parser.parse(html_path)
            print(f"[HTML] Extracted {len(html_offers)} offers")
        else:
            # Try to find any HTML file
            html_files = list(folder.glob("*.html"))
            if html_files:
                html_path = html_files[0]
                print(f"[HTML] Found HTML file: {html_path.name}")
                html_offers = self.html_parser.parse(html_path)
                print(f"[HTML] Extracted {len(html_offers)} offers")
            else:
                print(f"[HTML] ⚠️  No HTML file found, skipping")

        # 2. Parse PDF
        pdf_offers = []
        if pdf_path and pdf_path.exists():
            print(f"[PDF] Parsing {pdf_path.name}...")
            pdf_offers = self.pdf_parser.parse(pdf_path)
            print(f"[PDF] Extracted {len(pdf_offers)} offers")
        else:
            print(f"[PDF] ⚠️  No PDF found, skipping")

        # 3. Build baseline from HTML + PDF
        print(f"\n[BASELINE] Building baseline from HTML + PDF...")
        baseline_offers = self.baseline_builder.build_baseline(folder)
        baseline_path = self.baseline_builder.save_baseline(folder, baseline_offers)

        # 4. Vision AI with Reference (find missing offers)
        vision_offers = []
        if pdf_path and pdf_path.exists():
            print(f"\n[VISION] Finding missing offers with reference baseline...")
            print(f"[VISION] Baseline has {len(baseline_offers)} offers")
            print(f"[VISION] Using PDF: {pdf_path.name}")
            
            # Use Vision AI - process ALL pages to extract ALL offers
            vision_extracted = self.reference_vision_parser.process_all_pages(
                pdf_path,
                baseline_offers,  # Passed for reference, but we extract ALL offers
                max_pages=None,  # Process ALL pages - no limit!
                smart_sampling=False,  # Process every page for maximum coverage
            )
            vision_offers = vision_extracted
            print(f"[VISION] Extracted {len(vision_offers)} offers from all pages")
        else:
            # Fallback: use images directory if available
            if images_dir.exists() and images_dir.is_dir():
                print(f"[VISION] Using images directory (no PDF for reference)...")
                vision_offers = self.vision_parser.parse(images_dir)
                print(f"[VISION] Extracted {len(vision_offers)} offers")
            else:
                print(f"[VISION] ⚠️  No PDF or images found, skipping")

        # 5. Merge all offers (baseline + missing)
        print(f"\n[MERGE] Merging offers (baseline + missing)...")
        merged_offers = merge_offers(html_offers, pdf_offers, vision_offers, baseline_offers)
        print(f"[MERGE] Merged to {len(merged_offers)} unique offers")
        print(f"[MERGE]   - Baseline: {len(baseline_offers)}")
        print(f"[MERGE]   - Missing (Vision): {len(vision_offers)}")

        # 6. Normalize
        print(f"[NORMALIZE] Normalizing offers...")
        normalized_offers = self.normalizer.normalize(merged_offers)
        print(f"[NORMALIZE] Normalized {len(normalized_offers)} offers")

        # 7. Validate
        print(f"[VALIDATE] Validating offers...")
        validated_offers = self.validator.validate(normalized_offers)
        print(f"[VALIDATE] {len(validated_offers)} valid offers")

        # 8. Write results
        return self._write_results(folder, validated_offers)

    def _write_results(self, folder: Path, offers: List[Offer]) -> dict:
        """Write offers to JSON file."""
        output_path = folder / "offers.json"

        # Convert to dict
        offers_data = [offer.to_dict() for offer in offers]

        # Create output structure
        output = {
            "offers": offers_data,
            "metadata": {
                "folder": str(folder),
                "total_offers": len(offers_data),
                "extraction_date": datetime.now().isoformat(),
                "source": "aldi_nord_pipeline",
            }
        }

        # Write to file
        try:
            output_path.write_text(
                json.dumps(output, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(f"\n✅ [ALDI NORD] Wrote {len(offers_data)} offers to {output_path.name}")
            print(f"📁 Path: {output_path}")
        except Exception as e:
            print(f"❌ [ALDI NORD] Failed to write results: {e}")

        return output

    def _write_empty_result(self, folder: Path) -> dict:
        """Write empty result when no source files found."""
        output_path = folder / "offers.json"
        output = {
            "offers": [],
            "metadata": {
                "folder": str(folder),
                "total_offers": 0,
                "extraction_date": datetime.now().isoformat(),
                "source": "aldi_nord_pipeline",
                "error": "No source files found",
            }
        }

        try:
            output_path.write_text(
                json.dumps(output, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            print(f"⚠️  [ALDI NORD] Wrote empty result to {output_path.name}")
        except Exception as e:
            print(f"❌ [ALDI NORD] Failed to write empty result: {e}")

        return output

