"""Extract offers from raw prospekt JSON"""
import json
import re
from typing import List, Dict, Any
from pathlib import Path


# Food keywords for classification
FOOD_KEYWORDS = {
    'dessert', 'joghurt', 'eis', 'kuchen', 'torte', 'fleisch', 'wurst', 
    'milch', 'käse', 'butter', 'brot', 'nudeln', 'reis', 'kartoffeln',
    'gemüse', 'obst', 'salat', 'tomate', 'gurke', 'apfel', 'banane',
    'getränk', 'saft', 'wasser', 'wein', 'bier', 'kaffee', 'tee',
    'schokolade', 'bonbon', 'keks', 'chips', 'nüsse',
    'fisch', 'lachs', 'thunfisch', 'pizza', 'pasta'
}

NON_FOOD_KEYWORDS = {
    'handy', 'smartphone', 'tablet', 'laptop', 'fernseher',
    'mode', 'kleidung', 'hose', 'jacke', 'schuhe',
    'möbel', 'tisch', 'stuhl', 'regal',
    'spielzeug', 'lego', 'puppe',
    'reise', 'urlaub', 'hotel', 'flug',
    'werkzeug', 'bohrer', 'hammer',
    'gutschein', 'geschenkkarte', 'apple card'
}

STORE_ZONES = {
    'dessert': 'Kühlregal', 'joghurt': 'Kühlregal', 'milch': 'Kühlregal',
    'käse': 'Kühlregal', 'butter': 'Kühlregal', 'wurst': 'Kühlregal',
    'fleisch': 'Fleischtheke', 'fisch': 'Fischtheke',
    'eis': 'Tiefkühltruhe', 'pizza': 'Tiefkühltruhe',
    'obst': 'Obst & Gemüse', 'gemüse': 'Obst & Gemüse', 'salat': 'Obst & Gemüse',
    'brot': 'Backwelt', 'brötchen': 'Backwelt', 'kuchen': 'Backwelt',
    'getränk': 'Getränkeregal', 'saft': 'Getränkeregal', 'wasser': 'Getränkeregal',
    'wein': 'Getränkeregal', 'bier': 'Getränkeregal'
}


