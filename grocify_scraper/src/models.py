"""Data models for offers and recipes"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Literal
from datetime import datetime


@dataclass
class Quantity:
    """Product quantity"""
    value: Optional[float] = None
    unit: Optional[str] = None  # "g", "kg", "ml", "l", "pcs"


@dataclass
class Price:
    """Price information"""
    amount: Optional[float] = None
    currency: str = "EUR"


@dataclass
class ReferencePrice:
    """Reference price (UVP, was, per_kg, etc.)"""
    amount: Optional[float] = None
    currency: str = "EUR"
    type: Optional[str] = None  # "UVP", "was", "per_kg", "per_l"


@dataclass
class Condition:
    """Price condition (loyalty, app, etc.)"""
    type: Literal["standard", "loyalty", "app", "coupon", "multi_buy", "membership"]
    label: Optional[str] = None  # "K-Card", "REWE Bonus", etc.
    requires_card: bool = False
    requires_app: bool = False
    min_qty: Optional[int] = None
    notes: Optional[str] = None


@dataclass
class PriceTier:
    """A price tier with condition"""
    amount: float
    currency: str = "EUR"
    condition: Condition = field(default_factory=lambda: Condition(type="standard"))


@dataclass
class Source:
    """Source information"""
    primary: Literal["pdf", "list"]
    pdf_file: Optional[str] = None
    list_file: Optional[str] = None
    page: Optional[int] = None
    raw_text: Optional[str] = None


@dataclass
class Discount:
    """Discount information"""
    percent: Optional[float] = None
    derived: bool = False  # True if calculated from prices


@dataclass
class Offer:
    """Offer model"""
    id: str
    supermarket: str
    week_key: str
    title: str
    brand: Optional[str] = None
    brand_confidence: Literal["high", "medium", "low"] = "medium"
    category: Optional[str] = None  # "produce", "meat", "dairy", etc.
    quantity: Quantity = field(default_factory=Quantity)
    base_price: Price = field(default_factory=Price)
    reference_price: Optional[ReferencePrice] = None
    price_tiers: List[PriceTier] = field(default_factory=list)
    discount: Optional[Discount] = None
    source: Source = field(default_factory=Source)
    confidence: Literal["high", "medium", "low"] = "medium"
    flags: List[str] = field(default_factory=list)
    inferred: Dict[str, bool] = field(default_factory=dict)  # Track what was inferred


@dataclass
class Ingredient:
    """Recipe ingredient"""
    name: str
    amount: Optional[float] = None
    unit: Optional[str] = None
    from_offer_id: Optional[str] = None
    is_from_offer: bool = False
    price: Dict[str, Optional[float]] = field(default_factory=lambda: {
        "standard": None,
        "loyalty": None,
        "condition_label": None,
    })


@dataclass
class NutritionRange:
    """Nutrition range (min/max)"""
    min: float
    max: float


@dataclass
class Nutrition:
    """Nutrition information"""
    kcal: Optional[NutritionRange] = None
    protein_g: Optional[NutritionRange] = None
    carbs_g: Optional[NutritionRange] = None
    fat_g: Optional[NutritionRange] = None


@dataclass
class Pricing:
    """Recipe pricing"""
    estimated_total: Dict[str, Optional[float]] = field(default_factory=lambda: {
        "standard": None,
        "with_loyalty": None,
    })
    notes: Optional[str] = None


@dataclass
class Recipe:
    """Recipe model"""
    id: str
    supermarket: str
    week_key: str
    title: str
    tags: List[str] = field(default_factory=list)
    hero_image_url: str = ""
    images: List[str] = field(default_factory=list)
    servings: int = 2
    time_minutes: int = 30
    difficulty: Literal["easy", "medium", "hard"] = "medium"
    ingredients: List[Ingredient] = field(default_factory=list)
    steps: List[str] = field(default_factory=list)
    nutrition: Nutrition = field(default_factory=Nutrition)
    pricing: Pricing = field(default_factory=Pricing)
    warnings: List[str] = field(default_factory=list)

