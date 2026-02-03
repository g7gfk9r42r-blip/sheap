"""Prompt templates for Vision-AI parsing."""
from __future__ import annotations

EXTRACT_PROMPT = """You are a world-class model for extracting structured grocery offer data from images.
Extract ALL products on this flyer page.

Return ONLY a valid JSON array (no text, no markdown, no code blocks!). Each entry must have:
{
  "title": "string (product name)",
  "price_raw": "string (original price as shown, e.g. '1,29 €')",
  "price": float (numeric price, e.g. 1.29),
  "unit": "string (kg, g, L, ml, Stück, or null)",
  "brand": "string or null (brand name if visible)",
  "category": "string or null (e.g. 'Käse', 'Fleisch', 'Obst', 'Gemüse')",
  "valid_from": "string or null (ISO date: YYYY-MM-DD)",
  "valid_to": "string or null (ISO date: YYYY-MM-DD)",
  "page": int (page number),
  "confidence": float (0.0-1.0, your confidence in this extraction)
}

Rules:
- Extract EVERY visible product/offer
- Prices must be numeric floats (German format: comma as decimal)
- Units: kg, g, L, ml, Stück
- If date range visible, extract it
- Confidence: 0.9+ for clear offers, 0.7-0.9 for partial, <0.7 for uncertain
- Return empty array [] if no offers found
- NEVER include explanatory text, only JSON
- Start your response directly with [ or {, no preamble"""

REPAIR_JSON_PROMPT = """The following JSON is malformed. Please correct it and return ONLY valid JSON (no text, no markdown):

{malformed_json}

Return the corrected JSON array directly."""

VALIDATE_PRICE_PROMPT = """Given these two price variants for the same product in a grocery flyer, which is correct?

Product: {title}
Variant A: {price_a}
Variant B: {price_b}

Return ONLY a JSON object:
{
  "correct_price": "A" or "B",
  "reason": "brief explanation"
}"""

DEDUPE_RESOLUTION_PROMPT = """These two offers appear to be duplicates. Determine if they are the same product and merge them if so.

Offer A: {offer_a}
Offer B: {offer_b}

Return ONLY a JSON object:
{
  "is_duplicate": true/false,
  "merged_offer": {merged offer object} or null,
  "reason": "brief explanation"
}"""

EXTRACT_DATES_PROMPT = """Extract the validity date range from this grocery flyer text page.

Text: {text}

Return ONLY a JSON object:
{
  "valid_from": "YYYY-MM-DD" or null,
  "valid_to": "YYYY-MM-DD" or null,
  "confidence": float (0.0-1.0)
}"""

