"""
Text-to-JSON Parser for ALDI Nord offers.
Supports simple text format and Pages file extraction.
"""
from __future__ import annotations

import json
import re
import zipfile
from pathlib import Path
from typing import List, Optional
from xml.etree import ElementTree as ET

from .models import Offer


class TextParser:
    """Parse text input or Pages files into structured Offer objects."""

    def parse_text(self, text: str, source: str = "text_input") -> List[Offer]:
        """
        Parse simple text format into offers.
        
        Format examples:
        - "Milch 1,99 € / L"
        - "Brot - 2,49 €"
        - "Joghurt 0,79 € / 500g"
        - "Apfel | 1,29 € | kg"
        """
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
        """Parse a single line into an Offer."""
        # Try different separators: |, -, /
        separators = ['|', '-', '/']
        parts = None
        
        for sep in separators:
            if sep in line:
                parts = [p.strip() for p in line.split(sep)]
                if len(parts) >= 2:
                    break
        
        if not parts:
            # No separator found, try regex extraction
            return self._parse_regex(line, line_num, source)
        
        # Extract title (first part)
        title = parts[0].strip()
        
        # Extract price (look for number with € or EUR)
        price = None
        price_raw = None
        unit = None
        
        for part in parts[1:]:
            # Try to extract price
            price_match = re.search(r'(\d+[,.]?\d*)\s*€', part, re.IGNORECASE)
            if price_match:
                price_str = price_match.group(1).replace(',', '.')
                try:
                    price = float(price_str)
                    price_raw = price_match.group(0)
                except ValueError:
                    pass
            
            # Try to extract unit
            unit_match = re.search(r'/(\s*)?(kg|g|L|l|ml|Stück|Stk|St)', part, re.IGNORECASE)
            if unit_match:
                unit = unit_match.group(2)
        
        # If no price found, try regex on whole line
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
        """Parse line using regex patterns."""
        # Pattern: Title Price Unit
        # Example: "Milch 1,99 € / L"
        pattern = r'(.+?)\s+(\d+[,.]?\d*)\s*€(?:\s*/\s*(\w+))?'
        match = re.search(pattern, line, re.IGNORECASE)
        
        if not match:
            # Try without unit
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
        
        # If nothing matches, create offer with just title
        if line and len(line) > 2:
            return Offer(
                title=line,
                confidence=0.3,
                source=source,
                source_page=line_num,
            )
        
        return None

    def parse_pages_file(self, pages_path: Path) -> List[Offer]:
        """
        Extract text from Pages file and parse it.
        Pages files are ZIP archives containing XML.
        """
        if not pages_path.exists():
            print(f"[TEXT] Pages file not found: {pages_path}")
            return []
        
        try:
            # Pages files are ZIP archives
            with zipfile.ZipFile(pages_path, 'r') as zip_ref:
                # Find the main content file
                content_files = [f for f in zip_ref.namelist() if 'index.xml' in f or 'preview.pdf' in f]
                
                if not content_files:
                    # Try to extract text from any XML file
                    for file_name in zip_ref.namelist():
                        if file_name.endswith('.xml'):
                            try:
                                content = zip_ref.read(file_name)
                                text = self._extract_text_from_xml(content)
                                if text:
                                    return self.parse_text(text, source="pages_file")
                            except Exception as e:
                                print(f"[TEXT] Error reading {file_name}: {e}")
                                continue
                
                # If no XML found, try to read as plain text
                for file_name in zip_ref.namelist():
                    if file_name.endswith('.txt') or 'text' in file_name.lower():
                        try:
                            content = zip_ref.read(file_name).decode('utf-8')
                            return self.parse_text(content, source="pages_file")
                        except Exception as e:
                            print(f"[TEXT] Error reading {file_name}: {e}")
                            continue
            
            print(f"[TEXT] Could not extract text from Pages file: {pages_path}")
            return []
            
        except zipfile.BadZipFile:
            # Not a ZIP file, try to read as plain text
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
        """Extract text content from XML."""
        try:
            root = ET.fromstring(xml_content)
            texts = []
            
            # Recursively find all text nodes
            for elem in root.iter():
                if elem.text:
                    text = elem.text.strip()
                    if text and len(text) > 2:
                        texts.append(text)
            
            return '\n'.join(texts)
        except Exception as e:
            print(f"[TEXT] Error parsing XML: {e}")
            return ""

    def parse_file(self, file_path: Path) -> List[Offer]:
        """Parse a file (Pages, text, or other format)."""
        if file_path.suffix.lower() == '.pages':
            return self.parse_pages_file(file_path)
        else:
            # Try to read as text
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    return self.parse_text(content, source=str(file_path))
            except Exception as e:
                print(f"[TEXT] Error reading file: {e}")
                return []

    def to_json(self, offers: List[Offer], output_path: Path) -> None:
        """Save offers to JSON file."""
        data = [offer.to_dict() for offer in offers]
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        print(f"[TEXT] Saved {len(offers)} offers to {output_path}")


def main():
    """CLI entry point."""
    import sys
    from pathlib import Path
    
    if len(sys.argv) < 2:
        print("Usage: python -m prospekt_pipeline.aldi_nord.text_parser <input_file> [output_file]")
        print("\nSupported formats:")
        print("  - .pages files (Apple Pages)")
        print("  - .txt files (plain text)")
        print("  - Any text file")
        print("\nText format examples:")
        print("  Milch 1,99 € / L")
        print("  Brot - 2,49 €")
        print("  Joghurt | 0,79 € | 500g")
        sys.exit(1)
    
    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else input_path.with_suffix('.json')
    
    parser = TextParser()
    offers = parser.parse_file(input_path)
    
    if offers:
        parser.to_json(offers, output_path)
        print(f"\n✅ Successfully parsed {len(offers)} offers")
    else:
        print("\n⚠️  No offers found in file")


if __name__ == "__main__":
    main()

