"""ALDI Nord prospekt parsing pipeline."""
from __future__ import annotations

from .aldi_nord_processor import AldiNordProcessor
from .models import Offer

__all__ = [
    "AldiNordProcessor",
    "Offer",
]

