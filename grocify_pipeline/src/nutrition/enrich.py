"""Nutrition enrichment for offers"""
import json
from pathlib import Path
from typing import List, Dict, Optional
from .usda_client import USDAClient
from .off_client import OpenFoodFactsClient
from .normalize import get_search_term
from ..utils.io import read_json, write_json
from ..utils.logging import Logger


class NutritionEnricher:
    """Enrich offers with nutrition data"""
    
    def __init__(self, cache_file: Path, logger: Logger):
        self.cache_file = cache_file
        self.logger = logger
        self.usda = USDAClient()
        self.off = OpenFoodFactsClient()
        self.cache = self._load_cache()
        
        self.stats = {
            "total": 0,
            "enriched": 0,
            "missing": 0,
            "cache_hits": 0,
            "api_calls": 0
        }
    
    def _load_cache(self) -> Dict:
        """Load nutrition cache"""
        if self.cache_file.exists():
            try:
                return read_json(self.cache_file)
            except:
                pass
        return {}
    
    def _save_cache(self):
        """Save nutrition cache"""
        write_json(self.cache_file, self.cache)
        
        # Also save missing list
        missing_file = self.cache_file.parent / "nutrition_missing.json"
        missing = {k: v for k, v in self.cache.items() if v.get("status") == "missing"}
        write_json(missing_file, missing)
    
    def _get_from_cache(self, key: str) -> Optional[Dict]:
        """Get from cache"""
        if key in self.cache:
            self.stats["cache_hits"] += 1
            return self.cache[key]
        return None
    
    def _fetch_nutrition(self, food_name: str) -> Optional[Dict]:
        """Fetch nutrition from APIs"""
        search_term = get_search_term(food_name)
        
        # Try USDA first
        if self.usda.is_available():
            self.stats["api_calls"] += 1
            results = self.usda.search_food(search_term, limit=1)
            if results:
                return results[0]
        
        # Try OpenFoodFacts
        self.stats["api_calls"] += 1
        results = self.off.search_product(search_term, limit=1)
        if results:
            return results[0]
        
        return None
    
    def enrich_offer(self, offer: Dict) -> Dict:
        """Enrich single offer with nutrition"""
        self.stats["total"] += 1
        
        title = offer.get("title", "")
        cache_key = title.lower().strip()
        
        # Check cache
        cached = self._get_from_cache(cache_key)
        if cached:
            if cached.get("status") == "found":
                offer["nutrition"] = cached["data"]
                self.stats["enriched"] += 1
            else:
                offer["nutrition"] = None
                self.stats["missing"] += 1
            return offer
        
        # Fetch from APIs
        nutrition = self._fetch_nutrition(title)
        
        if nutrition:
            self.cache[cache_key] = {
                "status": "found",
                "data": nutrition
            }
            offer["nutrition"] = nutrition
            self.stats["enriched"] += 1
        else:
            self.cache[cache_key] = {
                "status": "missing",
                "query": title
            }
            offer["nutrition"] = None
            self.stats["missing"] += 1
        
        return offer
    
    def enrich_offers(self, offers: List[Dict]) -> List[Dict]:
        """Enrich list of offers"""
        self.logger.info(f"Enriching {len(offers)} offers with nutrition data")
        
        enriched = []
        for offer in offers:
            enriched.append(self.enrich_offer(offer))
        
        # Save cache
        self._save_cache()
        
        # Log stats
        self.logger.info(f"Nutrition enrichment complete:")
        self.logger.info(f"  Total: {self.stats['total']}")
        self.logger.info(f"  Enriched: {self.stats['enriched']}")
        self.logger.info(f"  Missing: {self.stats['missing']}")
        self.logger.info(f"  Cache hits: {self.stats['cache_hits']}")
        self.logger.info(f"  API calls: {self.stats['api_calls']}")
        
        return enriched
    
    def enrich_file(self, input_file: Path, output_file: Path) -> Dict:
        """Enrich offers from file"""
        offers = read_json(input_file)
        enriched = self.enrich_offers(offers)
        write_json(output_file, enriched)
        
        return {
            "total": self.stats["total"],
            "enriched": self.stats["enriched"],
            "missing": self.stats["missing"],
            "coverage": self.stats["enriched"] / self.stats["total"] if self.stats["total"] > 0 else 0
        }

