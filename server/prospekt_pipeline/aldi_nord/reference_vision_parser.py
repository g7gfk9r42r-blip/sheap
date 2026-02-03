"""Vision AI parser that uses baseline JSON as reference to find missing offers."""
from __future__ import annotations

import base64
import json
import os
import re
from pathlib import Path
from typing import List, Optional

try:
    from openai import OpenAI
except ImportError:
    print("[VISION] openai not installed. Vision parsing disabled.")
    OpenAI = None

from pdf2image import convert_from_path

from .models import Offer


class ReferenceVisionParser:
    """Vision AI parser that finds missing offers using baseline reference."""

    def __init__(self):
        """Initialize Vision parser."""
        api_key = os.getenv("OPENAI_API_KEY")
        if api_key and OpenAI:
            self.client = OpenAI(api_key=api_key)
        else:
            self.client = None
            if not api_key:
                print("[VISION] OPENAI_API_KEY not set. Vision parsing disabled.")

    def find_missing_offers(
        self,
        pdf_path: Path,
        baseline_offers: List[Offer],
        page_number: int,
    ) -> List[Offer]:
        """Extract ALL offers from a specific page (deduplication happens in merge)."""
        if not self.client or not pdf_path.exists():
            return []

        # Convert PDF page to image (300 DPI for better quality)
        try:
            images = convert_from_path(str(pdf_path), dpi=300, first_page=page_number, last_page=page_number)
            if not images:
                return []
            image = images[0]
        except Exception as e:
            print(f"[VISION] Failed to convert page {page_number}: {e}")
            return []

        # Encode image
        import io
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        img_data = base64.b64encode(buffer.getvalue()).decode("utf-8")
        img_url = f"data:image/png;base64,{img_data}"

        # Create prompt - extract ALL offers (deduplication happens in merge)
        prompt = f"""Du siehst ein ALDI Nord Prospekt-Bild (Seite {page_number}).

🔥 KRITISCHE AUFGABE - EXTRAHIERE ALLE ANGEBOTE:
1. Scanne das BILD KOMPLETT - jeden Quadratzentimeter, jeden Winkel!
2. Finde JEDES EINZELNE Angebot das du siehst - auch die kleinsten!
3. Extrahiere ALLE Angebote - nichts auslassen!
4. WICHTIG - Nichts übersehen:
   ✓ Kleine Preise (0,29 €, 0,49 €, 0,79 €)
   ✓ Produkte in Ecken und am Rand
   ✓ Kleine Schriftgrößen
   ✓ Header/Footer Angebote
   ✓ "X für Y€" oder "Ab X€" Angebote
   ✓ Produkte in Bildern/Illustrationen
   ✓ Angebote in Tabellen
   ✓ Produkte mit sehr langen Namen
   ✓ Auch Produkte die mehrfach vorkommen

Format (JSON Array) - MUSS mit [ beginnen:
[
  {{
    "title": "Vollständiger Produktname wie auf dem Bild",
    "price": 1.99,
    "price_raw": "1,99 €",
    "unit": "kg/g/L/ml/Stück oder null",
    "brand": "Marke oder null",
    "category": "Kategorie oder null"
  }}
]

ANTWORT NUR MIT VALIDEM JSON ARRAY - KEINE Erklärungen, KEINE Markdown, KEIN Text davor oder danach!
Extrahiere ALLES was du siehst - sei extrem gründlich!"""

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {"url": img_url}
                            },
                        ]
                    }
                ],
                max_tokens=2000,
                temperature=0.1,
            )

            content = response.choices[0].message.content
            if not content:
                return []

            # Extract JSON
            offers_data = self._extract_json(content)
            if not offers_data:
                return []

            # Convert to Offer objects
            offers = []
            for item in offers_data:
                if isinstance(item, dict) and item.get("title"):
                    offer = Offer(
                        title=item.get("title", ""),
                        price=item.get("price"),
                        price_raw=item.get("price_raw"),
                        unit=item.get("unit"),
                        brand=item.get("brand"),
                        category=item.get("category"),
                        confidence=0.95,  # Vision has high confidence
                        source="vision_reference",
                        source_page=page_number,
                    )
                    offers.append(offer)

            return offers

        except Exception as e:
            print(f"[VISION] API error for page {page_number}: {e}")
            return []


    def _extract_json(self, text: str) -> List[dict]:
        """Extract JSON from text, with repair fallbacks."""
        # Try direct JSON parse
        try:
            data = json.loads(text)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                # Try to find array in dict
                for key in ["offers", "items", "products", "missing"]:
                    if key in data and isinstance(data[key], list):
                        return data[key]
        except json.JSONDecodeError:
            pass

        # Try to extract from code blocks
        json_match = re.search(r"```json\s*(\[.*?\])\s*```", text, re.DOTALL)
        if json_match:
            try:
                return json.loads(json_match.group(1))
            except json.JSONDecodeError:
                pass

        # Try to find JSON array in text
        array_match = re.search(r"\[.*?\]", text, re.DOTALL)
        if array_match:
            try:
                return json.loads(array_match.group(0))
            except json.JSONDecodeError:
                pass

        return []

    def process_all_pages(
        self,
        pdf_path: Path,
        baseline_offers: List[Offer],
        max_pages: Optional[int] = None,
        smart_sampling: bool = True,
    ) -> List[Offer]:
        """Process PDF pages to extract ALL offers (deduplication in merge)."""
        if not self.client or not pdf_path.exists():
            return []

        # Get total page count
        try:
            # Try PyPDF2 first
            try:
                from PyPDF2 import PdfReader
                reader = PdfReader(str(pdf_path))
                total_pages = len(reader.pages)
            except ImportError:
                # Fallback: convert to images to count pages
                images = convert_from_path(str(pdf_path), dpi=200)
                total_pages = len(images)
        except Exception as e:
            print(f"[VISION] Could not determine page count: {e}")
            # Try to convert first page to estimate
            try:
                images = convert_from_path(str(pdf_path), dpi=200, first_page=1, last_page=1)
                if images:
                    total_pages = 1
                else:
                    return []
            except Exception:
                return []

        if max_pages:
            total_pages = min(total_pages, max_pages)

        # Process all pages for maximum coverage
        if smart_sampling and total_pages > 10:
            # Only use smart sampling for very long documents (>10 pages)
            pages_to_process = self._select_pages_smart(total_pages)
            print(f"[VISION] Smart sampling: Processing {len(pages_to_process)}/{total_pages} pages")
        else:
            # Process ALL pages for maximum coverage
            pages_to_process = list(range(1, total_pages + 1))
            print(f"[VISION] Processing ALL {total_pages} pages for maximum coverage...")

        all_offers = []

        for page_num in pages_to_process:
            print(f"[VISION] Page {page_num}/{total_pages}...")
            page_offers = self.find_missing_offers(pdf_path, baseline_offers, page_num)
            
            if page_offers:
                all_offers.extend(page_offers)
                print(f"[VISION] ✓ Extracted {len(page_offers)} offers from page {page_num}")
            else:
                print(f"[VISION] ✓ No offers found on page {page_num}")

        return all_offers

    def _select_pages_smart(self, total_pages: int) -> List[int]:
        """Select pages intelligently for processing."""
        pages = []

        # Always process first 3 pages (usually most important)
        pages.extend([1, 2, 3])

        # Always process last 3 pages
        if total_pages > 3:
            pages.extend([total_pages - 2, total_pages - 1, total_pages])

        # Process every 2nd page in the middle
        if total_pages > 6:
            middle_start = 4
            middle_end = total_pages - 3
            for page in range(middle_start, middle_end + 1, 2):
                if page not in pages:
                    pages.append(page)

        # Remove duplicates and sort
        pages = sorted(list(set(pages)))

        return pages

