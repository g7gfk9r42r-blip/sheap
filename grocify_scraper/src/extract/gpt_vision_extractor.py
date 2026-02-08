"""GPT Vision-based PDF extraction with page-by-page completeness checks"""

import base64
import json
import os
import re
import time
from pathlib import Path
from typing import List, Dict, Any, Optional, Tuple
import logging
from io import BytesIO

try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False
    OpenAI = None

try:
    from pdf2image import convert_from_path
    PDF2IMAGE_AVAILABLE = True
except ImportError:
    PDF2IMAGE_AVAILABLE = False

from ..models import Offer, PriceTier, Condition, Source, Quantity, Price, ReferencePrice
from ..config import SUPERMARKETS

logger = logging.getLogger(__name__)


class QuotaExceededError(Exception):
    """Raised when OpenAI API quota is exceeded"""
    pass


class APIConnectionError(Exception):
    """Raised when OpenAI API connection fails repeatedly"""
    pass


class GPTVisionExtractor:
    """Extract offers from PDF using GPT-4 Vision with completeness checks"""
    
    def __init__(self, supermarket: str):
        self.supermarket = supermarket
        self.config = SUPERMARKETS.get(supermarket)
        
        # Initialize OpenAI client
        api_key = os.getenv("OPENAI_API_KEY")
        if api_key and OPENAI_AVAILABLE:
            self.client = OpenAI(api_key=api_key)
        else:
            self.client = None
            if not api_key:
                logger.warning("OPENAI_API_KEY not set. GPT Vision extraction disabled.")
            if not OPENAI_AVAILABLE:
                logger.warning("openai package not installed. Install with: pip install openai")
        
        if not PDF2IMAGE_AVAILABLE:
            logger.warning("pdf2image not available. Install with: pip install pdf2image")
    
    def extract(self, pdf_path: Path, week_key: str, max_passes: int = 3) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        """
        Extract offers from PDF using GPT Vision with completeness checks.
        
        Args:
            pdf_path: Path to PDF file
            week_key: Week key
            max_passes: Maximum number of extraction passes per page
            
        Returns:
            Tuple of (offers, page_stats)
        """
        if not self.client:
            logger.error("GPT Vision client not available. Cannot extract.")
            return [], {}
        
        if not PDF2IMAGE_AVAILABLE:
            logger.error("pdf2image not available. Cannot render PDF pages.")
            return [], {}
        
        if not pdf_path.exists():
            logger.error(f"PDF file not found: {pdf_path}")
            return [], {}
        
        logger.info(f"Extracting offers from PDF using GPT Vision: {pdf_path}")
        
        # Convert PDF to images
        try:
            import warnings
            import logging
            
            # Suppress pdf2image warnings
            warnings.filterwarnings("ignore", category=UserWarning)
            pdf2image_logger = logging.getLogger("pdf2image")
            pdf2image_logger.setLevel(logging.ERROR)
            
            images = convert_from_path(str(pdf_path), dpi=300)
            logger.info(f"Rendered {len(images)} pages from PDF")
        except Exception as e:
            logger.error(f"Failed to render PDF pages: {e}")
            return [], {}
        
        all_offers = []
        page_stats = {}
        
        # Extract from each page with multiple passes
        for page_num, image in enumerate(images, 1):
            logger.info(f"🔄 Processing page {page_num}/{len(images)}...")
            print(f"🔄 Processing page {page_num}/{len(images)}...", flush=True)
            
            page_offers, stats = self._extract_page_with_passes(
                image, page_num, week_key, pdf_path, max_passes
            )
            
            logger.info(f"✅ Page {page_num} complete: {len(page_offers)} offers extracted")
            print(f"✅ Page {page_num} complete: {len(page_offers)} offers extracted", flush=True)
            
            all_offers.extend(page_offers)
            page_stats[f"page_{page_num}"] = stats
        
        # Deduplicate offers from same page
        all_offers = self._deduplicate_offers(all_offers)
        
        logger.info(f"Extracted {len(all_offers)} unique offers from {len(images)} pages")
        
        return all_offers, {
            "total_pages": len(images),
            "total_offers": len(all_offers),
            "pages": page_stats,
        }
    
    def _extract_page_with_passes(
        self, image, page_num: int, week_key: str, pdf_path: Path, max_passes: int
    ) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        """Extract offers from a single page with multiple passes for completeness"""
        page_offers = []
        seen_offers = set()
        stats = {
            "passes": [],
            "total_extracted": 0,
            "tile_count_estimate": None,
        }
        
        # Pass 1: Initial extraction
        logger.info(f"Page {page_num}: Starting initial extraction (Pass 1)...")
        print(f"  📄 Page {page_num}: Pass 1 - Initial extraction...", flush=True)
        pass1_offers = self._extract_page_initial(image, page_num, week_key, pdf_path)
        logger.info(f"Page {page_num}: Pass 1 complete - {len(pass1_offers)} offers found")
        print(f"  ✅ Page {page_num}: Pass 1 complete - {len(pass1_offers)} offers", flush=True)
        page_offers.extend(pass1_offers)
        for offer in pass1_offers:
            seen_offers.add(self._offer_key(offer))
        
        stats["passes"].append({
            "pass": 1,
            "type": "initial",
            "extracted": len(pass1_offers),
        })
        
        # Pass 2: Tile completeness check (only if significant gap)
        if len(pass1_offers) > 0:
            logger.info(f"Page {page_num}: Counting tiles for completeness check...")
            print(f"  🔍 Page {page_num}: Counting tiles...", flush=True)
            tile_count = self._count_tiles(image, page_num)
            logger.info(f"Page {page_num}: Found {tile_count} tiles")
            print(f"  📊 Page {page_num}: Found {tile_count} tiles", flush=True)
            stats["tile_count_estimate"] = tile_count
            
            # Only re-extract if gap is significant (>30% missing)
            if tile_count > len(pass1_offers) * 1.3:
                logger.info(f"Page {page_num}: Found {tile_count} tiles but only {len(pass1_offers)} offers. Re-extracting...")
                print(f"  🔄 Page {page_num}: Pass 2 - Re-extracting missing offers...", flush=True)
                pass2_offers = self._extract_page_focused(image, page_num, week_key, pdf_path, "missing_offers")
                logger.info(f"Page {page_num}: Pass 2 complete - {len(pass2_offers)} offers found")
                print(f"  ✅ Page {page_num}: Pass 2 complete - {len(pass2_offers)} offers", flush=True)
                new_offers = [o for o in pass2_offers if self._offer_key(o) not in seen_offers]
                page_offers.extend(new_offers)
                for offer in new_offers:
                    seen_offers.add(self._offer_key(offer))
                
                stats["passes"].append({
                    "pass": 2,
                    "type": "completeness_check",
                    "extracted": len(new_offers),
                })
            else:
                stats["passes"].append({
                    "pass": 2,
                    "type": "completeness_check",
                    "extracted": 0,
                    "skipped": "gap_too_small"
                })
        
        # Pass 3: Microtext pass (UVP, loyalty, multi-price) - only for offers with prices
        if len(page_offers) > 0:
            # Only do microtext pass for offers that might have loyalty/UVP
            offers_with_prices = [o for o in page_offers if o.get("price") or o.get("loyalty_price")]
            if offers_with_prices:
                logger.info(f"Page {page_num}: Starting microtext extraction (Pass 3) for {len(offers_with_prices)} offers...")
                print(f"  🔍 Page {page_num}: Pass 3 - Extracting microtext (UVP/loyalty)...", flush=True)
                pass3_offers = self._extract_page_microtext(image, page_num, week_key, pdf_path, offers_with_prices)
                logger.info(f"Page {page_num}: Pass 3 complete - {len(pass3_offers)} microtext offers found")
                print(f"  ✅ Page {page_num}: Pass 3 complete - {len(pass3_offers)} microtext offers", flush=True)
                # Merge microtext data into existing offers
                page_offers = self._merge_microtext(page_offers, pass3_offers)
                
                stats["passes"].append({
                    "pass": 3,
                    "type": "microtext",
                    "extracted": len(pass3_offers),
                })
            else:
                stats["passes"].append({
                    "pass": 3,
                    "type": "microtext",
                    "extracted": 0,
                    "skipped": "no_prices_to_check"
                })
        
        stats["total_extracted"] = len(page_offers)
        
        return page_offers, stats
    
    def _extract_page_initial(self, image, page_num: int, week_key: str, pdf_path: Path) -> List[Dict[str, Any]]:
        """Initial extraction pass - extract all food offers"""
        logger.debug(f"Page {page_num}: Calling GPT Vision API for initial extraction...")
        print(f"    ⏳ Calling GPT Vision API...", flush=True)
        
        prompt = f"""Extract offers from this supermarket leaflet page image with maximum accuracy.

STEP A — Page Classification:
Analyze the page content and classify it:
- "offers_page": Page primarily contains product offers with prices
- "mixed_page": Mix of offers and informational content
- "info_page": Mostly informational (store hours, locations, recipes, etc.) - return empty offers array
- "nonfood_page": Non-food items only (electronics, clothing, etc.) - return empty offers array

Provide a concise "page_reason" (max 20 words) explaining the classification.

STEP B — Offer Enumeration:
1. Count ALL distinct offer tiles/boxes that contain:
   - A visible price (e.g., "2.99", "€1.49", "3,50€")
   - Price-like text (e.g., "GRATIS", "kostenlos", percentage discounts)
2. Set "tile_count_estimate" to this exact count
3. Output exactly that many offers in the array (unless page_type is "info_page" or "nonfood_page")
4. If a tile is partially unreadable, still include it with appropriate flags and lower confidence

STEP C — Field Extraction (for each offer):

CRITICAL RULES:
- Extract ONLY food items (meat, fish, dairy, vegetables, fruits, bread, pasta, frozen food, sweets, spices, oils, eggs, flour, sugar)
- IGNORE: beverages (wine, beer, juice, soda), coffee, tea, household items, furniture, clothing, tools
- If unsure if item is food, use flag "not_food" and set confidence lower

Required JSON schema per offer:

{{
  "source": {{
    "supermarket": "{self.supermarket}",
    "week_key": "{week_key}",
    "page": {page_num},
    "tile_index": <int>  // Sequential index starting at 0
  }},
  "product": {{
    "title": "<string|null>",  // Full product name as visible
    "brand": "<string|null>",  // Brand name if clearly visible (e.g., "Milka", "Müller")
    "variant": "<string|null>",  // Variant/flavor if specified (e.g., "Vanille", "Schoko")
    "category_guess": "<string|null>"  // Best guess: "Fleisch", "Gemuese", "Kase", "Backwaren", etc.
  }},
  "size": {{
    "amount": <number|null>,  // Numeric amount (e.g., 500, 1, 6)
    "unit": "<string|null>",  // Unit string (e.g., "g", "kg", "l", "ml", "Stueck", "Packung")
    "pack_count": <int|null>  // Number of items in pack if multi-pack (e.g., 6 for "6x 200g")
  }},
  "pricing": {{
    "currency": "EUR",
    "price_current": <number|null>,  // Main/current price (the most prominent price shown)
    "price_regular": <number|null>,  // Regular price if crossed out or shown separately
    "price_before": <number|null>,  // Previous/UVP price if shown (e.g., "statt 4.99")
    "discount_percent": <int|null>,  // Only if explicitly shown (e.g., "-20%") or easily calculable
    "base_price": {{
      "value": <number|null>,  // Price per unit (e.g., 5.98 per kg)
      "unit": "<string|null>"  // Base price unit (e.g., "kg", "100g", "l")
    }},
    "price_options": [  // Array for multiple price conditions
      {{
        "price": <number|null>,
        "condition": "<string|null>",  // Condition text (e.g., "mit Karte", "2 für", "ab")
        "is_loyalty_required": <boolean|null>  // true if requires loyalty card/app
      }}
    ]
  }},
  "conditions": {{
    "loyalty": "<string|null>",  // Loyalty program name if required (e.g., "K-Card", "REWE Bonus")
    "coupon": "<string|null>",  // Coupon requirement if mentioned
    "date_range": "<string|null>",  // Validity period if shown (e.g., "01.01.-07.01.")
    "limit": "<string|null>"  // Purchase limit if shown (e.g., "max. 3", "pro Kunde")
  }},
  "meta": {{
    "confidence": <number>,  // 0.2=unreadable, 0.5=partial, 0.8=clear, 0.95=very clear
    "flags": [  // Array of relevant flags:
      // "needs_review" - uncertain extraction
      // "unreadable_text" - text too blurry/small
      // "multi_price" - multiple price conditions
      // "loyalty_price" - requires loyalty card
      // "uvp_present" - UVP/unverbindliche Preisempfehlung shown
      // "missing_brand" - brand not visible
      // "missing_size" - size/unit not visible
      // "not_food" - might not be a food item
      // "discount_visible" - discount percentage shown
      // "base_price_shown" - base price (per kg/l) visible
    ],
    "raw_text_snippet": "<string|null>"  // Key visible text fragments that justify the extracted data (max 160 chars)
  }}
}}

EXTRACTION GUIDELINES:
1. Price parsing:
   - Use dot for decimals: 1.99, 2.49 (NOT 1,99 or 2,49)
   - Extract the most prominent price as "price_current"
   - If price is crossed out, use crossed price as "price_before" and new price as "price_current"
   - For "2 für 5.99" or "3x 2.99", add to price_options array

2. Size/Unit parsing:
   - Extract both numeric amount AND unit separately
   - Examples: "500 g" → amount: 500, unit: "g"
   - "1 kg" → amount: 1, unit: "kg"
   - "6 Stück" → amount: 6, unit: "Stueck"
   - "6x 200g" → amount: 200, unit: "g", pack_count: 6

3. Brand extraction:
   - Only extract if brand name is clearly visible and distinct from product name
   - If brand is part of product name, include in title, set brand to null

4. Confidence scoring:
   - 0.95: All text crystal clear, all fields extractable
   - 0.8: Most text clear, minor uncertainties
   - 0.5: Partial visibility, some guessing required
   - 0.2: Very blurry/unreadable, mostly guessing

5. Flags:
   - Add "needs_review" if any field is uncertain
   - Add "unreadable_text" if text is too small/blurry
   - Add "multi_price" if multiple price conditions exist
   - Add "loyalty_price" if any price requires loyalty card
   - Add "uvp_present" if UVP/unverbindliche Preisempfehlung is visible
   - Add "missing_brand" if brand should be visible but isn't
   - Add "missing_size" if size/unit should be visible but isn't
   - Add "not_food" if item might not be food (when uncertain)

6. raw_text_snippet:
   - Include the most important visible text that supports your extraction
   - Focus on: product name, price, size, any special conditions
   - Keep it concise (max 160 characters)
   - Example: "Milka Schokolade 200g 2.99€ mit K-Card 1.99€"

OUTPUT FORMAT:
Return ONLY a single valid JSON object (no markdown, no code blocks, no explanations):

{{
  "page_type": "offers_page" | "mixed_page" | "info_page" | "nonfood_page",
  "page_reason": "<brief explanation>",
  "tile_count_estimate": <integer>,
  "offers": [
    // Array of offer objects matching the schema above
    // Exactly tile_count_estimate items (unless info_page or nonfood_page)
  ]
}}

CRITICAL: Return ONLY valid JSON. No markdown code blocks. No explanations. No extra text."""
        
        return self._call_vision_api_structured(image, prompt, page_num, week_key)
    
    def _extract_page_focused(
        self, image, page_num: int, week_key: str, pdf_path: Path, focus: str
    ) -> List[Dict[str, Any]]:
        """Focused extraction pass for missing offers"""
        prompt = f"""Analysiere diese Prospektseite erneut und suche nach WEITEREN Lebensmittel-Angeboten, die moeglicherweise uebersehen wurden.

{focus.upper()}: Konzentriere dich besonders auf kleine Angebote, Randbereiche, und Angebote die zwischen anderen Elementen versteckt sein koennten.

Extrahiere ALLE zusaetzlichen Lebensmittel-Angebote mit:
- name, brand, price, unit, loyalty_price, loyalty_label, discount, category

ANTWORT FORMAT (NUR JSON):
{{
  "offers": [...]
}}"""
        
        return self._call_vision_api(image, prompt, page_num)
    
    def _extract_page_microtext(
        self, image, page_num: int, week_key: str, pdf_path: Path, existing_offers: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Microtext pass - extract UVP, loyalty details, multi-price info"""
        prompt = f"""Analysiere diese Prospektseite FUER KLEINGEDRUCKTES:
- UVP (unverbindliche Preisempfehlung)
- Karten-/Bonus-Preise
- Mehrfachpreise ("2 fuer", "ab", etc.)
- Gueltigkeitsdaten

Fuer jedes bereits erkannte Angebot, ergaenze:
- uvp_price: UVP falls vorhanden
- loyalty_price: Karten-/Bonus-Preis falls vorhanden
- loyalty_label: Label fuer Loyalty-Preis
- multi_price_info: Info zu Mehrfachpreisen
- valid_from: Gültigkeitsbeginn
- valid_to: Gültigkeitsende

ANTWORT FORMAT (NUR JSON):
{{
  "offers": [
    {{
      "name": "Produktname (zur Zuordnung)",
      "uvp_price": null,
      "loyalty_price": null,
      "loyalty_label": null,
      "multi_price_info": null,
      "valid_from": null,
      "valid_to": null
    }}
  ]
}}"""
        
        return self._call_vision_api(image, prompt, page_num)
    
    def _count_tiles(self, image, page_num: int) -> int:
        """Ask GPT to count offer tiles on the page"""
        prompt = """Zaehle die Anzahl der Lebensmittel-Angebote (Tiles/Boxen) auf dieser Prospektseite.

Antworte NUR mit einer Zahl, z.B.:
15"""
        
        try:
            response = self._call_vision_api_raw(image, prompt)
            # Try to extract number
            numbers = re.findall(r'\d+', response)
            if numbers:
                return int(numbers[0])
        except Exception as e:
            logger.warning(f"Failed to count tiles on page {page_num}: {e}")
        
        return 0
    
    def _call_vision_api(self, image, prompt: str, page_num: int) -> List[Dict[str, Any]]:
        """Call GPT Vision API and parse JSON response"""
        logger.debug(f"Page {page_num}: Preparing API call (converting image to base64)...")
        try:
            # Convert PIL image to base64
            buffered = BytesIO()
            image.save(buffered, format="PNG")
            img_base64 = base64.b64encode(buffered.getvalue()).decode()
            
            # Add retry logic for connection issues
            max_retries = 3
            retry_delay = 2
            
            for attempt in range(max_retries):
                try:
                    if attempt > 0:
                        logger.info(f"Page {page_num}: API call attempt {attempt + 1}/{max_retries}")
                        print(f"      🔄 Retry {attempt + 1}/{max_retries}...", flush=True)
                    else:
                        logger.debug(f"Page {page_num}: Sending request to GPT Vision API...")
                        print(f"      📤 Sending to GPT Vision API...", flush=True)
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",  # Vision-capable model
                        messages=[
                            {
                                "role": "system",
                                "content": "Du bist ein Experte fuer Lebensmittel-Extraktion aus Supermarkt-Prospekten. Antworte NUR mit gueltigem JSON. Keine zusaetzlichen Erklaerungen."
                            },
                            {
                                "role": "user",
                                "content": [
                                    {"type": "text", "text": prompt},
                                    {
                                        "type": "image_url",
                                        "image_url": {
                                            "url": f"data:image/png;base64,{img_base64}",
                                            "detail": "high"
                                        }
                                    }
                                ]
                            }
                        ],
                        max_tokens=4000,
                        temperature=0,
                        timeout=90  # Increased timeout to 90 seconds
                    )
                    logger.debug(f"Page {page_num}: Received response from GPT Vision API")
                    print(f"      ✅ Received response", flush=True)
                    break  # Success, exit retry loop
                except Exception as retry_error:
                    if attempt < max_retries - 1:
                        error_str = str(retry_error) if retry_error else ""
                        # Only retry on connection/timeout errors, not auth errors
                        if "401" in error_str or "invalid_api_key" in error_str.lower() or "quota" in error_str.lower():
                            raise  # Don't retry auth/quota errors
                        logger.warning(f"API call failed (attempt {attempt + 1}/{max_retries}), retrying in {retry_delay}s: {retry_error}")
                        time.sleep(retry_delay)
                        retry_delay *= 2  # Exponential backoff
                    else:
                        raise  # Last attempt failed, re-raise
            
            content = response.choices[0].message.content
            if not content:
                return []
            
            # Extract JSON from response
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                data = json.loads(json_match.group())
                return data.get("offers", [])
            
            return []
            
        except QuotaExceededError:
            raise  # Re-raise quota errors
        except APIConnectionError:
            raise  # Re-raise connection errors
        except Exception as e:
            error_str = str(e) if e else ""
            error_type = type(e).__name__
            
            # Check for quota errors (401, 429, insufficient_quota)
            if error_str and ("429" in error_str or "insufficient_quota" in error_str.lower() or "quota" in error_str.lower() or "401" in error_str):
                logger.error(f"OpenAI API quota/auth error: {e}")
                raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
            
            # Check for connection errors - but be more careful
            # Only raise APIConnectionError for actual connection issues, not other errors
            if error_type in ['ConnectionError', 'Timeout', 'ConnectTimeout', 'ReadTimeout']:
                logger.error(f"OpenAI API connection error: {e}")
                raise APIConnectionError(f"OpenAI API connection failed: {e}")
            elif error_str and ("connection" in error_str.lower() or "timeout" in error_str.lower() or "network" in error_str.lower()):
                # Log but don't raise - might be a temporary issue
                logger.warning(f"Possible connection issue (retrying): {e}")
                # Don't raise APIConnectionError immediately - let it retry
                
            logger.error(f"GPT Vision API error on page {page_num}: {e} (type: {error_type})")
            return []
    
    def _call_vision_api_structured(self, image, prompt: str, page_num: int, week_key: str) -> List[Dict[str, Any]]:
        """Call GPT Vision API with structured prompt and parse response"""
        logger.debug(f"Page {page_num}: Preparing structured API call...")
        try:
            # Convert PIL image to base64
            buffered = BytesIO()
            image.save(buffered, format="PNG")
            img_base64 = base64.b64encode(buffered.getvalue()).decode()
            
            # Retry logic for connection issues
            max_retries = 3
            retry_delay = 2
            
            for attempt in range(max_retries):
                try:
                    if attempt > 0:
                        logger.info(f"Page {page_num}: Structured API call attempt {attempt + 1}/{max_retries}")
                        print(f"      🔄 Retry {attempt + 1}/{max_retries}...", flush=True)
                    else:
                        logger.debug(f"Page {page_num}: Sending structured request to GPT Vision API...")
                        print(f"      📤 Sending structured request...", flush=True)
                    
                    response = self.client.chat.completions.create(
                        model="gpt-4o-mini",
                        messages=[
                            {
                                "role": "system",
                                "content": "You are an expert at extracting structured data from supermarket leaflet images. Respond ONLY with valid JSON. No explanations."
                            },
                            {
                                "role": "user",
                                "content": [
                                    {"type": "text", "text": prompt},
                                    {
                                        "type": "image_url",
                                        "image_url": {
                                            "url": f"data:image/png;base64,{img_base64}",
                                            "detail": "high"
                                        }
                                    }
                                ]
                            }
                        ],
                        max_tokens=4000,
                        temperature=0,
                        timeout=90
                    )
                    logger.debug(f"Page {page_num}: Received structured response from GPT Vision API")
                    print(f"      ✅ Received structured response", flush=True)
                    break  # Success, exit retry loop
                except QuotaExceededError:
                    raise  # Don't retry quota errors
                except APIConnectionError:
                    raise  # Don't retry connection errors if explicitly raised
                except Exception as retry_error:
                    if attempt < max_retries - 1:
                        error_str = str(retry_error) if retry_error else ""
                        if "401" in error_str or "invalid_api_key" in error_str.lower() or "quota" in error_str.lower():
                            raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
                        logger.warning(f"Structured API call failed (attempt {attempt + 1}/{max_retries}), retrying in {retry_delay}s: {retry_error}")
                        time.sleep(retry_delay)
                        retry_delay *= 2
                    else:
                        # Last attempt failed - check error type
                        error_str = str(retry_error) if retry_error else ""
                        if "401" in error_str or "invalid_api_key" in error_str.lower():
                            raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
                        logger.error(f"Structured GPT Vision API error after {max_retries} attempts: {retry_error}")
                        raise
            
            content = response.choices[0].message.content
            if not content:
                logger.warning(f"Page {page_num}: Empty response from GPT Vision API")
                return []
            
            # Extract JSON from response (handle both full object and just offers array)
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                data = json.loads(json_match.group())
                # Handle new structured format
                if "offers" in data:
                    offers = data.get("offers", [])
                    # Convert structured format to old format for compatibility
                    return self._convert_structured_offers(offers, page_num, week_key)
                # Fallback: if it's already an array
                if isinstance(data, list):
                    return self._convert_structured_offers(data, page_num, week_key)
            
            logger.warning(f"Page {page_num}: Could not parse JSON from response")
            return []
            
        except QuotaExceededError:
            raise  # Re-raise quota errors
        except APIConnectionError:
            raise  # Re-raise connection errors
        except Exception as e:
            error_str = str(e) if e else ""
            error_type = type(e).__name__
            
            # Check for quota/auth errors (401, 429, insufficient_quota)
            if error_str and ("429" in error_str or "insufficient_quota" in error_str.lower() or "quota" in error_str.lower() or "401" in error_str):
                logger.error(f"OpenAI API quota/auth error: {e}")
                raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
            
            # Check for connection errors
            if error_type in ['ConnectionError', 'Timeout', 'ConnectTimeout', 'ReadTimeout']:
                logger.error(f"OpenAI API connection error: {e}")
                raise APIConnectionError(f"OpenAI API connection failed: {e}")
            
            logger.error(f"Structured GPT Vision API error on page {page_num}: {e} (type: {error_type})")
            return []
    
    def _convert_structured_offers(self, structured_offers: List[Dict[str, Any]], page_num: int, week_key: str) -> List[Dict[str, Any]]:
        """Convert new structured offer format to old format for compatibility"""
        converted = []
        for idx, offer in enumerate(structured_offers):
            # Extract data from structured format
            product = offer.get("product", {})
            size = offer.get("size", {})
            pricing = offer.get("pricing", {})
            conditions = offer.get("conditions", {})
            meta = offer.get("meta", {})
            
            # Convert to old format
            converted_offer = {
                "name": product.get("title"),
                "brand": product.get("brand"),
                "variant": product.get("variant"),
                "category": product.get("category_guess"),
                "price": pricing.get("price_current"),
                "regular_price": pricing.get("price_regular"),
                "price_before": pricing.get("price_before"),
                "discount": pricing.get("discount_percent"),
                "unit": size.get("unit"),
                "amount": size.get("amount"),
                "pack_count": size.get("pack_count"),
                "loyalty_price": None,
                "loyalty_label": conditions.get("loyalty"),
                "uvp_price": pricing.get("price_before"),
                "multi_price_info": None,
                "confidence": meta.get("confidence", 0.8),
                "flags": meta.get("flags", []),
                "raw_text": meta.get("raw_text_snippet"),
            }
            
            # Handle price_options (loyalty prices, multi-price)
            price_options = pricing.get("price_options", [])
            if price_options:
                loyalty_prices = [opt for opt in price_options if opt.get("is_loyalty_required")]
                if loyalty_prices:
                    converted_offer["loyalty_price"] = loyalty_prices[0].get("price")
                    converted_offer["loyalty_label"] = loyalty_prices[0].get("condition")
                if len(price_options) > 1:
                    converted_offer["multi_price_info"] = ", ".join([f"{opt.get('price')} {opt.get('condition', '')}" for opt in price_options])
            
            # Handle base_price
            base_price = pricing.get("base_price", {})
            if base_price.get("value") and not converted_offer.get("unit"):
                converted_offer["unit"] = base_price.get("unit")
            
            converted.append(converted_offer)
        
        return converted
    
    def _call_vision_api_raw(self, image, prompt: str) -> str:
        """Call GPT Vision API and return raw text response"""
        max_retries = 3
        retry_delay = 2
        
        buffered = BytesIO()
        image.save(buffered, format="PNG")
        img_base64 = base64.b64encode(buffered.getvalue()).decode()
        
        for attempt in range(max_retries):
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
                                    "image_url": {
                                        "url": f"data:image/png;base64,{img_base64}",
                                        "detail": "high"
                                    }
                                }
                            ]
                        }
                    ],
                    max_tokens=100,
                    temperature=0,
                    timeout=90
                )
                
                return response.choices[0].message.content or ""
            except QuotaExceededError:
                raise  # Don't retry quota errors
            except APIConnectionError:
                raise  # Don't retry connection errors if explicitly raised
            except Exception as retry_error:
                if attempt < max_retries - 1:
                    error_str = str(retry_error) if retry_error else ""
                    if "401" in error_str or "invalid_api_key" in error_str.lower() or "quota" in error_str.lower():
                        raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
                    logger.warning(f"API call failed (attempt {attempt + 1}/{max_retries}), retrying in {retry_delay}s: {retry_error}")
                    time.sleep(retry_delay)
                    retry_delay *= 2
                else:
                    # Last attempt failed - check error type
                    error_str = str(retry_error) if retry_error else ""
                    if "401" in error_str or "invalid_api_key" in error_str.lower():
                        raise QuotaExceededError("OpenAI API quota exceeded or invalid API key")
                    logger.error(f"GPT Vision API error after {max_retries} attempts: {retry_error}")
                    raise
    
    def _merge_microtext(
        self, existing_offers: List[Dict[str, Any]], microtext_offers: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Merge microtext data into existing offers"""
        # Match by name similarity
        for existing in existing_offers:
            best_match = None
            best_score = 0.0
            
            for micro in microtext_offers:
                score = self._name_similarity(existing.get("name", ""), micro.get("name", ""))
                if score > best_score and score > 0.7:
                    best_match = micro
                    best_score = score
            
            if best_match:
                # Merge microtext data
                if best_match.get("loyalty_price"):
                    existing["loyalty_price"] = best_match["loyalty_price"]
                    existing["loyalty_label"] = best_match.get("loyalty_label")
                if best_match.get("uvp_price"):
                    existing["uvp_price"] = best_match["uvp_price"]
                if best_match.get("multi_price_info"):
                    existing["multi_price_info"] = best_match["multi_price_info"]
                if best_match.get("valid_from"):
                    existing["valid_from"] = best_match["valid_from"]
                if best_match.get("valid_to"):
                    existing["valid_to"] = best_match["valid_to"]
        
        return existing_offers
    
    def _name_similarity(self, name1: str, name2: str) -> float:
        """Calculate name similarity score"""
        from difflib import SequenceMatcher
        name1 = str(name1).lower() if name1 else ""
        name2 = str(name2).lower() if name2 else ""
        return SequenceMatcher(None, name1, name2).ratio()
    
    def _offer_key(self, offer: Dict[str, Any]) -> str:
        """Generate unique key for offer deduplication"""
        name = str(offer.get("name", "") or "").lower().strip()
        price = offer.get("price", 0)
        unit = str(offer.get("unit", "") or "").lower().strip()
        return f"{name}|{price}|{unit}"
    
    def _deduplicate_offers(self, offers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Remove duplicate offers"""
        seen = set()
        unique = []
        
        for offer in offers:
            key = self._offer_key(offer)
            if key not in seen:
                seen.add(key)
                unique.append(offer)
        
        return unique

