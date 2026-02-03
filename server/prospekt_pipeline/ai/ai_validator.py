"""AI validator for offer validation and date extraction."""
from __future__ import annotations

import json
import os
from typing import List, Optional

import openai
from dotenv import load_dotenv
from rapidfuzz import fuzz

from ..utils.logger import get_logger
from .prompt_templates import EXTRACT_DATES_PROMPT

load_dotenv()

LOGGER = get_logger("ai.validator")

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY")) if os.getenv("OPENAI_API_KEY") else None


class AIValidator:
    """Validator for AI-extracted offers."""

    def __init__(self):
        """Initialize AI validator."""
        self.client = client

    def validate_offers(self, offers: List[dict]) -> List[dict]:
        """Validate and clean offers.
        
        Args:
            offers: List of offer dictionaries
            
        Returns:
            Validated list of offers
        """
        validated: List[dict] = []
        removed_count = 0

        for offer in offers:
            if not isinstance(offer, dict):
                removed_count += 1
                continue

            # Validate price
            price = offer.get("price")
            if price is not None:
                try:
                    price_float = float(price)
                    if price_float < 0.1 or price_float > 200:
                        removed_count += 1
                        LOGGER.debug("[VALIDATE] Removed offer with invalid price: %.2f", price_float)
                        continue
                except (ValueError, TypeError):
                    # Price is invalid, but might have price_raw
                    price_raw = offer.get("price_raw", "")
                    if not price_raw or not price_raw.strip():
                        removed_count += 1
                        continue

            # Normalize price
            if price is None:
                price_raw = offer.get("price_raw", "")
                if price_raw:
                    try:
                        # Try to extract numeric price
                        import re
                        price_match = re.search(r"(\d+[\.,]\d{1,2})", price_raw.replace("€", "").strip())
                        if price_match:
                            price_str = price_match.group(1).replace(",", ".")
                            offer["price"] = float(price_str)
                    except (ValueError, AttributeError):
                        pass

            # Standardize units
            unit = offer.get("unit")
            if unit:
                unit = self._standardize_unit(unit)
                offer["unit"] = unit

            # Remove duplicates via fuzzy title match
            title = offer.get("title", "").lower().strip()
            is_duplicate = False
            for existing in validated:
                existing_title = existing.get("title", "").lower().strip()
                similarity = fuzz.ratio(title, existing_title)
                if similarity > 90:  # Very similar titles
                    # Keep the one with higher confidence
                    if offer.get("confidence", 0.0) > existing.get("confidence", 0.0):
                        validated.remove(existing)
                        validated.append(offer)
                    is_duplicate = True
                    break

            if not is_duplicate:
                validated.append(offer)

        if removed_count > 0:
            LOGGER.info("[VALIDATE] Removed %d invalid offers", removed_count)

        LOGGER.info("[VALIDATE] Validated %d offers (from %d input)", len(validated), len(offers))
        return validated

    def _standardize_unit(self, unit: str) -> str:
        """Standardize unit strings.
        
        Args:
            unit: Unit string (e.g., "kg", "KG", "kilogram")
            
        Returns:
            Standardized unit (kg, g, L, ml, Stück)
        """
        if not unit:
            return unit

        unit_lower = unit.lower().strip()

        # Map variations to standard units
        unit_map = {
            "kg": "kg",
            "kilogram": "kg",
            "kilogramm": "kg",
            "g": "g",
            "gramm": "g",
            "gram": "g",
            "l": "L",
            "liter": "L",
            "ml": "ml",
            "milliliter": "ml",
            "stück": "Stück",
            "stk": "Stück",
            "stk.": "Stück",
            "piece": "Stück",
            "pieces": "Stück",
        }

        # Check for exact matches
        if unit_lower in unit_map:
            return unit_map[unit_lower]

        # Check for partial matches
        for key, value in unit_map.items():
            if key in unit_lower:
                return value

        # Return original if no match
        return unit

    def extract_date_range(self, text: str) -> Optional[dict]:
        """Extract validity date range from text using GPT.
        
        Args:
            text: Text content from PDF/HTML
            
        Returns:
            Dictionary with valid_from, valid_to, confidence or None
        """
        if not self.client:
            return None

        if not text or len(text.strip()) < 10:
            return None

        try:
            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "user",
                        "content": EXTRACT_DATES_PROMPT.format(text=text[:2000]),  # Limit text length
                    },
                ],
                response_format={"type": "json_object"},
                temperature=0.1,
                max_tokens=200,
            )

            content = response.choices[0].message.content
            
            # Clean up response
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                content = content.split("```")[1].split("```")[0].strip()
            
            data = json.loads(content)
            
            if isinstance(data, dict) and ("valid_from" in data or "valid_to" in data):
                return data

        except Exception as exc:
            LOGGER.debug("[VALIDATE] Date extraction failed: %s", exc)

        return None

