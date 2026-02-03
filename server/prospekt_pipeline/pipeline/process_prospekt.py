"""Main orchestration module for processing a single prospekt folder."""
from __future__ import annotations

import json
from pathlib import Path
from typing import Dict

from ..parsers.html_parser import HtmlParser
from ..parsers.pdf_parser import PdfParser
from ..parsers.ocr_parser import OcrParser
from ..parsers.fallback_parser import FallbackParser
from ..parsers.json_parser import JsonParser
from ..ai.ai_pdf_parser import AIPDFParser
from ..utils import exceptions
from ..utils.file_loader import discover_files, load_binary, load_text
from ..utils.logger import get_logger
from .merge_results import merge_results
from .normalize import Normalizer
from .validate import Validator

LOGGER = get_logger("pipeline.processor")


class ProspektProcessor:
    """Self-healing processor that coordinates all parsers."""

    def __init__(self) -> None:
        self.html_parser = HtmlParser()
        self.pdf_parser = PdfParser()
        self.ocr_parser = OcrParser()
        self.fallback_parser = FallbackParser()
        self.json_parser = JsonParser()
        self.ai_parser = AIPDFParser()  # Premium Vision-AI parser
        self.normalizer = Normalizer()
        self.validator = Validator()

    def process(self, folder: Path) -> Dict:
        """Process a prospekt folder and generate offers.json."""
        LOGGER.info("Processing folder %s", folder)
        try:
            files = discover_files(folder)
            files.ensure_output_parent()
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("Failed to discover files: %s", exc)
            return self._write_empty_result(folder, str(exc))

        # Validate sources
        html_ok, pdf_ok = self.validator.validate(folder)

        # STRICT PRIORITY: HTML → JSON → PDF → OCR → Fallback
        
        # 1. HTML parsing (highest priority - structured data)
        html_offers = []
        html_content = None
        if html_ok:
            html_content = load_text(files.html)
            if html_content:
                try:
                    html_offers = self.html_parser.parse(html_content)
                    LOGGER.info("[HTML] Extracted %d offers", len(html_offers))
                except Exception as exc:  # noqa: BLE001
                    LOGGER.error("[HTML] Parsing failed: %s", exc)

        # 2. JSON parsing (existing structured data - second priority)
        json_offers = []
        if files.json and files.json.exists():
            try:
                json_content = load_text(files.json)
                if json_content:
                    json_offers = self.json_parser.parse(json_content, files.json)
                    LOGGER.info("[JSON] Extracted %d offers from existing file", len(json_offers))
            except Exception as exc:  # noqa: BLE001
                LOGGER.warning("[JSON] Parsing failed: %s", exc)

        # 3. PDF parsing (text layer extraction)
        pdf_offers = []
        pdf_bytes = None
        if pdf_ok:
            pdf_bytes = load_binary(files.pdf)
            if pdf_bytes:
                try:
                    pdf_offers = self.pdf_parser.parse(pdf_bytes)
                    LOGGER.info("[PDF] Extracted %d offers", len(pdf_offers))
                except Exception as exc:  # noqa: BLE001
                    LOGGER.error("[PDF] Parsing failed: %s", exc)

        # 3.5. AI Vision parsing (highest quality - premium extraction)
        ai_offers = []
        if pdf_ok and pdf_bytes:
            try:
                LOGGER.info("[AI] Starting Vision-AI parsing")
                # Use pdf_bytes if available, otherwise fall back to file path
                if files.pdf and files.pdf.exists():
                    ai_offers_raw = self.ai_parser.parse_pdf(pdf_path=files.pdf)
                else:
                    ai_offers_raw = self.ai_parser.parse_pdf(pdf_bytes=pdf_bytes)
                
                # Convert AI offers to standard format for merging
                from ..parsers.html_parser import HtmlOffer
                ai_offers = []
                for offer in ai_offers_raw:
                    if not isinstance(offer, dict) or not offer.get("title"):
                        continue
                    
                    # Format price for merging
                    price_str = offer.get("price_raw")
                    if not price_str and offer.get("price") is not None:
                        price_str = f"{offer.get('price'):.2f}".replace(".", ",") + " €"
                    
                    ai_offers.append(
                        HtmlOffer(
                            title=offer.get("title", ""),
                            price=price_str,
                            unit_price=offer.get("unit"),
                            discount=None,
                            confidence=min(1.0, max(0.95, offer.get("confidence", 0.95))),  # AI has high confidence
                        )
                    )
                
                LOGGER.info("[AI] Extracted %d offers via Vision-AI", len(ai_offers))
            except Exception as exc:  # noqa: BLE001
                LOGGER.error("[AI] Vision-AI parsing failed: %s", exc)

        # 4. OCR fallback (only if PDF parsing yielded < 30% of HTML results or < 5 offers)
        ocr_offers = []
        html_count = len(html_offers) if html_offers else 0
        pdf_count = len(pdf_offers)
        
        should_run_ocr = pdf_bytes and pdf_ok and (
            (html_count > 0 and pdf_count < html_count * 0.3) or 
            (html_count == 0 and pdf_count < 5)
        )
        
        if should_run_ocr:
            try:
                LOGGER.fallback("[OCR] PDF-Parsing yielded only %d offers, starting OCR", pdf_count)
                ocr_offers = self.ocr_parser.parse(pdf_bytes, max_pages=None)
                LOGGER.info("[OCR] Extracted %d offers", len(ocr_offers))
            except Exception as exc:  # noqa: BLE001
                LOGGER.error("[OCR] Parsing failed: %s", exc)
        else:
            LOGGER.info("[OCR] Skipped (PDF-Parsing yielded sufficient results: %d)", pdf_count)

        # 5. Fallback parser (last resort - text scavenging)
        # Run fallback if we have very few results OR no results at all
        total_results = html_count + pdf_count + len(json_offers) + len(ocr_offers)
        fallback_offers = []
        
        # Run fallback if:
        # - No results at all, OR
        # - Very few results (< 10) and we have source material
        should_run_fallback = (
            total_results == 0 or 
            (total_results < 10 and (html_content or pdf_bytes))
        )
        
        if should_run_fallback:
            LOGGER.fallback("[FALLBACK] Running fallback parser (total results: %d)", total_results)
            if html_content:
                try:
                    html_fallback = self.fallback_parser.text_scavenge(html_content.splitlines(), source="html")
                    fallback_offers.extend(html_fallback)
                    LOGGER.info("[FALLBACK] HTML scavenge found %d offers", len(html_fallback))
                except Exception as exc:  # noqa: BLE001
                    LOGGER.error("[FALLBACK] HTML text scavenge failed: %s", exc)
            if pdf_bytes:
                try:
                    # Use pypdfium2 for text extraction
                    import pypdfium2 as pdfium
                    pdf = pdfium.PdfDocument(pdf_bytes)
                    pdf_text_lines = []
                    # Extract from first 10 pages for speed
                    max_pages = min(10, len(pdf))
                    for page_num in range(max_pages):
                        try:
                            page = pdf[page_num]
                            textpage = page.get_textpage()
                            text = textpage.get_text_range()
                            if text:
                                pdf_text_lines.extend(text.splitlines())
                        except Exception:
                            continue
                    if pdf_text_lines:
                        pdf_fallback = self.fallback_parser.text_scavenge(pdf_text_lines, source="pdf")
                        fallback_offers.extend(pdf_fallback)
                        LOGGER.info("[FALLBACK] PDF scavenge found %d offers", len(pdf_fallback))
                except Exception as exc:  # noqa: BLE001
                    LOGGER.error("[FALLBACK] PDF text conversion failed: %s", exc)

        # Merge and normalize with strict priority
        try:
            # Strict priority order: AI → JSON → HTML → PDF → OCR → Fallback
            merged = merge_results(json_offers, html_offers, pdf_offers, ocr_offers, fallback_offers, ai_offers)
            
            # Combine source text for validity extraction
            source_text = ""
            if html_content:
                source_text += html_content[:5000]  # First 5000 chars
            if pdf_bytes:
                try:
                    import pypdfium2 as pdfium
                    pdf = pdfium.PdfDocument(pdf_bytes)
                    for page_num in range(min(3, len(pdf))):  # First 3 pages
                        try:
                            page = pdf[page_num]
                            textpage = page.get_textpage()
                            text = textpage.get_text_range()
                            source_text += text[:1000]  # First 1000 chars per page
                        except Exception:
                            continue
                except Exception:
                    pass
            
            payload = self.normalizer.normalize(merged, source_text=source_text)
            
            # Finale Validierung: Entferne nochmal ungültige Angebote
            from ..utils.offer_validator import is_valid_offer
            validated_payload = []
            filtered_reasons = {}
            
            for offer in payload:
                title = offer.get("title", "")
                price = offer.get("price")
                price_str = offer.get("price_raw") or (str(price) if price else None)
                
                # Multi-stage validation
                if not title or len(title.strip()) < 3:
                    filtered_reasons["empty_title"] = filtered_reasons.get("empty_title", 0) + 1
                    continue
                
                if not is_valid_offer(title, price_str):
                    filtered_reasons["invalid_offer"] = filtered_reasons.get("invalid_offer", 0) + 1
                    LOGGER.debug("[VALIDATE] Filtered invalid offer: %s", title[:50])
                    continue
                
                # Additional quality checks
                # Check for minimum word count
                words = title.split()
                if len(words) < 1:
                    filtered_reasons["no_words"] = filtered_reasons.get("no_words", 0) + 1
                    continue
                
                # Check for reasonable price if present
                if price is not None:
                    if price < 0.01 or price > 10000.0:
                        filtered_reasons["invalid_price"] = filtered_reasons.get("invalid_price", 0) + 1
                        continue
                
                # Check confidence threshold (very low confidence might be junk)
                confidence = offer.get("confidence", 0.0)
                if confidence < 0.1:
                    filtered_reasons["low_confidence"] = filtered_reasons.get("low_confidence", 0) + 1
                    continue
                
                validated_payload.append(offer)
            
            if filtered_reasons:
                LOGGER.info("[VALIDATE] Filtered offers: %s", ", ".join(f"{k}: {v}" for k, v in filtered_reasons.items()))
            
            payload = validated_payload
            LOGGER.info("[MERGE] Final validation: %d valid offers (from %d merged, filtered %d)", 
                       len(payload), len(merged), len(merged) - len(payload))
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("[MERGE] Merge/normalize failed: %s", exc)
            payload = []

        # Write result
        report = {
            "metadata": {
                "folder": str(folder),
                "ai_candidates": len(ai_offers),
                "json_candidates": len(json_offers),
                "html_candidates": len(html_offers),
                "pdf_candidates": len(pdf_offers),
                "ocr_candidates": len(ocr_offers),
                "fallback_candidates": len(fallback_offers),
                "final_offers": len(payload),
            },
            "offers": payload,
        }

        try:
            files.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            LOGGER.info("[PROCESS] Wrote %s with %d offers", files.output, len(payload))
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("[PROCESS] Failed to write output: %s", exc)
            return self._write_empty_result(folder, f"Write failed: {exc}")

        return report

    def _missing_ratio(self, offers: list) -> float:
        """Calculate ratio of offers missing price."""
        if not offers:
            return 1.0
        missing = sum(1 for offer in offers if not getattr(offer, "price", None))
        return missing / len(offers)

    def _write_empty_result(self, folder: Path, error: str) -> Dict:
        """Write empty offers.json when processing fails completely."""
        files = discover_files(folder)
        output_path = files.output
        report = {
            "metadata": {
                "folder": str(folder),
                "error": error,
                "json_candidates": 0,
                "html_candidates": 0,
                "pdf_candidates": 0,
                "ocr_candidates": 0,
                "fallback_candidates": 0,
                "final_offers": 0,
            },
            "offers": [],
        }
        try:
            output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            LOGGER.fallback("Wrote empty offers.json due to processing failure")
        except Exception:  # noqa: BLE001
            pass
        return report
