"""Vision AI parser for ALDI Nord images using OpenAI GPT-4o."""
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

from .models import Offer


class AldiNordVisionParser:
    """Vision AI parser for ALDI Nord images."""

    def __init__(self):
        """Initialize Vision parser."""
        api_key = os.getenv("OPENAI_API_KEY")
        if api_key and OpenAI:
            self.client = OpenAI(api_key=api_key)
        else:
            self.client = None
            if not api_key:
                print("[VISION] OPENAI_API_KEY not set. Vision parsing disabled.")

    def parse(self, images_dir: Path) -> List[Offer]:
        """Parse all images in directory using Vision AI."""
        if not self.client or not images_dir.exists():
            return []

        # Find all image files
        image_files = []
        for ext in ["*.png", "*.jpg", "*.jpeg"]:
            image_files.extend(images_dir.glob(ext))
            image_files.extend(images_dir.glob(ext.upper()))

        if not image_files:
            return []

        print(f"[VISION] Found {len(image_files)} images")

        all_offers = []
        for img_path in sorted(image_files)[:20]:  # Limit to 20 images
            try:
                offers = self._parse_image(img_path)
                all_offers.extend(offers)
            except Exception as e:
                print(f"[VISION] Error parsing {img_path.name}: {e}")

        # Fuzzy deduplication
        return self._deduplicate_offers(all_offers)

    def _parse_image(self, img_path: Path) -> List[Offer]:
        """Parse single image using Vision AI."""
        # Encode image to base64
        with open(img_path, "rb") as f:
            img_data = base64.b64encode(f.read()).decode("utf-8")

        # Determine image type
        img_type = "png" if img_path.suffix.lower() == ".png" else "jpeg"
        img_url = f"data:image/{img_type};base64,{img_data}"

        prompt = """Extrahiere ALLE Angebote aus diesem ALDI Nord Prospekt-Bild.

Format (JSON Array):
[
  {
    "title": "Produktname",
    "price": 1.99,
    "price_raw": "1,99 €",
    "unit": "kg",
    "brand": "Marke oder null",
    "category": "Kategorie oder null"
  }
]

Antwort NUR mit JSON, keine Erklärungen."""

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
                        source="vision",
                        source_page=self._extract_page_number(img_path.name),
                    )
                    offers.append(offer)

            return offers

        except Exception as e:
            print(f"[VISION] API error for {img_path.name}: {e}")
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
                for key in ["offers", "items", "products"]:
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

    def _extract_page_number(self, filename: str) -> Optional[int]:
        """Extract page number from filename."""
        match = re.search(r"page[_\s]?(\d+)", filename, re.I)
        if match:
            return int(match.group(1))
        match = re.search(r"(\d+)", filename)
        if match:
            return int(match.group(1))
        return None

    def _deduplicate_offers(self, offers: List[Offer]) -> List[Offer]:
        """Deduplicate offers using fuzzy matching."""
        try:
            from rapidfuzz import fuzz
        except ImportError:
            # Fallback: simple exact match
            seen = set()
            unique = []
            for offer in offers:
                key = offer.title.lower() if offer.title else ""
                if key and key not in seen:
                    seen.add(key)
                    unique.append(offer)
            return unique

        # Fuzzy deduplication
        unique = []
        for offer in offers:
            is_duplicate = False
            for existing in unique:
                if offer.title and existing.title:
                    similarity = fuzz.ratio(offer.title.lower(), existing.title.lower())
                    if similarity > 85:
                        # Keep higher confidence
                        if offer.confidence > existing.confidence:
                            unique.remove(existing)
                            unique.append(offer)
                        is_duplicate = True
                        break
            if not is_duplicate:
                unique.append(offer)

        return unique

