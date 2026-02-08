"""Cached pipeline with resume support and targeted verification"""

import json
import hashlib
import logging
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime

from ..extract.gpt_vision_extractor import GPTVisionExtractor, QuotaExceededError, APIConnectionError
from ..extract.list_parser import ListParser
from ..extract.pdf_extractor import PDFExtractor
from ..normalize.normalizer import Normalizer
from ..reconcile.reconciler import Reconciler
from ..validate.validators import Validator
from ..generate.recipe_generator import RecipeGenerator
from ..enrich.availability_checker import AvailabilityChecker
from ..enrich.nutrition_database import NutritionDatabase
from ..enrich.image_generator import ImageGenerator

logger = logging.getLogger(__name__)


class CachedPipeline:
    """Pipeline with caching and targeted verification"""
    
    def __init__(
        self,
        supermarket: str,
        week_key: str,
        out_dir: Path,
        pdf_path: Optional[Path] = None,
        raw_list_path: Optional[Path] = None,
        max_loops: int = 10
    ):
        self.supermarket = supermarket
        self.week_key = week_key
        self.out_dir = Path(out_dir)
        self.pdf_path = pdf_path
        self.raw_list_path = raw_list_path
        self.max_loops = max_loops
        
        # Cache directories
        self.cache_dir = self.out_dir / "cache" / supermarket / week_key
        self.pages_dir = self.cache_dir / "pages"
        self.pages_dir.mkdir(parents=True, exist_ok=True)
        
        # Output directories
        (self.out_dir / "offers").mkdir(parents=True, exist_ok=True)
        (self.out_dir / "reports").mkdir(parents=True, exist_ok=True)
        (self.out_dir / "recipes").mkdir(parents=True, exist_ok=True)
        (self.out_dir / "images").mkdir(parents=True, exist_ok=True)
        
        self.vision_extractor = GPTVisionExtractor(supermarket) if pdf_path else None
        self.gpt_calls = 0
    
    def run(self) -> Dict[str, Any]:
        """Run the complete pipeline"""
        try:
            # Phase 0: Load & Render (once)
            gpt_vision_available = True
            if self.pdf_path and self.pdf_path.exists():
                try:
                    pages_rendered = self._phase0_render()
                except (QuotaExceededError, APIConnectionError) as e:
                    error_type = "quota exceeded" if isinstance(e, QuotaExceededError) else "connection error"
                    logger.warning(f"GPT Vision {error_type}, falling back to traditional PDF extraction")
                    gpt_vision_available = False
                    pages_rendered = []
                except Exception as e:
                    logger.warning(f"GPT Vision failed: {e}, falling back to traditional PDF extraction")
                    gpt_vision_available = False
                    pages_rendered = []
            else:
                pages_rendered = []
            
            # Phase 1: Tile Consensus (only if GPT Vision available)
            if pages_rendered and gpt_vision_available:
                try:
                    tile_data = self._phase1_tile_consensus(pages_rendered)
                except (QuotaExceededError, APIConnectionError) as e:
                    error_type = "quota exceeded" if isinstance(e, QuotaExceededError) else "connection error"
                    logger.warning(f"GPT Vision {error_type} during tile consensus, using traditional extraction")
                    gpt_vision_available = False
                    tile_data = {}
                except Exception as e:
                    logger.warning(f"Tile consensus failed: {e}, using traditional extraction")
                    gpt_vision_available = False
                    tile_data = {}
            else:
                tile_data = {}
            
            # Phase 2: Per-Page Extraction
            if pages_rendered and gpt_vision_available:
                try:
                    page_offers = self._phase2_extract_pages(pages_rendered, tile_data)
                except (QuotaExceededError, APIConnectionError) as e:
                    error_type = "quota exceeded" if isinstance(e, QuotaExceededError) else "connection error"
                    logger.warning(f"GPT Vision {error_type} during extraction, using traditional PDF extraction")
                    gpt_vision_available = False
                    page_offers = self._phase2_traditional_pdf_extraction()
                except Exception as e:
                    logger.warning(f"GPT Vision extraction failed: {e}, using traditional PDF extraction")
                    gpt_vision_available = False
                    page_offers = self._phase2_traditional_pdf_extraction()
            elif self.pdf_path and self.pdf_path.exists() and not gpt_vision_available:
                # Use traditional PDF extraction
                page_offers = self._phase2_traditional_pdf_extraction()
            else:
                page_offers = []
            
            # Phase 3: RAW Ingest
            raw_offers = self._phase3_raw_ingest()
            logger.info(f"Phase 3: Loaded {len(raw_offers)} RAW offers")
            
            # Phase 4: Reconciliation
            merged_offers, reconcile_report = self._phase4_reconcile(page_offers, raw_offers)
            logger.info(f"Phase 4: Merged to {len(merged_offers)} offers (PDF: {len(page_offers)}, RAW: {len(raw_offers)})")
            
            # Phase 5: Targeted Verification Loops (only if GPT Vision available)
            if gpt_vision_available and pages_rendered:
                try:
                    final_offers, page_quality = self._phase5_verification_loops(
                        pages_rendered, tile_data, merged_offers
                    )
                except (QuotaExceededError, APIConnectionError) as e:
                    error_type = "quota exceeded" if isinstance(e, QuotaExceededError) else "connection error"
                    logger.warning(f"{error_type.capitalize()} during verification, skipping verification loops")
                    final_offers = merged_offers
                    page_quality = {}
            else:
                final_offers = merged_offers
                page_quality = {}
            
            # Phase 6: Final Offers Output
            self._phase6_output_offers(final_offers)
            
            # Phase 7: Recipes (only if offers available)
            if final_offers:
                logger.info(f"Phase 7: Generating recipes from {len(final_offers)} offers...")
                recipes = self._phase7_generate_recipes(final_offers)
                logger.info(f"Phase 7: Generated {len(recipes)} recipes")
            else:
                logger.warning("Phase 7: No offers available, skipping recipe generation")
                recipes = []
            
            # Phase 8: Image Jobs
            image_jobs = self._phase8_image_jobs(recipes)
            
            # Phase 9: Manifest
            manifest_path = self._phase9_manifest(
                final_offers, recipes, page_quality, reconcile_report
            )
            
            return {
                "status": "OK",
                "manifestPath": str(manifest_path),
                "metrics": {
                    "offers": len(final_offers),
                    "recipes": len(recipes),
                    "gptCalls": self.gpt_calls,
                    "badPagesFinal": sum(1 for p in page_quality.values() if p.get("bad", False)),
                    "pagesProcessed": len(pages_rendered),
                }
            }
            
        except Exception as e:
            logger.error(f"Pipeline failed: {e}", exc_info=True)
            return {
                "status": "ERROR",
                "error": str(e),
                "manifestPath": None,
                "metrics": {}
            }
    
    def _phase0_render(self) -> List[Path]:
        """Render PDF pages to images (once)"""
        if not self.vision_extractor or not self.vision_extractor.client:
            return []
        
        logger.info("Phase 0: Rendering PDF pages...")
        
        try:
            from pdf2image import convert_from_path
            import warnings
            import logging
            
            # Suppress pdf2image warnings
            warnings.filterwarnings("ignore", category=UserWarning)
            pdf2image_logger = logging.getLogger("pdf2image")
            pdf2image_logger.setLevel(logging.ERROR)
            
            images = convert_from_path(str(self.pdf_path), dpi=250)
            
            page_paths = []
            for page_num, image in enumerate(images, 1):
                page_path = self.pages_dir / f"page_{page_num}.png"
                
                # Skip if already rendered
                if page_path.exists():
                    logger.debug(f"Page {page_num} already rendered, skipping")
                    page_paths.append(page_path)
                    continue
                
                image.save(page_path, "PNG")
                page_paths.append(page_path)
                logger.info(f"Rendered page {page_num}/{len(images)}")
            
            return page_paths
            
        except Exception as e:
            logger.error(f"Failed to render PDF: {e}")
            return []
    
    def _phase1_tile_consensus(self, page_paths: List[Path]) -> Dict[int, Dict[str, Any]]:
        """Tile consensus - count tiles 2-3 times, take median"""
        logger.info("Phase 1: Tile consensus...")
        
        tile_data = {}
        
        for page_path in page_paths:
            page_num = int(page_path.stem.split("_")[1])
            tile_cache = self.cache_dir / f"page_{page_num}_tiles.json"
            
            # Load from cache if exists
            if tile_cache.exists():
                try:
                    tile_data[page_num] = json.load(open(tile_cache))
                    logger.debug(f"Page {page_num}: Loaded tile data from cache")
                    continue
                except:
                    pass
            
            # Run tile discovery 2-3 times
            counts = []
            descriptors_list = []
            
            for attempt in range(3):
                try:
                    count, descriptors = self._discover_tiles(page_path, page_num)
                    counts.append(count)
                    descriptors_list.append(descriptors)
                    self.gpt_calls += 1
                    
                    # If first two match, skip third
                    if attempt == 1 and counts[0] == counts[1]:
                        break
                except Exception as e:
                    logger.warning(f"Tile discovery attempt {attempt+1} failed: {e}")
                    continue
            
            # Take median count
            if counts:
                counts.sort()
                median_count = counts[len(counts) // 2]
                # Use descriptors from attempt with count closest to median
                best_descriptors = descriptors_list[0]
                for i, c in enumerate(counts):
                    if abs(c - median_count) < abs(counts[0] - median_count):
                        best_descriptors = descriptors_list[i]
            else:
                median_count = 0
                best_descriptors = []
            
            tile_info = {
                "tileCount": median_count,
                "descriptors": best_descriptors,
                "confidence": 0.9 if len(counts) >= 2 and counts[0] == counts[1] else 0.7,
                "attempts": len(counts),
            }
            
            tile_data[page_num] = tile_info
            
            # Save to cache
            with open(tile_cache, 'w') as f:
                json.dump(tile_info, f, indent=2)
            
            logger.info(f"Page {page_num}: {median_count} tiles (confidence: {tile_info['confidence']})")
        
        return tile_data
    
    def _discover_tiles(self, page_path: Path, page_num: int) -> Tuple[int, List[str]]:
        """Discover tiles on a page"""
        from PIL import Image
        
        image = Image.open(page_path)
        
        prompt = """Zähle die Anzahl der Angebots-Tiles auf dieser Prospektseite.

Ein Tile ist ein Angebot, wenn es:
- Ein Produkt zeigt (Lebensmittel/Getränk)
- Einen Preis zeigt
- Ein abgegrenztes Element ist (Box, Rahmen, etc.)

IGNORIERE:
- Überschriften, Logos
- Rezepte ohne Preis
- Allgemeine Textblöcke
- Gutscheine ohne Produktpreis

Antworte NUR mit JSON:
{
  "tileCount": <zahl>,
  "descriptors": ["kurze Beschreibung Tile 1", "kurze Beschreibung Tile 2", ...]
}"""
        
        try:
            # Call GPT Vision API directly
            response = self.vision_extractor._call_vision_api_raw(image, prompt)
            
            # Parse JSON response
            import re
            json_match = re.search(r'\{[\s\S]*\}', response)
            if json_match:
                data = json.loads(json_match.group())
                tile_count = data.get("tileCount", 0)
                descriptors = data.get("descriptors", [])
            else:
                # Fallback: try to extract number
                numbers = re.findall(r'\d+', response)
                tile_count = int(numbers[0]) if numbers else 0
                descriptors = []
            
            return tile_count, descriptors
            
        except Exception as e:
            logger.error(f"Tile discovery failed for page {page_num}: {e}")
            return 0, []
    
    def _phase2_extract_pages(
        self, page_paths: List[Path], tile_data: Dict[int, Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """Extract offers from each page (with cache)"""
        logger.info("Phase 2: Per-page extraction...")
        
        all_offers = []
        
        for page_path in page_paths:
            page_num = int(page_path.stem.split("_")[1])
            offers_cache = self.cache_dir / f"page_{page_num}_offers.json"
            
            # Load from cache if exists
            if offers_cache.exists():
                try:
                    cached_offers = json.load(open(offers_cache))
                    all_offers.extend(cached_offers)
                    logger.debug(f"Page {page_num}: Loaded {len(cached_offers)} offers from cache")
                    continue
                except:
                    pass
            
            # Extract offers
            page_offers = self._extract_page_offers(page_path, page_num, tile_data.get(page_num, {}))
            
            # Save to cache
            with open(offers_cache, 'w') as f:
                json.dump(page_offers, f, indent=2)
            
            all_offers.extend(page_offers)
            logger.info(f"Page {page_num}: Extracted {len(page_offers)} offers")
        
        return all_offers
    
    def _extract_page_offers(
        self, page_path: Path, page_num: int, tile_info: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Extract offers from a single page"""
        from PIL import Image
        
        image = Image.open(page_path)
        
        # Initial extraction
        prompt = """Extrahiere ALLE Lebensmittel-Angebote von dieser Prospektseite.

Für jedes Angebot:
- name: Produktname
- brand: Marke (falls sichtbar)
- unitText: Einheit (z.B. "500g", "1kg", "6x1,5L")
- basePrice: Standardpreis (Zahl)
- loyaltyPrice: Preis mit Karte/Bonus (nur wenn explizit markiert)
- loyaltyLabel: Label (z.B. "Kaufland Card", "REWE Bonus")
- priceMechanic: "single"|"multi"|"bundle"|"uvp_shown"|"percent_only"
- notes: Zusätzliche Info (UVP, "2 Preise sichtbar", etc.)
- category: "food"|"drink"|"other"

WICHTIG:
- Wenn Preis mit "Karte", "App", "Bonus" markiert => loyaltyPrice + loyaltyLabel
- Wenn 2 Preise, nur einer markiert => markierter = loyaltyPrice, unmarkierter = basePrice
- Wenn 2 Preise, beide unmarkiert => basePrice=null, flag MULTI_PRICE_UNLABELED
- UVP ist KEIN Verkaufspreis, nur in notes

ANTWORT FORMAT (NUR JSON):
{
  "offers": [
    {
      "name": "...",
      "brand": null,
      "unitText": "...",
      "basePrice": 2.99,
      "loyaltyPrice": null,
      "loyaltyLabel": null,
      "currency": "EUR",
      "priceMechanic": "single",
      "notes": null,
      "category": "food",
      "sourcePage": 1,
      "flags": []
    }
  ]
}"""
        
        try:
            offers_list = self.vision_extractor._call_vision_api(image, prompt, page_num)
        except APIConnectionError:
            # Connection error - abort this page, will trigger fallback
            raise
        except Exception as e:
            logger.warning(f"Failed to extract offers from page {page_num}: {e}")
            offers_list = []
        self.gpt_calls += 1
        
        # Ensure it's a list
        if isinstance(offers_list, list):
            offers = offers_list
        elif isinstance(offers_list, dict) and "offers" in offers_list:
            offers = offers_list["offers"]
        else:
            offers = []
        
        # Add source page
        for offer in offers:
            offer["sourcePage"] = page_num
            if not offer.get("currency"):
                offer["currency"] = "EUR"
        
        # Check completeness
        tile_count = tile_info.get("tileCount", 0)
        if tile_count > len(offers) * 1.1:  # 10% gap
            logger.info(f"Page {page_num}: Missing offers detected ({len(offers)}/{tile_count}), running missing-only pass...")
            
            # Missing-only pass
            missing_prompt = """Suche nach WEITEREN Lebensmittel-Angeboten, die übersehen wurden.

Konzentriere dich auf:
- Kleine Angebote
- Randbereiche
- Angebote zwischen anderen Elementen

Extrahiere NUR Angebote, die noch nicht erfasst wurden.

ANTWORT FORMAT (NUR JSON):
{
  "offers": [...]
}"""
            
            missing_offers = self.vision_extractor._call_vision_api(image, missing_prompt, page_num)
            self.gpt_calls += 1
            
            if isinstance(missing_offers, list):
                # Add source page
                for offer in missing_offers:
                    offer["sourcePage"] = page_num
                    if not offer.get("currency"):
                        offer["currency"] = "EUR"
                
                # Merge (deduplicate by name+price)
                existing_keys = {(o.get("name", ""), o.get("basePrice")) for o in offers}
                for offer in missing_offers:
                    key = (offer.get("name", ""), offer.get("basePrice"))
                    if key not in existing_keys:
                        offers.append(offer)
                        existing_keys.add(key)
        
        return offers
    
    def _phase3_raw_ingest(self) -> List[Dict[str, Any]]:
        """Load and normalize RAW offers"""
        if not self.raw_list_path or not self.raw_list_path.exists():
            return []
        
        logger.info("Phase 3: RAW ingest...")
        
        try:
            parser = ListParser(self.supermarket)
            raw_offers = parser.parse(self.raw_list_path, self.week_key)
            
            # Normalize to OfferDraft format
            normalized = []
            for raw in raw_offers:
                if isinstance(raw, dict):
                    # Extract title/name
                    title = raw.get("title") or raw.get("name", "")
                    if not title:
                        continue  # Skip offers without title
                    
                    # Extract base price from prices array
                    base_price = self._extract_base_price(raw)
                    if base_price is None:
                        # Try to get from prices array
                        prices = raw.get("prices", [])
                        if prices and isinstance(prices, list):
                            for price_item in prices:
                                if isinstance(price_item, dict):
                                    if price_item.get("condition", {}).get("type") == "standard":
                                        base_price = price_item.get("amount")
                                        break
                    
                    if base_price is None:
                        continue  # Skip offers without price
                    
                    draft = {
                        "name": title,
                        "brand": raw.get("brand"),
                        "unitText": self._format_unit(raw.get("quantity", {})),
                        "basePrice": base_price,
                        "loyaltyPrice": self._extract_loyalty_price(raw),
                        "loyaltyLabel": self._extract_loyalty_label(raw),
                        "currency": "EUR",
                        "priceMechanic": "single",
                        "notes": None,
                        "category": raw.get("category", "food"),
                        "sourcePage": None,
                        "flags": raw.get("flags", []),
                        "source": "raw",
                        "confidence": raw.get("confidence", "medium"),
                    }
                    normalized.append(draft)
                else:
                    logger.debug(f"Skipping offer without title or price: {raw}")
            
            logger.info(f"Loaded {len(normalized)} RAW offers from {len(raw_offers)} parsed offers")
            return normalized
            
        except Exception as e:
            logger.error(f"RAW ingest failed: {e}")
            return []
    
    def _format_unit(self, quantity: Dict) -> Optional[str]:
        """Format quantity to unitText"""
        if isinstance(quantity, dict):
            value = quantity.get("value")
            unit = quantity.get("unit")
            if value and unit:
                return f"{int(value)}{unit}" if value == int(value) else f"{value}{unit}"
        return None
    
    def _extract_base_price(self, offer: Dict) -> Optional[float]:
        """Extract base price from offer"""
        # Try priceTiers first
        price_tiers = offer.get("priceTiers", [])
        for tier in price_tiers:
            if isinstance(tier, dict):
                condition = tier.get("condition", {})
                if isinstance(condition, dict) and condition.get("type") == "standard":
                    return tier.get("amount")
            elif hasattr(tier, "condition") and tier.condition.type == "standard":
                return tier.amount
        
        # Fallback: try prices array
        prices = offer.get("prices", [])
        if prices and isinstance(prices, list):
            for price_item in prices:
                if isinstance(price_item, dict):
                    # Check if it's a standard price (not reference, not loyalty)
                    condition = price_item.get("condition", {})
                    if isinstance(condition, dict):
                        price_type = condition.get("type", "standard")
                        is_reference = price_item.get("is_reference", False)
                        if price_type == "standard" and not is_reference:
                            return price_item.get("amount")
                    elif not condition:  # Simple dict with amount
                        return price_item.get("amount")
        
        return None
    
    def _extract_loyalty_price(self, offer: Dict) -> Optional[float]:
        """Extract loyalty price from offer"""
        price_tiers = offer.get("priceTiers", [])
        for tier in price_tiers:
            if isinstance(tier, dict):
                condition = tier.get("condition", {})
                if isinstance(condition, dict) and condition.get("type") == "loyalty":
                    return tier.get("amount")
            elif hasattr(tier, "condition") and tier.condition.type == "loyalty":
                return tier.amount
        return None
    
    def _extract_loyalty_label(self, offer: Dict) -> Optional[str]:
        """Extract loyalty label from offer"""
        price_tiers = offer.get("priceTiers", [])
        for tier in price_tiers:
            if isinstance(tier, dict):
                condition = tier.get("condition", {})
                if isinstance(condition, dict) and condition.get("type") == "loyalty":
                    return condition.get("label")
            elif hasattr(tier, "condition") and tier.condition.type == "loyalty":
                return tier.condition.label
        return None
    
    def _phase4_reconcile(
        self, pdf_offers: List[Dict], raw_offers: List[Dict]
    ) -> Tuple[List[Dict], Dict[str, Any]]:
        """Reconcile PDF and RAW offers"""
        logger.info("Phase 4: Reconciliation...")
        
        # Normalize offers to Offer objects for reconciliation
        normalizer = Normalizer(self.supermarket, self.week_key)
        pdf_normalized = normalizer.normalize(pdf_offers) if pdf_offers else []
        raw_normalized = normalizer.normalize(raw_offers) if raw_offers else []
        
        # Reconcile
        reconciler = Reconciler()
        merged, report = reconciler.reconcile(raw_normalized, pdf_normalized)
        
        # Convert back to dicts
        merged_dicts = []
        for offer in merged:
            if isinstance(offer, dict):
                merged_dicts.append(offer)
            else:
                # Convert Offer object to dict
                merged_dicts.append(self._offer_to_draft(offer))
        
        # Write reconcile report
        reconcile_path = self.out_dir / "reports" / f"reconcile_{self.supermarket}_{self.week_key}.json"
        with open(reconcile_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        logger.info(f"Reconciled: {len(merged_dicts)} offers (PDF: {len(pdf_offers)}, RAW: {len(raw_offers)})")
        
        return merged_dicts, report
    
    def _offer_to_draft(self, offer) -> Dict[str, Any]:
        """Convert Offer object to OfferDraft dict"""
        if isinstance(offer, dict):
            return offer
        
        # Extract base price
        base_price = None
        for tier in offer.price_tiers:
            if tier.condition.type == "standard":
                base_price = tier.amount
                break
        
        # Extract loyalty price
        loyalty_price = None
        loyalty_label = None
        for tier in offer.price_tiers:
            if tier.condition.type == "loyalty":
                loyalty_price = tier.amount
                loyalty_label = tier.condition.label
                break
        
        # Format unit
        unit_text = None
        if offer.quantity.value and offer.quantity.unit:
            unit_text = f"{int(offer.quantity.value) if offer.quantity.value == int(offer.quantity.value) else offer.quantity.value}{offer.quantity.unit}"
        
        return {
            "name": offer.title,
            "brand": offer.brand,
            "unitText": unit_text,
            "basePrice": base_price,
            "loyaltyPrice": loyalty_price,
            "loyaltyLabel": loyalty_label,
            "currency": "EUR",
            "priceMechanic": "single",
            "notes": None,
            "category": offer.category or "food",
            "sourcePage": None,
            "flags": offer.flags if hasattr(offer, 'flags') else [],
            "source": "merged",
        }
    
    def _phase5_verification_loops(
        self,
        page_paths: List[Path],
        tile_data: Dict[int, Dict[str, Any]],
        merged_offers: List[Dict]
    ) -> Tuple[List[Dict], Dict[int, Dict[str, Any]]]:
        """Targeted verification loops - only recheck bad pages"""
        logger.info("Phase 5: Targeted verification loops...")
        
        page_quality = {}
        final_offers = merged_offers.copy()
        
        for loop in range(1, self.max_loops + 1):
            logger.info(f"Verification loop {loop}/{self.max_loops}")
            
            # Compute page quality metrics
            bad_pages = []
            for page_path in page_paths:
                page_num = int(page_path.stem.split("_")[1])
                page_offers = [o for o in final_offers if o.get("sourcePage") == page_num]
                
                tile_count = tile_data.get(page_num, {}).get("tileCount", 0)
                extracted_count = len(page_offers)
                missing_ratio = (tile_count - extracted_count) / max(tile_count, 1) if tile_count > 0 else 0
                tile_confidence = tile_data.get(page_num, {}).get("confidence", 0.5)
                
                # Count MULTI_PRICE_UNLABELED flags
                multi_price_count = sum(1 for o in page_offers if "MULTI_PRICE_UNLABELED" in o.get("flags", []))
                multi_price_ratio = multi_price_count / max(extracted_count, 1)
                
                is_bad = (
                    missing_ratio > 0.10 or
                    tile_confidence < 0.6 or
                    multi_price_ratio > 0.2
                )
                
                page_quality[page_num] = {
                    "tileCount": tile_count,
                    "extractedCount": extracted_count,
                    "missingRatio": missing_ratio,
                    "tileConfidence": tile_confidence,
                    "multiPriceRatio": multi_price_ratio,
                    "bad": is_bad,
                }
                
                if is_bad:
                    bad_pages.append((page_num, page_path))
            
            # Stop if no bad pages
            if not bad_pages:
                logger.info(f"✅ No bad pages after loop {loop}")
                break
            
            logger.info(f"Found {len(bad_pages)} bad pages, rechecking...")
            
            # Recheck bad pages only
            for page_num, page_path in bad_pages:
                logger.info(f"Rechecking page {page_num}...")
                
                # Re-run tile discovery once
                tile_count, descriptors = self._discover_tiles(page_path, page_num)
                self.gpt_calls += 1
                tile_data[page_num]["tileCount"] = tile_count
                
                # Run missing-only extraction once
                from PIL import Image
                image = Image.open(page_path)
                
                missing_prompt = """Suche nach WEITEREN Lebensmittel-Angeboten auf dieser Seite.

Extrahiere NUR Angebote, die noch nicht erfasst wurden.

ANTWORT FORMAT (NUR JSON):
{
  "offers": [...]
}"""
                
                missing_result = self.vision_extractor._call_vision_api(image, missing_prompt, page_num)
                self.gpt_calls += 1
                
                # Parse missing offers
                if isinstance(missing_result, list):
                    missing_offers = missing_result
                elif isinstance(missing_result, dict) and "offers" in missing_result:
                    missing_offers = missing_result["offers"]
                else:
                    missing_offers = []
                
                if missing_offers:
                    # Add to final offers
                    existing_keys = {(o.get("name", ""), o.get("basePrice")) for o in final_offers}
                    for offer in missing_offers:
                        offer["sourcePage"] = page_num
                        key = (offer.get("name", ""), offer.get("basePrice"))
                        if key not in existing_keys:
                            final_offers.append(offer)
                    
                    # Update cache
                    offers_cache = self.cache_dir / f"page_{page_num}_offers.json"
                    page_offers = [o for o in final_offers if o.get("sourcePage") == page_num]
                    with open(offers_cache, 'w') as f:
                        json.dump(page_offers, f, indent=2)
        
        # Write page quality report
        quality_path = self.out_dir / "reports" / f"page_quality_{self.supermarket}_{self.week_key}.json"
        with open(quality_path, 'w') as f:
            json.dump(page_quality, f, indent=2)
        
        return final_offers, page_quality
    
    def _phase2_traditional_pdf_extraction(self) -> List[Dict[str, Any]]:
        """Fallback: Traditional PDF text extraction when GPT Vision unavailable"""
        logger.info("Using traditional PDF extraction (GPT Vision not available)")
        
        if not self.pdf_path or not self.pdf_path.exists():
            return []
        
        try:
            import warnings
            import logging
            
            # Suppress pdfminer/pdf2image warnings
            warnings.filterwarnings("ignore", category=UserWarning)
            pdfminer_logger = logging.getLogger("pdfminer")
            pdfminer_logger.setLevel(logging.ERROR)
            
            from ..extract.pdf_extractor import PDFExtractor
            extractor = PDFExtractor(self.supermarket)
            offers = extractor.extract(self.pdf_path, self.week_key)
            
            # Convert to dict format
            offers_dicts = []
            for offer in offers:
                if isinstance(offer, dict):
                    offers_dicts.append(offer)
                else:
                    # Convert Offer object to dict
                    offers_dicts.append({
                        "name": getattr(offer, "title", ""),
                        "basePrice": getattr(offer, "base_price", {}).get("amount") if hasattr(offer, "base_price") else None,
                        "currency": "EUR",
                        "source": "pdf_traditional",
                        "confidence": "low",
                    })
            
            logger.info(f"Extracted {len(offers_dicts)} offers using traditional PDF extraction")
            return offers_dicts
            
        except Exception as e:
            logger.error(f"Traditional PDF extraction failed: {e}")
            return []
    
    def _phase6_output_offers(self, offers: List[Dict]):
        """Write final offers JSON"""
        logger.info("Phase 6: Output offers...")
        
        # Add stable IDs
        for offer in offers:
            if not offer.get("id"):
                id_string = f"{self.supermarket}{self.week_key}{offer.get('name', '')}{offer.get('basePrice', '')}"
                offer["id"] = hashlib.sha256(id_string.encode()).hexdigest()[:16]
        
        # Validate and flag
        validator = Validator()
        validated, flagged, _ = validator.validate(offers)
        
        # Write offers
        offers_path = self.out_dir / "offers" / f"offers_{self.supermarket}_{self.week_key}.json"
        with open(offers_path, 'w', encoding='utf-8') as f:
            json.dump([self._offer_to_draft(o) if not isinstance(o, dict) else o for o in validated], f, indent=2, ensure_ascii=False)
        
        # Write flagged
        flagged_path = self.out_dir / "reports" / f"flagged_{self.supermarket}_{self.week_key}.json"
        with open(flagged_path, 'w', encoding='utf-8') as f:
            json.dump(flagged, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Wrote {len(validated)} offers, {len(flagged)} flagged")
    
    def _phase7_generate_recipes(self, offers: List[Dict]) -> List[Dict]:
        """Generate 50-100 recipes with availability and nutrition"""
        logger.info("Phase 7: Generate recipes...")
        
        # Setup availability checker
        availability = AvailabilityChecker(self.supermarket, self.week_key)
        availability.set_offers(offers)
        
        # Setup nutrition database
        nutrition_db = NutritionDatabase()
        
        # Convert to Offer objects for generator
        normalizer = Normalizer(self.supermarket, self.week_key)
        offer_objects = normalizer.normalize(offers)
        
        # Check if normalization filtered out all offers
        if not offer_objects:
            logger.warning(f"Phase 7: All {len(offers)} offers were filtered out during normalization - skipping recipe generation")
            return []
        
        logger.info(f"Phase 7: Normalized {len(offers)} offers to {len(offer_objects)} valid Offer objects")
        
        generator = RecipeGenerator(self.supermarket, self.week_key)
        recipes = generator.generate(offer_objects, count=80)
        
        # Convert to dicts and enrich
        recipes_dicts = []
        for recipe in recipes:
            if isinstance(recipe, dict):
                recipe_dict = recipe
            else:
                recipe_dict = self._recipe_to_dict(recipe)
            
            # Enrich with availability
            for ingredient in recipe_dict.get("ingredients", []):
                ingredient_name = ingredient.get("name", "")
                availability_info = availability.check_ingredient(ingredient_name)
                ingredient["availability"] = availability_info
                ingredient["fromOffer"] = availability_info.get("source") == "offer"
            
            # Enrich with nutrition (if not already present)
            if not recipe_dict.get("nutritionRange"):
                ingredients = recipe_dict.get("ingredients", [])
                nutrition_ranges = nutrition_db.calculate_recipe_nutrition(ingredients)
                recipe_dict["nutritionRange"] = {
                    "kcal": [int(nutrition_ranges["kcal"][0]), int(nutrition_ranges["kcal"][1])],
                    "protein_g": [int(nutrition_ranges["protein"][0]), int(nutrition_ranges["protein"][1])],
                    "carbs_g": [int(nutrition_ranges["carbs"][0]), int(nutrition_ranges["carbs"][1])],
                    "fat_g": [int(nutrition_ranges["fat"][0]), int(nutrition_ranges["fat"][1])],
                }
            
            recipes_dicts.append(recipe_dict)
        
        # Write recipes
        recipes_path = self.out_dir / "recipes" / f"recipes_{self.supermarket}_{self.week_key}.json"
        with open(recipes_path, 'w', encoding='utf-8') as f:
            json.dump(recipes_dicts, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Generated {len(recipes_dicts)} recipes")
        return recipes_dicts
    
    def _recipe_to_dict(self, recipe) -> Dict[str, Any]:
        """Convert Recipe to dict"""
        if isinstance(recipe, dict):
            return recipe
        
        return {
            "id": recipe.id,
            "supermarket": recipe.supermarket,
            "weekKey": recipe.week_key,
            "shortTitle": recipe.title[:42] if len(recipe.title) > 42 else recipe.title,
            "servings": recipe.servings,
            "cookTimeMinutes": recipe.time_minutes,
            "ingredients": [
                {
                    "name": ing.name,
                    "amountText": f"{ing.amount}{ing.unit}" if ing.amount and ing.unit else "",
                    "fromOffer": ing.is_from_offer,
                    "matchedOfferId": ing.from_offer_id,
                }
                for ing in recipe.ingredients
            ],
            "steps": recipe.steps,
            "nutritionRange": {
                "kcal": [recipe.nutrition.kcal.min, recipe.nutrition.kcal.max] if recipe.nutrition.kcal else None,
                "protein_g": [recipe.nutrition.protein_g.min, recipe.nutrition.protein_g.max] if recipe.nutrition.protein_g else None,
                "carbs_g": [recipe.nutrition.carbs_g.min, recipe.nutrition.carbs_g.max] if recipe.nutrition.carbs_g else None,
                "fat_g": [recipe.nutrition.fat_g.min, recipe.nutrition.fat_g.max] if recipe.nutrition.fat_g else None,
            },
            "tags": recipe.tags,
        }
    
    def _phase8_image_jobs(self, recipes: List[Dict]) -> List[Dict]:
        """Create image generation jobs"""
        logger.info("Phase 8: Image jobs...")
        
        image_generator = ImageGenerator(self.supermarket, self.week_key)
        image_jobs = image_generator.create_image_jobs(recipes)
        
        # Write image jobs
        jobs_path = self.out_dir / "images" / f"image_jobs_{self.supermarket}_{self.week_key}.json"
        with open(jobs_path, 'w', encoding='utf-8') as f:
            json.dump(image_jobs, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Created {len(image_jobs)} image jobs")
        return image_jobs
    
    def _phase9_manifest(
        self,
        offers: List[Dict],
        recipes: List[Dict],
        page_quality: Dict[int, Dict[str, Any]],
        reconcile_report: Dict[str, Any]
    ) -> Path:
        """Create manifest"""
        logger.info("Phase 9: Manifest...")
        
        bad_pages = sum(1 for p in page_quality.values() if p.get("bad", False))
        rechecked_pages = sum(1 for p in page_quality.values() if p.get("rechecked", False))
        
        manifest = {
            "supermarket": self.supermarket,
            "weekKey": self.week_key,
            "generatedAt": datetime.now().isoformat(),
            "counts": {
                "offers": len(offers),
                "recipes": len(recipes),
            },
            "perPageQuality": page_quality,
            "recheckedPages": rechecked_pages,
            "totalGptCalls": self.gpt_calls,
            "reconcileReport": {
                "matched": len(reconcile_report.get("matches", [])),
                "pdfOnly": len(reconcile_report.get("pdf_only", [])),
                "rawOnly": len(reconcile_report.get("list_only", [])),
            },
            "files": {
                "offers": f"out/offers/offers_{self.supermarket}_{self.week_key}.json",
                "recipes": f"out/recipes/recipes_{self.supermarket}_{self.week_key}.json",
                "reports": [
                    f"out/reports/reconcile_{self.supermarket}_{self.week_key}.json",
                    f"out/reports/flagged_{self.supermarket}_{self.week_key}.json",
                    f"out/reports/page_quality_{self.supermarket}_{self.week_key}.json",
                ],
                "imageJobs": f"out/images/image_jobs_{self.supermarket}_{self.week_key}.json",
            },
        }
        
        manifest_path = self.out_dir / f"manifest_{self.supermarket}_{self.week_key}.json"
        with open(manifest_path, 'w', encoding='utf-8') as f:
            json.dump(manifest, f, indent=2, ensure_ascii=False)
        
        return manifest_path

