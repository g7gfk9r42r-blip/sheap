"""File loading utilities"""

from pathlib import Path
from typing import Optional, List
import json
import logging

logger = logging.getLogger(__name__)


def load_json(file_path: Path) -> Optional[dict]:
    """Load JSON file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        logger.error(f"Failed to load JSON from {file_path}: {e}")
        return None


def load_text(file_path: Path) -> Optional[str]:
    """Load text file"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        logger.error(f"Failed to load text from {file_path}: {e}")
        return None


def find_list_files(supermarket: str, base_dir: Path) -> List[Path]:
    """
    Find list files for supermarket.
    
    Args:
        supermarket: Supermarket name
        base_dir: Base directory to search
        
    Returns:
        List of found list file paths
    """
    list_dir = base_dir / "lists" / supermarket
    if not list_dir.exists():
        return []
    
    # Try common patterns
    patterns = ["*.txt", "*.json", "*.csv"]
    files = []
    
    for pattern in patterns:
        files.extend(list_dir.glob(pattern))
    
    return files

