"""Data models for ALDI Nord offers."""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Offer:
    """Represents a single offer from ALDI Nord."""
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
        """Convert to dictionary."""
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

