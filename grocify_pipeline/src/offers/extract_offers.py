"""Main offer extraction module"""
import json
from pathlib import Path
from typing import List, Dict, Any
from .offer_parser_regex import OfferParserRegex
from .offer_llm_cleaner import OfferLLMCleaner
from .offer_schema import Offer, OFFER_JSON_SCHEMA
from ..utils.io import read_json, write_json
from ..utils.json_validate import validate_against_schema
from ..utils.logging import Logger


class OfferExtractor:
    """Extract offers from raw prospekt JSON"""
    
    def __init__(self, logger: Logger, use_llm: bool = True):
        self.logger = logger
        self.parser = OfferParserRegex()
        self.llm_cleaner = OfferLLMCleaner() if use_llm else None
    
    def extract_text_from_json(self, data: Any) -> str:
        """Recursively extract all text content from JSON"""
        texts = []
        
        if isinstance(data, dict):
            for value in data.values():
                texts.append(self.extract_text_from_json(value))
        elif isinstance(data, list):
            for item in data:
                texts.append(self.extract_text_from_json(item))
        elif isinstance(data, str):
            texts.append(data)
        
        return ' '.join(texts)
    
    def deduplicate_offers(self, offers: List[Dict]) -> List[Dict]:
        """Remove duplicate offers"""
        seen = set()
        unique = []
        
        for offer in offers:
            # Use title + price as dedup key
            key = (offer['title'].lower(), offer['price_now'])
            if key not in seen:
                seen.add(key)
                unique.append(offer)
        
        return unique
    
    def assign_final_ids(self, offers: List[Dict], supermarket: str, weekkey: str) -> List[Dict]:
        """Assign final offer IDs"""
        for idx, offer in enumerate(offers, 1):
            offer['offerId'] = f"{supermarket}-{weekkey}-{idx:03d}"
        return offers
    
    def extract_from_file(
        self,
        input_file: Path,
        supermarket: str,
        weekkey: str
    ) -> List[Dict]:
        """
        Extract offers from raw JSON file
        
        Returns list of offer dicts
        """
        self.logger.info(f"Extracting offers from {input_file}")
        
        # Read raw JSON
        try:
            raw_data = read_json(input_file)
        except Exception as e:
            self.logger.error(f"Failed to read {input_file}: {e}")
            raise
        
        # Extract text
        text = self.extract_text_from_json(raw_data)
        self.logger.info(f"Extracted {len(text)} chars of text")
        
        # Parse candidates
        candidates = self.parser.parse_offer_candidates(text, supermarket)
        self.logger.info(f"Found {len(candidates)} initial candidates")
        
        # Filter out low confidence non-food
        candidates = [c for c in candidates if c['is_food'] or c['confidence'] > 0.5]
        
        # Use LLM for uncertain cases
        uncertain = [c for c in candidates if 0.3 < c['confidence'] < 0.7]
        if uncertain and self.llm_cleaner:
            self.logger.info(f"Classifying {len(uncertain)} uncertain offers with LLM")
            try:
                self.llm_cleaner.classify_batch(uncertain)
            except Exception as e:
                self.logger.warning(f"LLM classification failed: {e}")
        
        # Keep only food items
        food_offers = [c for c in candidates if c['is_food']]
        self.logger.info(f"Kept {len(food_offers)} food offers")
        
        # Deduplicate
        unique_offers = self.deduplicate_offers(food_offers)
        self.logger.info(f"After deduplication: {len(unique_offers)} offers")
        
        # Assign final IDs
        final_offers = self.assign_final_ids(unique_offers, supermarket, weekkey)
        
        # Validate
        for offer in final_offers:
            is_valid, error = validate_against_schema(offer, OFFER_JSON_SCHEMA)
            if not is_valid:
                self.logger.warning(f"Offer {offer['offerId']} validation warning: {error}")
        
        return final_offers
    
    def extract_and_save(
        self,
        input_file: Path,
        output_file: Path,
        supermarket: str,
        weekkey: str
    ) -> int:
        """
        Extract offers and save to file
        
        Returns number of offers extracted
        """
        offers = self.extract_from_file(input_file, supermarket, weekkey)
        
        write_json(output_file, offers)
        self.logger.info(f"Saved {len(offers)} offers to {output_file}")
        
        return len(offers)

