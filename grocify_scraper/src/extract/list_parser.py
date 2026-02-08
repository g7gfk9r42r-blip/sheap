"""List/raw data parser"""

from pathlib import Path
from typing import List, Dict, Any, Optional
import logging
import json
import re

from ..models import Offer, Source

logger = logging.getLogger(__name__)


class ListParser:
    """Parse offers from list/raw data files"""
    
    def __init__(self, supermarket: str):
        self.supermarket = supermarket
    
    def parse(self, file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """
        Parse offers from list file.
        
        Args:
            file_path: Path to list file
            week_key: Week key
            
        Returns:
            List of raw offer dictionaries
        """
        try:
            logger.info(f"Parsing list file: {file_path}")
            
            # Try JSON first
            if file_path.suffix == '.json':
                return self._parse_json(file_path, week_key)
            
            # Try text
            return self._parse_text(file_path, week_key)
            
        except Exception as e:
            logger.error(f"Failed to parse list file {file_path}: {e}")
            return []
    
    def _parse_json(self, file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Parse JSON file"""
        if not file_path.exists():
            logger.error(f"JSON file not found: {file_path}")
            return []
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                # Try to fix common JSON issues
                if not content.startswith('[') and not content.startswith('{'):
                    # Might be a text file, try to parse as text
                    logger.warning(f"File {file_path} doesn't start with [ or {{, trying text parser")
                    return self._parse_text(file_path, week_key)
                data = json.loads(content)
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in {file_path}: {e}")
            # Try to parse as text file instead
            logger.info(f"Trying to parse {file_path} as text file...")
            return self._parse_text(file_path, week_key)
        except Exception as e:
            logger.error(f"Error reading JSON file {file_path}: {e}")
            # Try to parse as text file instead
            logger.info(f"Trying to parse {file_path} as text file...")
            return self._parse_text(file_path, week_key)
        
        offers = []
        
        # Handle different JSON structures
        if isinstance(data, list):
            items = data
        elif isinstance(data, dict) and 'offers' in data:
            items = data['offers']
        elif isinstance(data, dict) and 'items' in data:
            items = data['items']
        else:
            logger.warning(f"Unknown JSON structure in {file_path}")
            return []
        
        # Check if items are recipes (have ingredients with offer_price or is_offer_product)
        is_recipe_format = False
        if items and isinstance(items[0], dict):
            first_item = items[0]
            # Check for recipe indicators
            if 'ingredients' in first_item and isinstance(first_item['ingredients'], list):
                # Check if ingredients have offer_price or is_offer_product
                for ing in first_item['ingredients'][:5]:
                    if isinstance(ing, dict):
                        if 'offer_price' in ing or ing.get('is_offer_product'):
                            is_recipe_format = True
                            break
            # Also check for other recipe indicators
            if not is_recipe_format:
                recipe_indicators = ['steps', 'portions', 'estimated_total_time_minutes', 'difficulty']
                if any(key in first_item for key in recipe_indicators):
                    # Check if it has ingredients with offer info
                    if 'ingredients' in first_item:
                        for ing in first_item.get('ingredients', [])[:5]:
                            if isinstance(ing, dict) and ('offer_price' in ing or ing.get('is_offer_product')):
                                is_recipe_format = True
                                break
        
        if is_recipe_format:
            # Extract offers from recipes
            logger.info(f"Detected recipe format, extracting offers from ingredients")
            return self._extract_offers_from_recipes(items, file_path, week_key)
        else:
            # Normal offer format
            for item in items:
                offer = self._normalize_json_item(item, file_path, week_key)
                if offer:
                    offers.append(offer)
        
        return offers
    
    def _parse_text(self, file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Parse text file"""
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        offers = []
        lines = content.split('\n')
        
        # Try to detect format
        if self._is_tagged_format(lines):
            offers = self._parse_tagged_format(lines, file_path, week_key)
        else:
            offers = self._parse_freeform(lines, file_path, week_key)
        
        return offers
    
    def _is_tagged_format(self, lines: List[str]) -> bool:
        """Check if lines use tagged format (STANDARD:, KARTE:, etc.)"""
        tagged_keywords = ["STANDARD:", "KARTE:", "UVP:", "BONUS:", "APP:"]
        return any(keyword in line.upper() for line in lines[:20] for keyword in tagged_keywords)
    
    def _parse_tagged_format(self, lines: List[str], file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Parse tagged format"""
        offers = []
        current_offer = {}
        
        for line in lines:
            line = line.strip()
            if not line:
                if current_offer:
                    offers.append(current_offer)
                    current_offer = {}
                continue
            
            # Parse tags
            if line.upper().startswith("STANDARD:"):
                price = self._extract_price(line)
                if price:
                    current_offer.setdefault("prices", []).append({
                        "amount": price,
                        "condition": {"type": "standard"},
                        "is_reference": False,
                    })
            elif line.upper().startswith("KARTE:") or line.upper().startswith("K-CARD:"):
                price = self._extract_price(line)
                if price:
                    current_offer.setdefault("prices", []).append({
                        "amount": price,
                        "condition": {
                            "type": "loyalty",
                            "label": "K-Card",
                            "requires_card": True,
                        },
                        "is_reference": False,
                    })
            elif line.upper().startswith("UVP:"):
                price = self._extract_price(line)
                if price:
                    current_offer["reference_price"] = {
                        "amount": price,
                        "type": "UVP",
                    }
            elif line.upper().startswith("BONUS:") or "REWE BONUS" in line.upper():
                price = self._extract_price(line)
                if price:
                    current_offer.setdefault("prices", []).append({
                        "amount": price,
                        "condition": {
                            "type": "loyalty",
                            "label": "REWE Bonus",
                            "requires_card": True,
                        },
                        "is_reference": False,
                    })
            elif line.upper().startswith("TITLE:") or line.upper().startswith("NAME:"):
                current_offer["title"] = line.split(":", 1)[1].strip()
            elif line.upper().startswith("BRAND:"):
                current_offer["brand"] = line.split(":", 1)[1].strip()
            else:
                # Assume it's title if no title set
                if "title" not in current_offer and len(line) > 3:
                    current_offer["title"] = line
        
        if current_offer:
            offers.append(current_offer)
        
        # Add source info
        for offer in offers:
            offer["source"] = {
                "primary": "list",
                "list_file": str(file_path),
                "raw_text": "\n".join(lines[:10]),  # First 10 lines
            }
        
        return offers
    
    def _parse_freeform(self, lines: List[str], file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Parse freeform text"""
        offers = []
        current_offer = {}
        price_pattern = re.compile(r'(\d+[,.]\d{2})')
        
        for i, line in enumerate(lines):
            line = line.strip()
            if not line or len(line) < 2:
                # Empty line - finish current offer if exists
                if current_offer and current_offer.get("title"):
                    offers.append(current_offer)
                    current_offer = {}
                continue
            
            # Skip header/date lines
            if any(skip in line.lower() for skip in ["ab mo.", "ab sa.", "aktion", "filter", "einkaufsliste", "aktuelle woche", "nächste woche"]):
                continue
            
            # Try to extract price
            price_match = price_pattern.search(line)
            
            if price_match:
                # Line contains price
                price_value = float(price_match.group(1).replace(',', '.'))
                
                # Get title (text before price)
                title = line[:price_match.start()].strip()
                
                # Clean up title
                title = re.sub(r'\s+', ' ', title)  # Multiple spaces
                title = title.strip('–').strip()  # Remove dashes
                
                # Check if previous line was product name
                if i > 0 and lines[i-1].strip() and not price_pattern.search(lines[i-1].strip()):
                    prev_line = lines[i-1].strip()
                    # If previous line looks like a product name (no price, not a header)
                    if len(prev_line) > 3 and prev_line[0].isupper() and not any(skip in prev_line.lower() for skip in ["ab ", "aktion", "filter"]):
                        title = f"{prev_line} {title}".strip() if title else prev_line
                
                if title and len(title) > 2:
                    # Check for unit in line (after price)
                    unit_match = re.search(r'(\d+[-]?[a-zA-Z]+)', line[price_match.end():])
                    unit = None
                    if unit_match:
                        unit = unit_match.group(1)
                    
                    offer = {
                        "title": title,
                        "prices": [{
                            "amount": price_value,
                            "condition": {"type": "standard"},
                            "is_reference": False,
                        }],
                        "quantity": {"value": None, "unit": unit} if unit else {},
                        "source": {
                            "primary": "list",
                            "list_file": str(file_path),
                            "raw_text": line,
                        },
                        "confidence": "medium",
                        "flags": [],
                    }
                    
                    offers.append(offer)
                    current_offer = {}
            else:
                # Line without price - might be product name
                if len(line) > 3 and line[0].isupper() and not any(skip in line.lower() for skip in ["ab ", "aktion", "filter", "einkaufsliste"]):
                    # Potential product name - store for next line
                    current_offer["title"] = line.strip('–').strip()
        
        # Add last offer if exists
        if current_offer and current_offer.get("title"):
            offers.append(current_offer)
        
        logger.info(f"Parsed {len(offers)} offers from freeform text")
        return offers
    
    def _extract_price(self, text: str) -> Optional[float]:
        """Extract price from text"""
        match = re.search(r'(\d+[,.]\d{2})', text)
        if match:
            return float(match.group(1).replace(',', '.'))
        return None
    
    def _extract_offers_from_recipes(self, recipes: List[Dict[str, Any]], file_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Extract offers from recipe ingredients"""
        offers = []
        seen_offers = set()  # Deduplicate by title+price
        
        for recipe in recipes:
            if not isinstance(recipe, dict) or 'ingredients' not in recipe:
                continue
            
            ingredients = recipe.get('ingredients', [])
            for ing in ingredients:
                if not isinstance(ing, dict):
                    continue
                
                # Check if ingredient has offer information
                if not ing.get('is_offer_product') or 'offer_price' not in ing:
                    continue
                
                # Extract offer data
                title = ing.get('offer_title_match') or ing.get('name', '')
                price = ing.get('offer_price')
                original_price = ing.get('original_price')
                
                if not title or not price:
                    continue
                
                # Create unique key for deduplication
                offer_key = (title.lower().strip(), float(price))
                if offer_key in seen_offers:
                    continue
                seen_offers.add(offer_key)
                
                # Extract amount/unit
                amount_str = ing.get('amount', '')
                quantity = {}
                if amount_str:
                    # Parse "200 g" or "250g"
                    import re
                    match = re.search(r'(\d+)\s*(g|kg|ml|l|stück|stk)', amount_str.lower())
                    if match:
                        quantity = {
                            "value": float(match.group(1)),
                            "unit": match.group(2) if match.group(2) != 'stück' else 'pcs',
                        }
                
                # Build offer
                offer = {
                    "title": title,
                    "brand": ing.get('brand'),
                    "prices": [{
                        "amount": float(price),
                        "condition": {"type": "standard"},
                        "is_reference": False,
                    }],
                    "quantity": quantity,
                    "source": {
                        "primary": "list",
                        "list_file": str(file_path),
                    },
                    "confidence": "high" if ing.get('is_offer_product') else "medium",
                    "flags": [],
                }
                
                # Add original price as reference if available
                if original_price and original_price > price:
                    offer["prices"].append({
                        "amount": float(original_price),
                        "condition": {"type": "standard"},
                        "is_reference": True,
                    })
                
                offers.append(offer)
        
        logger.info(f"Extracted {len(offers)} offers from {len(recipes)} recipes")
        return offers
    
    def _normalize_json_item(self, item: Dict[str, Any], file_path: Path, week_key: str) -> Optional[Dict[str, Any]]:
        """Normalize JSON item to offer format"""
        if not isinstance(item, dict):
            return None
        
        # Extract title
        title = item.get('title') or item.get('name') or item.get('product')
        if not title:
            return None
        
        # Extract prices
        prices = []
        if 'price' in item:
            price_value = float(item['price']) if isinstance(item['price'], (int, float)) else None
            if price_value:
                prices.append({
                    "amount": price_value,
                    "condition": {"type": "standard"},
                    "is_reference": False,
                })
        
        # Extract loyalty prices
        if 'loyaltyPrice' in item:
            price_value = float(item['loyaltyPrice']) if isinstance(item['loyaltyPrice'], (int, float)) else None
            if price_value:
                prices.append({
                    "amount": price_value,
                    "condition": {
                        "type": "loyalty",
                        "label": item.get('loyaltyCondition', 'Mit Karte'),
                        "requires_card": True,
                    },
                    "is_reference": False,
                })
        
        if not prices:
            return None
        
        offer = {
            "title": title,
            "brand": item.get('brand'),
            "quantity": {
                "value": item.get('quantity', {}).get('value') if isinstance(item.get('quantity'), dict) else None,
                "unit": item.get('quantity', {}).get('unit') if isinstance(item.get('quantity'), dict) else item.get('unit'),
            },
            "prices": prices,
            "source": {
                "primary": "list",
                "list_file": str(file_path),
            },
            "confidence": item.get('confidence', 'medium'),
            "flags": item.get('flags', []),
        }
        
        return offer

