"""Offer data schema"""
from dataclasses import dataclass, asdict
from typing import Optional, Dict, Any


@dataclass
class Offer:
    offerId: str
    supermarket: str
    title: str
    brand: Optional[str]
    price_now: Optional[float]
    price_before: Optional[float]
    price_before_source: Optional[str]  # uvp|previous|unknown
    unit_price: Optional[float]
    unit: Optional[str]  # kg|l|100g|100ml|piece|null
    valid_from: Optional[str]
    valid_to: Optional[str]
    discount_percent: Optional[int]
    is_food: bool
    confidence: float  # 0.0-1.0
    raw_evidence: Dict[str, Any]
    
    def to_dict(self) -> dict:
        return asdict(self)


OFFER_JSON_SCHEMA = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "required": ["offerId", "supermarket", "title", "is_food", "confidence"],
    "properties": {
        "offerId": {"type": "string"},
        "supermarket": {"type": "string"},
        "title": {"type": "string"},
        "brand": {"type": ["string", "null"]},
        "price_now": {"type": ["number", "null"]},
        "price_before": {"type": ["number", "null"]},
        "price_before_source": {"type": ["string", "null"]},
        "unit_price": {"type": ["number", "null"]},
        "unit": {"type": ["string", "null"]},
        "valid_from": {"type": ["string", "null"]},
        "valid_to": {"type": ["string", "null"]},
        "discount_percent": {"type": ["integer", "null"]},
        "is_food": {"type": "boolean"},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1},
        "raw_evidence": {"type": "object"}
    }
}

