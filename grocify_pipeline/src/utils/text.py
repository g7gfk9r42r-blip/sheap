"""Text processing utilities"""
import re
from typing import List


def normalize_text(text: str) -> str:
    """Normalize text: lowercase, clean whitespace"""
    text = text.lower()
    text = re.sub(r'\s+', ' ', text)
    return text.strip()


def extract_float(text: str) -> float:
    """Extract first float from text"""
    # Handle German number format (comma as decimal)
    text = text.replace(',', '.')
    match = re.search(r'\d+\.?\d*', text)
    if match:
        try:
            return float(match.group())
        except ValueError:
            return 0.0
    return 0.0


def extract_price(text: str) -> float:
    """Extract price from text like '1,29 €' or '€ 2.49'"""
    # Remove currency symbols
    text = text.replace('€', '').replace('EUR', '').strip()
    return extract_float(text)


def clean_product_name(name: str) -> str:
    """Clean product name"""
    # Remove excess whitespace
    name = re.sub(r'\s+', ' ', name)
    # Remove price info
    name = re.sub(r'\d+[,\.]\d+\s*€?', '', name)
    # Remove pack size indicators at end
    name = re.sub(r'\s+\d+\s*[gml]$', '', name, flags=re.IGNORECASE)
    return name.strip()


def split_into_blocks(text: str, max_block_size: int = 5000) -> List[str]:
    """Split text into blocks"""
    if len(text) <= max_block_size:
        return [text]
    
    blocks = []
    lines = text.split('\n')
    current_block = []
    current_size = 0
    
    for line in lines:
        line_size = len(line)
        if current_size + line_size > max_block_size and current_block:
            blocks.append('\n'.join(current_block))
            current_block = [line]
            current_size = line_size
        else:
            current_block.append(line)
            current_size += line_size
    
    if current_block:
        blocks.append('\n'.join(current_block))
    
    return blocks