class OfferExtractor:
    """Extract structured offers from messy prospekt JSON"""
    
    def __init__(self):
        self.offers = []
        self.stats = {
            'blocks_processed': 0,
            'offers_extracted': 0,
            'food_offers': 0,
            'non_food_filtered': 0
        }
    
    def extract_text_from_json(self, data: Any) -> str:
        """Recursively extract all text from JSON"""
        texts = []
        if isinstance(data, dict):
            for v in data.values():
                texts.append(self.extract_text_from_json(v))
        elif isinstance(data, list):
            for item in data:
                texts.append(self.extract_text_from_json(item))
        elif isinstance(data, str):
            texts.append(data)
        return ' '.join(texts)
    
    def extract_price(self, text: str) -> float:
        """Extract price from text"""
        # Handle formats: "0.44", "1.11**", "3.89*"
        text = text.replace(',', '.').replace('*', '')
        match = re.search(r'(\d+)\.(\d{2})', text)
        if match:
            return float(f"{match.group(1)}.{match.group(2)}")
        return 0.0
    
    def find_price_blocks(self, text: str) -> List[Dict]:
        """Find blocks with prices"""
        blocks = []
        lines = text.split('\n')
        
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            
            # Look for discount markers
            if '-' in line and '%' in line:
                # Found discount, collect surrounding context
                context_start = max(0, i - 5)
                context_end = min(len(lines), i + 10)
                context = '\n'.join(lines[context_start:context_end])
                
                blocks.append({
                    'text': context,
                    'offset': i
                })
                i = context_end
            else:
                i += 1
        
        return blocks
    
    def parse_block(self, block: Dict, supermarket: str, idx: int) -> Dict:
        """Parse offer block into structured offer"""
        text = block['text']
        lines = text.split('\n')
        
        # Extract key info
        title_parts = []
        brand = None
        price_now = 0.0
        price_before = None
        discount_percent = None
        unit_price = None
        unit_price_unit = None
        
        for line in lines:
            line = line.strip()
            
            # Skip empty
            if not line:
                continue
            
            # Discount
            if '%' in line and '-' in line:
                match = re.search(r'-(\d+)\s*%', line)
                if match:
                    discount_percent = int(match.group(1))
            
            # Price patterns
            if re.match(r'\d+\.\s*\d{2}', line):
                price = self.extract_price(line)
                if price > 0:
                    if price_now == 0.0:
                        price_now = price
                    elif not price_before or price > price_now:
                        price_before = price
            
            # UVP
            if 'UVP' in line or 'uvp' in line.lower():
                price = self.extract_price(line)
                if price > 0:
                    price_before = price
            
            # Unit price
            if 'kg-Preis' in line or 'l-Preis' in line or 'Preis je' in line:
                if 'kg' in line:
                    unit_price_unit = '€/kg'
                elif 'l-Preis' in line or 'l-preis' in line.lower():
                    unit_price_unit = '€/l'
                price = self.extract_price(line)
                if price > 0:
                    unit_price = price
            
            # Title/Brand collection
            if len(line) > 3 and not any(c in line for c in ['%', '€', 'UVP', 'kg-Preis', 'l-Preis', 'zzgl', 'Pfand']):
                if line.isupper() and len(line) < 30:
                    if not brand:
                        brand = line.title()
                    else:
                        title_parts.append(line.title())
                elif len(line) < 50:
                    title_parts.append(line)
        
        # Build title
        title = ' '.join(title_parts[:3]) if title_parts else "Unbekanntes Produkt"
        title = title.strip()
        
        # Classify food
        is_food, confidence = self.classify_food(text)
        
        # Determine store zone
        store_zone = self.guess_store_zone(title)
        
        offer = {
            'supermarket': supermarket,
            'offer_id': f"{supermarket}_{idx:03d}",
            'title': title,
            'brand': brand,
            'price_now': price_now,
            'price_before': price_before,
            'unit_price': unit_price,
            'unit_price_unit': unit_price_unit,
            'pack_size': None,
            'pack_unit': None,
            'valid_from': None,
            'valid_to': None,
            'category': 'food' if is_food else 'non-food',
            'store_zone': store_zone,
            'is_food': is_food,
            'confidence': confidence,
            'raw_evidence': text[:200]
        }
        
        return offer
    
    def classify_food(self, text: str) -> tuple:
        """Classify if text is food-related"""
        text_lower = text.lower()
        
        # Count keywords
        food_count = sum(1 for kw in FOOD_KEYWORDS if kw in text_lower)
        non_food_count = sum(1 for kw in NON_FOOD_KEYWORDS if kw in text_lower)
        
        if non_food_count > 0:
            return False, 0.9
        
        if food_count >= 2:
            return True, 0.9
        elif food_count == 1:
            return True, 0.6
        else:
            return True, 0.3  # Default to food with low confidence
    
    def guess_store_zone(self, title: str) -> str:
        """Guess store zone from title"""
        title_lower = title.lower()
        for keyword, zone in STORE_ZONES.items():
            if keyword in title_lower:
                return zone
        return "Zentrale Gänge"
    
    def deduplicate(self, offers: List[Dict]) -> List[Dict]:
        """Remove duplicates"""
        seen = set()
        unique = []
        
        for offer in offers:
            key = (offer['title'].lower(), offer['price_now'])
            if key not in seen and len(offer['title']) > 3:
                seen.add(key)
                unique.append(offer)
        
        return unique
    
    def extract(self, json_path: Path, supermarket: str) -> List[Dict]:
        """Main extraction method"""
        print(f"🔍 Extracting offers from {json_path}")
        
        # Load file - handle both JSON and plain text
        with open(json_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        try:
            data = json.loads(content)
            text = self.extract_text_from_json(data)
        except json.JSONDecodeError:
            # Plain text file
            text = content
        
        print(f"   Extracted {len(text)} chars of text")
        
        # Find price blocks
        blocks = self.find_price_blocks(text)
        print(f"   Found {len(blocks)} price blocks")
        self.stats['blocks_processed'] = len(blocks)
        
        # Parse blocks
        offers = []
        for idx, block in enumerate(blocks):
            offer = self.parse_block(block, supermarket, idx)
            if offer['price_now'] > 0:  # Must have price
                offers.append(offer)
                self.stats['offers_extracted'] += 1
        
        # Filter food only
        food_offers = [o for o in offers if o['is_food']]
        self.stats['food_offers'] = len(food_offers)
        self.stats['non_food_filtered'] = len(offers) - len(food_offers)
        
        # Deduplicate
        unique_offers = self.deduplicate(food_offers)
        
        print(f"   ✅ Extracted {len(unique_offers)} unique food offers")
        
        return unique_offers

