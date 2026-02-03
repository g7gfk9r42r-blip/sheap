"""
Persistent cache for nutrition data to minimize API calls.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Any


class NutritionCache:
    """
    Manages persistent cache for nutrition data.
    Cache structure: {canonical_key: {nutrition_data, metadata}}
    """
    
    def __init__(self, cache_dir: str = "./nutrition_cache"):
        """
        Initialize cache manager.
        
        Args:
            cache_dir: Directory for cache files
        """
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        
        self.cache_file = self.cache_dir / "nutrition_cache.json"
        self.missing_file = self.cache_dir / "nutrition_missing.json"
        self.ambiguous_file = self.cache_dir / "nutrition_ambiguous.json"
        
        self._cache: Dict[str, Any] = {}
        self._missing: Dict[str, Any] = {}
        self._ambiguous: Dict[str, Any] = {}
        
        self._load_all()
    
    def _load_all(self):
        """Load all cache files."""
        self._cache = self._load_json(self.cache_file, {})
        self._missing = self._load_json(self.missing_file, {})
        self._ambiguous = self._load_json(self.ambiguous_file, {})
    
    def _load_json(self, filepath: Path, default: Any) -> Any:
        """Load JSON file with fallback."""
        if filepath.exists():
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                print(f"Warning: Could not load {filepath}: {e}")
                return default
        return default
    
    def _save_json(self, filepath: Path, data: Any):
        """Save data to JSON file."""
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Error: Could not save {filepath}: {e}")
    
    def get(self, canonical_key: str) -> Optional[Dict[str, Any]]:
        """
        Get cached nutrition data for a canonical key.
        
        Args:
            canonical_key: Normalized ingredient key
        
        Returns:
            Cached nutrition data or None
        """
        return self._cache.get(canonical_key)
    
    def set(self, canonical_key: str, nutrition_data: Dict[str, Any], metadata: Optional[Dict[str, Any]] = None):
        """
        Cache nutrition data.
        
        Args:
            canonical_key: Normalized ingredient key
            nutrition_data: Nutrition information
            metadata: Optional metadata (source, confidence, etc.)
        """
        entry = {
            "nutrition": nutrition_data,
            "metadata": metadata or {},
            "cached_at": datetime.now().isoformat()
        }
        self._cache[canonical_key] = entry
    
    def add_missing(self, canonical_key: str, original_name: str, reason: str = "not_found"):
        """
        Add ingredient to missing list.
        
        Args:
            canonical_key: Normalized ingredient key
            original_name: Original ingredient name
            reason: Reason why it's missing
        """
        if canonical_key not in self._missing:
            self._missing[canonical_key] = {
                "original_names": [],
                "reason": reason,
                "first_seen": datetime.now().isoformat(),
                "count": 0
            }
        
        if original_name not in self._missing[canonical_key]["original_names"]:
            self._missing[canonical_key]["original_names"].append(original_name)
        
        self._missing[canonical_key]["count"] += 1
        self._missing[canonical_key]["last_seen"] = datetime.now().isoformat()
    
    def add_ambiguous(self, canonical_key: str, original_name: str, matches: list):
        """
        Add ingredient with ambiguous matches.
        
        Args:
            canonical_key: Normalized ingredient key
            original_name: Original ingredient name
            matches: List of possible matches with confidence scores
        """
        if canonical_key not in self._ambiguous:
            self._ambiguous[canonical_key] = {
                "original_names": [],
                "matches": matches,
                "first_seen": datetime.now().isoformat(),
                "count": 0
            }
        
        if original_name not in self._ambiguous[canonical_key]["original_names"]:
            self._ambiguous[canonical_key]["original_names"].append(original_name)
        
        self._ambiguous[canonical_key]["count"] += 1
        self._ambiguous[canonical_key]["last_seen"] = datetime.now().isoformat()
    
    def is_missing(self, canonical_key: str) -> bool:
        """Check if key is in missing list."""
        return canonical_key in self._missing
    
    def is_ambiguous(self, canonical_key: str) -> bool:
        """Check if key is in ambiguous list."""
        return canonical_key in self._ambiguous
    
    def save_all(self):
        """Persist all cache data to disk."""
        self._save_json(self.cache_file, self._cache)
        self._save_json(self.missing_file, self._missing)
        self._save_json(self.ambiguous_file, self._ambiguous)
        
        print(f"✓ Cache saved: {len(self._cache)} entries")
        print(f"✓ Missing: {len(self._missing)} ingredients")
        print(f"✓ Ambiguous: {len(self._ambiguous)} ingredients")
    
    def get_stats(self) -> Dict[str, int]:
        """Get cache statistics."""
        return {
            "cached": len(self._cache),
            "missing": len(self._missing),
            "ambiguous": len(self._ambiguous)
        }
    
    def clear_missing(self):
        """Clear missing list (useful for retry)."""
        self._missing = {}
    
    def clear_ambiguous(self):
        """Clear ambiguous list (useful for retry)."""
        self._ambiguous = {}

