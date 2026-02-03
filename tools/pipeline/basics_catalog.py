"""Basics and pantry items catalog"""

PANTRY_ITEMS = {
    "Salz": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
    "Pfeffer": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
    "Zucker": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
    "Olivenöl": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
    "Essig": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
    "Gewürze": {"price_range": [0.0, 0.0], "unit": "ignoriert"},
}

BASIC_ITEMS = {
    "Eier": {
        "price_range": [2.0, 4.0],
        "unit": "10 Stück",
        "store_zone": "Kühlregal",
        "search_terms": ["eier", "frische eier", "bio eier"]
    },
    "Zwiebeln": {
        "price_range": [0.8, 2.0],
        "unit": "1 kg",
        "store_zone": "Obst & Gemüse",
        "search_terms": ["zwiebeln", "speisezwiebeln"]
    },
    "Knoblauch": {
        "price_range": [1.0, 2.5],
        "unit": "1 Stück",
        "store_zone": "Obst & Gemüse",
        "search_terms": ["knoblauch"]
    },
    "Butter": {
        "price_range": [1.5, 3.0],
        "unit": "250g",
        "store_zone": "Kühlregal",
        "search_terms": ["butter", "deutsche butter"]
    },
    "Milch": {
        "price_range": [0.8, 1.5],
        "unit": "1l",
        "store_zone": "Kühlregal",
        "search_terms": ["milch", "frische milch", "vollmilch"]
    },
}


def is_pantry(name: str) -> bool:
    """Check if item is pantry"""
    name_lower = name.lower()
    return any(p.lower() in name_lower for p in PANTRY_ITEMS.keys())


def is_basic(name: str) -> bool:
    """Check if item is basic"""
    name_lower = name.lower()
    return any(b.lower() in name_lower for b in BASIC_ITEMS.keys())


def get_basic_info(name: str) -> dict:
    """Get basic item info"""
    name_lower = name.lower()
    for basic_name, info in BASIC_ITEMS.items():
        if basic_name.lower() in name_lower:
            return {
                "availability": "basic",
                "price_range": info["price_range"],
                "find_it_fast": {
                    "store_zone": info["store_zone"],
                    "search_terms": info["search_terms"]
                }
            }
    return {}

