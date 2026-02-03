"""
Test script for text parser - can run standalone.
"""
import sys
import json
import re
import zipfile
from pathlib import Path
from typing import List, Optional
from xml.etree import ElementTree as ET
from dataclasses import dataclass, field

# Standalone Offer model (no imports needed)
@dataclass
class Offer:
    title: str
    price: Optional[float] = None
    price_raw: Optional[str] = None
    unit: Optional[str] = None
    brand: Optional[str] = None
    category: Optional[str] = None
    confidence: float = 0.5
    source: str = "unknown"
    source_page: Optional[int] = None
    valid_from: Optional[str] = None
    valid_to: Optional[str] = None

    def to_dict(self) -> dict:
        return {
            "title": self.title,
            "price": self.price,
            "price_raw": self.price_raw,
            "unit": self.unit,
            "brand": self.brand,
            "category": self.category,
            "confidence": self.confidence,
            "source": self.source,
            "source_page": self.source_page,
            "valid_from": self.valid_from,
            "valid_to": self.valid_to,
        }

# Standalone TextParser (copy from text_parser.py)
class TextParser:
    def parse_text(self, text: str, source: str = "text_input") -> List[Offer]:
        offers = []
        lines = text.strip().split('\n')
        
        for line_num, line in enumerate(lines, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            
            offer = self._parse_line(line, line_num, source)
            if offer:
                offers.append(offer)
        
        return offers

    def _parse_line(self, line: str, line_num: int, source: str) -> Optional[Offer]:
        separators = ['|', '-', '/']
        parts = None
        
        for sep in separators:
            if sep in line:
                parts = [p.strip() for p in line.split(sep)]
                if len(parts) >= 2:
                    break
        
        if not parts:
            return self._parse_regex(line, line_num, source)
        
        title = parts[0].strip()
        price = None
        price_raw = None
        unit = None
        
        for part in parts[1:]:
            price_match = re.search(r'(\d+[,.]?\d*)\s*€', part, re.IGNORECASE)
            if price_match:
                price_str = price_match.group(1).replace(',', '.')
                try:
                    price = float(price_str)
                    price_raw = f"{price_match.group(1)} €"
                except ValueError:
                    pass
            
            unit_match = re.search(r'/(\s*)?(kg|g|L|l|ml|Stück|Stk|St)', part, re.IGNORECASE)
            if unit_match:
                unit = unit_match.group(2)
        
        if price is None:
            return self._parse_regex(line, line_num, source)
        
        return Offer(
            title=title,
            price=price,
            price_raw=price_raw,
            unit=unit,
            confidence=0.8,
            source=source,
            source_page=line_num,
        )

    def _parse_regex(self, line: str, line_num: int, source: str) -> Optional[Offer]:
        pattern = r'(.+?)\s+(\d+[,.]?\d*)\s*€(?:\s*/\s*(\w+))?'
        match = re.search(pattern, line, re.IGNORECASE)
        
        if not match:
            pattern = r'(.+?)\s+(\d+[,.]?\d*)\s*€'
            match = re.search(pattern, line, re.IGNORECASE)
        
        if match:
            title = match.group(1).strip()
            price_str = match.group(2).replace(',', '.')
            unit = match.group(3) if len(match.groups()) > 2 and match.group(3) else None
            
            try:
                price = float(price_str)
                price_raw = f"{match.group(2)} €"
                
                return Offer(
                    title=title,
                    price=price,
                    price_raw=price_raw,
                    unit=unit,
                    confidence=0.7,
                    source=source,
                    source_page=line_num,
                )
            except ValueError:
                pass
        
        if line and len(line) > 2:
            return Offer(
                title=line,
                confidence=0.3,
                source=source,
                source_page=line_num,
            )
        
        return None

    def parse_pages_file(self, pages_path: Path) -> List[Offer]:
        if not pages_path.exists():
            print(f"[TEXT] Pages file not found: {pages_path}")
            return []
        
        try:
            with zipfile.ZipFile(pages_path, 'r') as zip_ref:
                for file_name in zip_ref.namelist():
                    if file_name.endswith('.xml'):
                        try:
                            content = zip_ref.read(file_name)
                            text = self._extract_text_from_xml(content)
                            if text:
                                return self.parse_text(text, source="pages_file")
                        except Exception as e:
                            continue
                
                for file_name in zip_ref.namelist():
                    if file_name.endswith('.txt') or 'text' in file_name.lower():
                        try:
                            content = zip_ref.read(file_name).decode('utf-8')
                            return self.parse_text(content, source="pages_file")
                        except Exception:
                            continue
            
            print(f"[TEXT] Could not extract text from Pages file")
            return []
            
        except zipfile.BadZipFile:
            try:
                with open(pages_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    return self.parse_text(content, source="text_file")
            except Exception as e:
                print(f"[TEXT] Error reading file as text: {e}")
                return []
        except Exception as e:
            print(f"[TEXT] Error processing Pages file: {e}")
            return []

    def _extract_text_from_xml(self, xml_content: bytes) -> str:
        try:
            root = ET.fromstring(xml_content)
            texts = []
            for elem in root.iter():
                if elem.text:
                    text = elem.text.strip()
                    if text and len(text) > 2:
                        texts.append(text)
            return '\n'.join(texts)
        except Exception:
            return ""

    def to_json(self, offers: List[Offer], output_path: Path) -> None:
        data = [offer.to_dict() for offer in offers]
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"[TEXT] Saved {len(offers)} offers to {output_path}")


def test_text_parsing():
    """Test text parsing with examples."""
    parser = TextParser()
    
    # Example text
    text = """
# Milchprodukte
Milch 1,99 € / L
Joghurt 0,79 € / 500g
Käse | 2,49 € | 100g

# Backwaren
Brot - 2,49 €
Brötchen 1,29 € / Stück

# Obst & Gemüse
Apfel 1,29 € / kg
Banane 0,99 €
"""
    
    print("🧪 Testing Text Parser")
    print("=" * 60)
    print("\n📝 Input text:")
    print(text)
    
    offers = parser.parse_text(text, source="test_input")
    
    print(f"\n✅ Parsed {len(offers)} offers:")
    print("-" * 60)
    for i, offer in enumerate(offers, 1):
        print(f"{i}. {offer.title}")
        print(f"   Preis: {offer.price_raw or offer.price} €")
        if offer.unit:
            print(f"   Einheit: {offer.unit}")
        print()
    
    # Save to JSON
    output_path = Path(__file__).parent.parent.parent / "media" / "prospekte" / "aldi_nord" / "test_offers.json"
    parser.to_json(offers, output_path)
    print(f"💾 Saved to: {output_path}")


def test_pages_file():
    """Test Pages file parsing."""
    parser = TextParser()
    
    pages_path = Path(__file__).parent.parent.parent / "media" / "prospekte" / "aldi_nord" / "Aldi-nord.pages"
    
    if not pages_path.exists():
        print(f"❌ Pages file not found: {pages_path}")
        return
    
    print("\n🧪 Testing Pages File Parsing")
    print("=" * 60)
    print(f"📄 File: {pages_path}")
    
    offers = parser.parse_pages_file(pages_path)
    
    if offers:
        print(f"\n✅ Parsed {len(offers)} offers from Pages file")
        for i, offer in enumerate(offers[:10], 1):  # Show first 10
            print(f"{i}. {offer.title} - {offer.price_raw or 'N/A'}")
        
        if len(offers) > 10:
            print(f"... and {len(offers) - 10} more")
        
        # Save to JSON
        output_path = pages_path.parent / "offers_from_pages.json"
        parser.to_json(offers, output_path)
        print(f"\n💾 Saved to: {output_path}")
    else:
        print("\n⚠️  No offers found in Pages file")
        print("   (This is normal if the Pages file doesn't contain extractable text)")


if __name__ == "__main__":
    test_text_parsing()
    test_pages_file()

