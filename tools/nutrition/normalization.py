"""
Text normalization, synonym mapping, and pantry exclusion for ingredient matching.
"""

import re
from typing import Dict, List, Set
from unicodedata import normalize as unicode_normalize


# Pantry items that should be excluded from shopping/price/nutrition
PANTRY_EXCLUDE: Set[str] = {
    # Gewürze & Würzmittel
    "salz", "pfeffer", "gewuerze", "gewürze", "paprika edelsüß", "paprika edelsuess",
    "paprikapulver", "chili", "chiliflocken", "chilipulver", "muskat", "muskatnuss",
    "knoblauchpulver", "zwiebelpulver", "currypulver", "curry", "kurkuma",
    "kreuzkümmel", "koriander", "zimt", "nelken", "kardamom", "ingwerpulver",
    "oregano", "basilikum", "thymian", "rosmarin", "majoran", "dill", "petersilie",
    "schnittlauch", "kräuter", "kraeuter", "kräutermischung",
    
    # Back-Zutaten (Basics)
    "backpulver", "natron", "hefe", "trockenhefe", "vanillezucker", "vanillin",
    "speisestärke", "speisestaerke", "stärke", "staerke", "maisstärke",
    
    # Öle & Essig (Standard)
    "pflanzenöl", "pflanzenoel", "rapsöl", "rapsoel", "sonnenblumenöl", "sonnenblumenoel",
    "essig", "weinessig", "balsamico", "apfelessig",
    
    # Sonstiges
    "wasser", "brühe", "bruehe", "gemüsebrühe", "gemuesebruehe",
    "fleischbrühe", "fleischbruehe", "instant brühe", "brühwürfel", "bruehwuerfel",
}

# Stopwords, die beim Matching entfernt werden können
STOPWORDS: Set[str] = {
    "frisch", "frische", "frischer", "frisches",
    "bio", "öko", "oeko", "demeter", "naturland",
    "xxl", "xl", "groß", "gross", "klein",
    "packung", "beutel", "dose", "glas", "flasche",
    "schale", "netz", "bund", "stuck", "stück",
    "ca", "circa", "etwa",
    "deutsche", "deutscher", "deutsches", "regional",
    "tiefgekühlt", "tiefgekuehlt", "tk",
    "neu", "premium", "edel", "fein", "extra",
}

