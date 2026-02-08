"""PDF text extraction and offer parsing"""

import re
from pathlib import Path
from typing import List, Dict, Any, Optional
import logging
from pdfminer.high_level import extract_text
from pdfminer.layout import LAParams

from ..models import Offer, PriceTier, Condition, Source, Quantity, Price, ReferencePrice
from ..config import SUPERMARKETS, FLAGS

logger = logging.getLogger(__name__)


class PDFExtractor:
    """Extract offers from PDF files"""
    
    def __init__(self, supermarket: str):
        self.supermarket = supermarket
        self.config = SUPERMARKETS.get(supermarket)
        self.loyalty_keywords = self.config.loyalty_keywords if self.config else {}
        
    def extract(self, pdf_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """
        Extract offers from PDF.
        
        Args:
            pdf_path: Path to PDF file
            week_key: Week key
            
        Returns:
            List of raw offer dictionaries
        """
        try:
            if not pdf_path.exists():
                logger.error(f"PDF file not found: {pdf_path}")
                return []
            
            logger.info(f"Extracting text from PDF: {pdf_path}")
            
            # Suppress pdfminer warnings
            import warnings
            import logging
            warnings.filterwarnings("ignore", category=UserWarning)
            pdfminer_logger = logging.getLogger("pdfminer")
            pdfminer_logger.setLevel(logging.ERROR)
            
            text = extract_text(str(pdf_path), laparams=LAParams())
            
            if not text or len(text.strip()) < 10:
                logger.warning(f"PDF extraction returned empty or very short text")
                return []
            
            # Save raw text for debugging
            raw_output = Path("out/reports") / f"{self.supermarket}_{week_key}_pdf_raw.txt"
            raw_output.parent.mkdir(parents=True, exist_ok=True)
            with open(raw_output, 'w', encoding='utf-8') as f:
                f.write(text)
            
            # Parse offers from text
            offers = self._parse_text(text, pdf_path, week_key)
            
            logger.info(f"Extracted {len(offers)} offers from PDF")
            return offers
            
        except Exception as e:
            logger.error(f"Failed to extract from PDF {pdf_path}: {e}")
            return []
    
    def _parse_text(self, text: str, pdf_path: Path, week_key: str) -> List[Dict[str, Any]]:
        """Parse offers from text"""
        offers = []
        lines = text.split('\n')
        
        # Group lines into potential offer blocks
        blocks = self._group_into_blocks(lines)
        
        for i, block in enumerate(blocks):
            offer = self._parse_block(block, pdf_path, week_key, i)
            if offer:
                offers.append(offer)
        
        return offers
    
    def _group_into_blocks(self, lines: List[str]) -> List[List[str]]:
        """Group lines into potential offer blocks"""
        blocks = []
        current_block = []
        
        for line in lines:
            line = line.strip()
            if not line:
                if current_block:
                    blocks.append(current_block)
                    current_block = []
                continue
            
            # Check if line looks like a price
            if self._looks_like_price(line):
                if current_block:
                    blocks.append(current_block)
                current_block = [line]
            else:
                current_block.append(line)
        
        if current_block:
            blocks.append(current_block)
        
        return blocks
    
    def _looks_like_price(self, text: str) -> bool:
        """Check if text looks like a price"""
        # Match patterns like "1,99", "2.49 €", "UVP 3.99", etc.
        price_patterns = [
            r'\d+[,.]\d{2}',
            r'UVP\s+\d+[,.]\d{2}',
            r'statt\s+\d+[,.]\d{2}',
            r'-\d+%',
        ]
        return any(re.search(pattern, text, re.IGNORECASE) for pattern in price_patterns)
    
    def _parse_block(self, block: List[str], pdf_path: Path, week_key: str, index: int) -> Optional[Dict[str, Any]]:
        """Parse a single offer block"""
        if not block:
            return None
        
        # Extract title (usually first non-price line)
        title = None
        for line in block:
            if not self._looks_like_price(line) and len(line) > 3:
                title = line.strip()
                break
        
        if not title:
            return None
        
        # Extract prices
        prices = self._extract_prices(block)
        if not prices:
            return None
        
        # Extract brand
        brand = self._extract_brand(block)
        
        # Extract quantity
        quantity = self._extract_quantity(block)
        
        # Build offer dict
        offer = {
            "title": title,
            "brand": brand,
            "brand_confidence": "high" if brand else "low",
            "quantity": quantity,
            "prices": prices,
            "source": {
                "primary": "pdf",
                "pdf_file": str(pdf_path),
                "raw_text": "\n".join(block),
            },
            "confidence": "medium",
            "flags": [],
        }
        
        return offer
    
    def _extract_prices(self, block: List[str]) -> List[Dict[str, Any]]:
        """Extract prices from block"""
        prices = []
        text = " ".join(block).lower()
        
        # Find all price patterns
        price_pattern = r'(\d+[,.]\d{2})'
        matches = re.findall(price_pattern, " ".join(block))
        
        for match in matches:
            price_value = float(match.replace(',', '.'))
            
            # Check for loyalty keywords
            condition = self._detect_condition(text, match)
            
            # Check for UVP/reference
            is_reference = any(keyword in text for keyword in ["uvp", "statt", "war", "unverbindlich"])
            
            price_info = {
                "amount": price_value,
                "condition": condition,
                "is_reference": is_reference,
            }
            prices.append(price_info)
        
        return prices
    
    def _detect_condition(self, text: str, price_str: str) -> Dict[str, Any]:
        """Detect price condition from text"""
        # Check for loyalty keywords
        for cond_type, keywords in self.loyalty_keywords.items():
            for keyword in keywords:
                if keyword.lower() in text:
                    return {
                        "type": cond_type,
                        "label": keyword.title(),
                        "requires_card": cond_type == "loyalty",
                        "requires_app": cond_type == "app",
                    }
        
        # Check for multi-buy
        if re.search(r'ab\s*\d+', text):
            match = re.search(r'ab\s*(\d+)', text)
            if match:
                return {
                    "type": "multi_buy",
                    "min_qty": int(match.group(1)),
                    "requires_card": False,
                    "requires_app": False,
                }
        
        # Default to standard
        return {
            "type": "standard",
            "requires_card": False,
            "requires_app": False,
        }
    
    def _extract_brand(self, block: List[str]) -> Optional[str]:
        """Extract brand from block"""
        # Common brand patterns (uppercase, short)
        for line in block:
            line = line.strip()
            # Brand is usually uppercase, 2-20 chars, not a price
            if (line.isupper() and 
                2 <= len(line) <= 20 and 
                not self._looks_like_price(line) and
                not line.isdigit()):
                return line
        
        return None
    
    def _extract_quantity(self, block: List[str]) -> Dict[str, Any]:
        """Extract quantity from block"""
        text = " ".join(block).lower()
        
        # Patterns: "500g", "1kg", "250ml", "2 Stück"
        patterns = [
            (r'(\d+)\s*g', 'g'),
            (r'(\d+)\s*kg', 'kg'),
            (r'(\d+)\s*ml', 'ml'),
            (r'(\d+)\s*l', 'l'),
            (r'(\d+)\s*stück', 'pcs'),
        ]
        
        for pattern, unit in patterns:
            match = re.search(pattern, text)
            if match:
                return {
                    "value": float(match.group(1)),
                    "unit": unit,
                }
        
        return {"value": None, "unit": None}

