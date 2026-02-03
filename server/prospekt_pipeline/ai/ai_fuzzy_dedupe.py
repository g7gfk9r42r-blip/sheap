"""Fuzzy deduplication for AI-extracted offers."""
from __future__ import annotations

import json
import os
from typing import List, Optional

import openai
from dotenv import load_dotenv
from rapidfuzz import fuzz

from ..utils.logger import get_logger
from .prompt_templates import DEDUPE_RESOLUTION_PROMPT, VALIDATE_PRICE_PROMPT

load_dotenv()

LOGGER = get_logger("ai.dedupe")

client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY")) if os.getenv("OPENAI_API_KEY") else None


class AIFuzzyDedupe:
    """Fuzzy deduplication with AI-assisted conflict resolution."""

    def __init__(self, similarity_threshold: float = 87.0):
        """Initialize fuzzy deduplicator.
        
        Args:
            similarity_threshold: Minimum similarity ratio (0-100) to consider duplicates
        """
        self.similarity_threshold = similarity_threshold
        self.client = client

    def run(self, offers: List[dict]) -> List[dict]:
        """Run fuzzy deduplication on offers.
        
        Args:
            offers: List of offer dictionaries
            
        Returns:
            Deduplicated list of offers
        """
        if not offers:
            return []

        LOGGER.info("[DEDUPE] Starting deduplication of %d offers", len(offers))

        # Group similar offers
        groups: List[List[dict]] = []
        processed_indices: set[int] = set()

        for i, offer_a in enumerate(offers):
            if i in processed_indices:
                continue

            # Start a new group
            group = [offer_a]
            processed_indices.add(i)

            # Find similar offers
            title_a = offer_a.get("title", "").lower().strip()
            if not title_a:
                continue

            for j, offer_b in enumerate(offers[i + 1 :], start=i + 1):
                if j in processed_indices:
                    continue

                title_b = offer_b.get("title", "").lower().strip()
                if not title_b:
                    continue

                # Calculate similarity
                similarity = fuzz.ratio(title_a, title_b)

                if similarity > self.similarity_threshold:
                    group.append(offer_b)
                    processed_indices.add(j)

            groups.append(group)

        # Merge groups
        merged_offers: List[dict] = []
        for group in groups:
            if len(group) == 1:
                merged_offers.append(group[0])
            else:
                # Merge duplicates
                merged = self._merge_group(group)
                if merged:
                    merged_offers.append(merged)

        LOGGER.info("[DEDUPE] Deduplicated %d offers into %d unique", len(offers), len(merged_offers))
        return merged_offers

    def _merge_group(self, group: List[dict]) -> Optional[dict]:
        """Merge a group of similar offers into one.
        
        Args:
            group: List of similar offer dictionaries
            
        Returns:
            Merged offer dictionary or None
        """
        if not group:
            return None

        if len(group) == 1:
            return group[0]

        # Start with highest confidence offer
        group.sort(key=lambda x: x.get("confidence", 0.0), reverse=True)
        merged = group[0].copy()

        # Merge data from other offers
        for offer in group[1:]:
            # Merge confidence (use max)
            merged["confidence"] = max(merged.get("confidence", 0.0), offer.get("confidence", 0.0))

            # Merge price if missing
            if not merged.get("price") and offer.get("price"):
                merged["price"] = offer["price"]
                merged["price_raw"] = offer.get("price_raw", merged.get("price_raw"))

            # Merge unit if missing
            if not merged.get("unit") and offer.get("unit"):
                merged["unit"] = offer["unit"]

            # Merge brand if missing
            if not merged.get("brand") and offer.get("brand"):
                merged["brand"] = offer["brand"]

            # Merge category if missing
            if not merged.get("category") and offer.get("category"):
                merged["category"] = offer["category"]

            # Handle price conflicts
            price_a = merged.get("price")
            price_b = offer.get("price")
            if price_a and price_b and abs(float(price_a) - float(price_b)) > 0.01:
                # Prices differ significantly - ask AI
                resolved = self._resolve_price_conflict(merged.get("title", ""), price_a, price_b)
                if resolved:
                    merged["price"] = resolved
                else:
                    # Keep higher confidence price
                    if offer.get("confidence", 0.0) > merged.get("confidence", 0.0):
                        merged["price"] = price_b
                        merged["price_raw"] = offer.get("price_raw", merged.get("price_raw"))

        return merged

    def _resolve_price_conflict(self, title: str, price_a: float | str, price_b: float | str) -> Optional[float]:
        """Resolve price conflict using AI.
        
        Args:
            title: Product title
            price_a: First price variant
            price_b: Second price variant
            
        Returns:
            Resolved price or None
        """
        if not self.client:
            return None

        try:
            from .prompt_templates import VALIDATE_PRICE_PROMPT

            response = self.client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "user",
                        "content": VALIDATE_PRICE_PROMPT.format(
                            title=title,
                            price_a=str(price_a),
                            price_b=str(price_b),
                        ),
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
            
            if isinstance(data, dict) and "correct_price" in data:
                choice = data["correct_price"]
                if choice == "A":
                    return float(price_a)
                elif choice == "B":
                    return float(price_b)

        except Exception as exc:
            LOGGER.debug("[DEDUPE] Price conflict resolution failed: %s", exc)

        return None