# Deutsche -> Englische Synonyme für besseres API-Matching
SYNONYM_MAP: Dict[str, str] = {
    # Fleisch & Wurst
    "hackfleisch": "ground meat",
    "rinderhack": "ground beef",
    "schweinehack": "ground pork",
    "gemischtes hack": "mixed ground meat",
    "hähnchenbrust": "chicken breast",
    "haehnchenbrust": "chicken breast",
    "hähnchen": "chicken",
    "haehnchen": "chicken",
    "putenbrust": "turkey breast",
    "schweinefleisch": "pork",
    "schweinefilet": "pork tenderloin",
    "rindfleisch": "beef",
    "rindersteak": "beef steak",
    "würstchen": "sausage",
    "wuerstchen": "sausage",
    "bratwurst": "bratwurst sausage",
    "speck": "bacon",
    "schinken": "ham",
    
    # Milchprodukte
    "milch": "milk",
    "vollmilch": "whole milk",
    "frische milch": "fresh milk",
    "haltbare milch": "uht milk",
    "sahne": "cream",
    "schlagsahne": "whipping cream",
    "saure sahne": "sour cream",
    "schmand": "sour cream",
    "quark": "quark",
    "joghurt": "yogurt",
    "naturjoghurt": "plain yogurt",
    "käse": "cheese",
    "kaese": "cheese",
    "gouda": "gouda cheese",
    "emmentaler": "emmental cheese",
    "mozzarella": "mozzarella",
    "frischkäse": "cream cheese",
    "frischkaese": "cream cheese",
    "butter": "butter",
    
    # Gemüse
    "kartoffeln": "potatoes",
    "kartoffel": "potato",
    "süßkartoffel": "sweet potato",
    "suesskartoffel": "sweet potato",
    "zwiebeln": "onions",
    "zwiebel": "onion",
    "knoblauch": "garlic",
    "möhren": "carrots",
    "moehren": "carrots",
    "karotten": "carrots",
    "karotte": "carrot",
    "paprika": "bell pepper",
    "tomate": "tomato",
    "tomaten": "tomatoes",
    "gurke": "cucumber",
    "gurken": "cucumbers",
    "zucchini": "zucchini",
    "aubergine": "eggplant",
    "brokkoli": "broccoli",
    "blumenkohl": "cauliflower",
    "champignons": "mushrooms",
    "champignon": "mushroom",
    "braune champignons": "brown mushrooms",
    "spinat": "spinach",
    "salat": "lettuce",
    "eisbergsalat": "iceberg lettuce",
    "rucola": "arugula",
    "lauch": "leek",
    "porree": "leek",
    "sellerie": "celery",
    "kürbis": "pumpkin",
    "kuerbis": "pumpkin",
    
    # Obst
    "äpfel": "apples",
    "aepfel": "apples",
    "apfel": "apple",
    "birne": "pear",
    "birnen": "pears",
    "banane": "banana",
    "bananen": "bananas",
    "orange": "orange",
    "orangen": "oranges",
    "zitrone": "lemon",
    "zitronen": "lemons",
    "limette": "lime",
    "limetten": "limes",
    "erdbeeren": "strawberries",
    "himbeeren": "raspberries",
    "blaubeeren": "blueberries",
    "heidelbeeren": "blueberries",
    "weintrauben": "grapes",
    "trauben": "grapes",
    
    # Getreide & Teigwaren
    "mehl": "flour",
    "weizenmehl": "wheat flour",
    "vollkornmehl": "whole wheat flour",
    "reis": "rice",
    "basmati reis": "basmati rice",
    "parboiled reis": "parboiled rice",
    "vollkornreis": "brown rice",
    "nudeln": "pasta",
    "spaghetti": "spaghetti",
    "penne": "penne",
    "fusilli": "fusilli",
    "lasagne": "lasagna",
    "lasagneplatten": "lasagna sheets",
    "brot": "bread",
    "vollkornbrot": "whole grain bread",
    "toast": "toast",
    "brötchen": "bread roll",
    "broetchen": "bread roll",
    
    # Hülsenfrüchte & Konserven
    "bohnen": "beans",
    "kidneybohnen": "kidney beans",
    "weiße bohnen": "white beans",
    "weisse bohnen": "white beans",
    "kichererbsen": "chickpeas",
    "linsen": "lentils",
    "rote linsen": "red lentils",
    "erbsen": "peas",
    "mais": "corn",
    "dosenmais": "canned corn",
    "dosentomaten": "canned tomatoes",
    "tomatenmark": "tomato paste",
    "passierte tomaten": "crushed tomatoes",
    
    # Sonstiges
    "eier": "eggs",
    "ei": "egg",
    "zucker": "sugar",
    "brauner zucker": "brown sugar",
    "honig": "honey",
    "marmelade": "jam",
    "konfitüre": "jam",
    "konfituere": "jam",
    "nüsse": "nuts",
    "nuesse": "nuts",
    "mandeln": "almonds",
    "walnüsse": "walnuts",
    "walnuesse": "walnuts",
    "haselnüsse": "hazelnuts",
    "haselnuesse": "hazelnuts",
}

# Density table for ml -> g conversion (g/ml)
DENSITY_TABLE: Dict[str, float] = {
    "wasser": 1.0,
    "water": 1.0,
    "milch": 1.03,
    "milk": 1.03,
    "sahne": 1.01,
    "cream": 1.01,
    "joghurt": 1.03,
    "yogurt": 1.03,
    "öl": 0.91,
    "oel": 0.91,
    "oil": 0.91,
    "olivenöl": 0.91,
    "olivenoel": 0.91,
    "olive oil": 0.91,
    "rapsöl": 0.92,
    "rapsoel": 0.92,
    "rapeseed oil": 0.92,
    "sonnenblumenöl": 0.92,
    "sonnenblumenoel": 0.92,
    "sunflower oil": 0.92,
    "honig": 1.42,
    "honey": 1.42,
    "sirup": 1.37,
    "syrup": 1.37,
    "essig": 1.01,
    "vinegar": 1.01,
    "wein": 0.99,
    "wine": 0.99,
    "bier": 1.01,
    "beer": 1.01,
    "brühe": 1.00,
    "bruehe": 1.00,
    "broth": 1.00,
    "stock": 1.00,
    "saft": 1.04,
    "juice": 1.04,
}


def normalize_text(text: str) -> str:
    """
    Basic text normalization: lowercase, unicode normalization, whitespace cleanup.
    """
    if not text:
        return ""
    
    # Unicode normalization (NFD = decomposed form)
    text = unicode_normalize('NFD', text)
    # Convert to ASCII, removing diacritics
    text = text.encode('ascii', 'ignore').decode('ascii')
    
    # Replace umlauts manually for German
    text = text.replace('ä', 'ae').replace('ö', 'oe').replace('ü', 'ue')
    text = text.replace('Ä', 'ae').replace('Ö', 'oe').replace('Ü', 'ue')
    text = text.replace('ß', 'ss')
    
    # Lowercase
    text = text.lower()
    
    # Remove special characters but keep spaces and alphanumeric
    text = re.sub(r'[^\w\s%]', ' ', text)
    
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text).strip()
    
    return text


