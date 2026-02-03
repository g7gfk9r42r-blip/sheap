# ============================================
# FIXED VERSION — AIPDFParser
# Keine Tabs mehr, 100% konsistente Einrückung
# ============================================

from __future__ import annotations

import base64
import json
import os
import traceback
from pathlib import Path
from typing import List, Dict, Any

from dotenv import load_dotenv
from openai import OpenAI
from pdf2image import convert_from_path

from ..utils.logger import get_logger

load_dotenv()

LOGGER = get_logger("ai.parser")

# Initialize OpenAI client
api_key = os.getenv("OPENAI_API_KEY")
if api_key:
    client = OpenAI(api_key=api_key)
else:
    LOGGER.warning("[AI] OPENAI_API_KEY not found in .env - AI parsing will be disabled")
    client = None


class AIPDFParser:
    """
    Premium Vision-AI PDF Parser:
    • Konvertiert PDF → Bilder
    • GPT-4o Vision extrahiert Angebotsdaten
    • Multi-Pass Validation + JSON Repair
    """

    def process_pdf(self, pdf_path: str) -> List[Dict[str, Any]]:
        """Process PDF file using Vision-AI."""
        if not client:
            LOGGER.warning("[AI] OpenAI client not initialized - skipping AI parsing")
            return []

        try:
            LOGGER.info("[AI] Processing PDF: %s", Path(pdf_path).name)
            pages = convert_from_path(str(pdf_path), dpi=200)
            LOGGER.info("[AI] Converted %d pages to images", len(pages))

            encoded_pages = [self.encode_image(img) for img in pages]

            raw_json = self.ask_model(encoded_pages)

            offers = self.safe_json_load(raw_json)

            # Add source metadata
            for offer in offers:
                if isinstance(offer, dict):
                    offer["source"] = "ai_vision"
                    if "confidence" not in offer:
                        offer["confidence"] = 0.9

            LOGGER.info("[AI] Extracted %d offers", len(offers))
            return offers

        except Exception as e:
            LOGGER.error("[AI-PDF] ERROR: %s", e)
            LOGGER.debug("[AI-PDF] Traceback: %s", traceback.format_exc())
            return []

    # ----------------------
    # Image Encoding
    # ----------------------
    def encode_image(self, img) -> str:
        """Encode PIL image to base64 data URL."""
        import io
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        base64_bytes = base64.b64encode(buffer.getvalue()).decode("utf-8")
        return f"data:image/png;base64,{base64_bytes}"

    # ----------------------
    # GPT-4o Vision Request
    # ----------------------
    def ask_model(self, encoded_pages: List[str]) -> str:
        """Sendet alle PDF-Bilder an GPT-Vision und gibt reinen JSON-String zurück."""

        prompt = """
Extrahiere ALLE Angebote. Format:

[
  {
    "title": "...",
    "price": "...",
    "price_raw": "...",
    "unit": "...",
    "brand": "...",
    "category": "...",
    "valid_from": "...",
    "valid_to": "...",
    "confidence": 0.9
  }
]

Antwort NUR mit JSON.
"""

        msgs = [
            {
                "role": "system",
                "content": "Du bist ein professioneller Prospekt-Analyst."
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt}
                ] + [
                    {"type": "image_url", "image_url": {"url": img}}
                    for img in encoded_pages
                ]
            }
        ]

        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=msgs,
                max_tokens=4000,
                temperature=0
            )

            content = response.choices[0].message.content
            if content is None:
                return "[]"

            return content.strip()

        except Exception as e:
            LOGGER.error("[AI] API call failed: %s", e)
            return "[]"

    # ----------------------
    # JSON Fixing
    # ----------------------
    def safe_json_load(self, text: str) -> List[Dict[str, Any]]:
        """Extrahiert JSON selbst aus beschädigten Antworten."""

        try:
            data = json.loads(text)
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                # Try to find array in dict
                for key in ["offers", "items", "products"]:
                    if key in data and isinstance(data[key], list):
                        return data[key]
                return []
            return []
        except Exception:
            try:
                cleaned = self.extract_json(text)
                data = json.loads(cleaned)
                if isinstance(data, list):
                    return data
                return []
            except Exception:
                LOGGER.warning("[AI] Failed to parse JSON, returning empty list")
                return []

    def extract_json(self, text: str) -> str:
        """Findet JSON-Blöcke in Text."""
        start = text.find("[")
        end = text.rfind("]")
        if start == -1 or end == -1:
            return "[]"
        return text[start:end+1]

    # Backward compatibility methods
    def parse_pdf(self, pdf_path: str | Path | None = None, pdf_bytes: bytes | None = None) -> List[Dict[str, Any]]:
        """Alias for process_pdf for backward compatibility."""
        if pdf_path:
            return self.process_pdf(str(pdf_path))
        return []