def remove_shop_suffixes(text: str) -> str:
    """
    Remove shop-specific suffixes and marketing terms.
    """
    patterns = [
        r'\s*[-–—]\s*(aldi|lidl|edeka|rewe|kaufland|netto|penny|tegut).*$',
        r'\s+xxl\s*$',
        r'\s+xl\s*$',
        r'\s+uvp.*$',
        r'\s+kg\s*=.*$',
        r'\s+\d+\s*[-–]\s*[lkg][-–]packung.*$',
        r'\s+packung\s*$',
        r'\s+beutel\s*$',
        r'\s+dose\s*$',
        r'\s+ca\s+\d+.*$',
        r'\s+\d+\s*g\s*$',
        r'\s+\d+\s*ml\s*$',
        r'\s+\d+\s*kg\s*$',
        r'\s+\d+\s*l\s*$',
        r'\s+\d+\s*stuck\s*$',
        r'\s+\d+\s*stueck\s*$',
    ]
    
    result = text
    for pattern in patterns:
        result = re.sub(pattern, '', result, flags=re.IGNORECASE)
    
    return result.strip()


def remove_stopwords(text: str, stopwords: Set[str] = STOPWORDS) -> str:
    """
    Remove stopwords from text.
    """
    words = text.split()
    filtered = [w for w in words if w not in stopwords]
    return ' '.join(filtered)


def normalize_name(name: str, remove_stops: bool = True) -> str:
    """
    Full normalization pipeline for ingredient name matching.
    
    Args:
        name: Raw ingredient name
        remove_stops: Whether to remove stopwords
    
    Returns:
        Normalized string suitable for matching
    """
    # Basic normalization
    normalized = normalize_text(name)
    
    # Remove shop suffixes
    normalized = remove_shop_suffixes(normalized)
    
    # Remove stopwords if requested
    if remove_stops:
        normalized = remove_stopwords(normalized)
    
    # Final cleanup
    normalized = re.sub(r'\s+', ' ', normalized).strip()
    
    return normalized


def get_canonical_key(name: str) -> str:
    """
    Generate a canonical key for caching and matching.
    
    Args:
        name: Raw ingredient name
    
    Returns:
        Canonical key (normalized, potentially with synonym applied)
    """
    # Normalize
    normalized = normalize_name(name, remove_stops=True)
    
    # Check for exact synonym match
    if normalized in SYNONYM_MAP:
        return SYNONYM_MAP[normalized]
    
    # Check for partial matches (contains)
    for german, english in SYNONYM_MAP.items():
        if german in normalized:
            # Replace first occurrence
            normalized = normalized.replace(german, english, 1)
            break
    
    return normalized


def is_pantry_item(name: str) -> bool:
    """
    Check if ingredient should be excluded as pantry item.
    
    Args:
        name: Ingredient name (raw or normalized)
    
    Returns:
        True if it's a pantry item
    """
    normalized = normalize_name(name, remove_stops=False)
    
    # Exact match
    if normalized in PANTRY_EXCLUDE:
        return True
    
    # Partial match (e.g., "paprika edelsüß" contains "paprika")
    words = normalized.split()
    for word in words:
        if word in PANTRY_EXCLUDE:
            return True
    
    return False


def get_density(ingredient_name: str, unit: str = "ml") -> tuple[float, bool]:
    """
    Get density for ml -> g conversion.
    
    Args:
        ingredient_name: Normalized ingredient name
        unit: Unit (should be 'ml')
    
    Returns:
        (density_value, needs_manual_check)
        If needs_manual_check=True, density is a guess
    """
    if unit.lower() != "ml":
        return 1.0, False  # Not applicable
    
    normalized = normalize_name(ingredient_name, remove_stops=True)
    
    # Exact match
    if normalized in DENSITY_TABLE:
        return DENSITY_TABLE[normalized], False
    
    # Partial match
    for key, density in DENSITY_TABLE.items():
        if key in normalized or normalized in key:
            return density, False
    
    # Default to water density, but flag for manual check
    return 1.0, True


def calculate_string_similarity(a: str, b: str) -> float:
    """
    Simple string similarity metric (Jaccard similarity of words).
    
    Returns:
        Similarity score between 0.0 and 1.0
    """
    if not a or not b:
        return 0.0
    
    words_a = set(a.lower().split())
    words_b = set(b.lower().split())
    
    if not words_a or not words_b:
        return 0.0
    
    intersection = words_a & words_b
    union = words_a | words_b
    
    return len(intersection) / len(union) if union else 0.0

