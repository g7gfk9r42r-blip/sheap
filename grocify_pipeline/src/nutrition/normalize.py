"""Text normalization for nutrition matching"""
import re


def normalize_food_name(name: str) -> str:
    """Normalize food name for matching"""
    # Lowercase
    name = name.lower()
    
    # Remove special chars
    name = re.sub(r'[^\w\s]', ' ', name)
    
    # Remove common brand/packaging terms
    remove_terms = ['bio', 'öko', 'frisch', 'regional', 'xl', 'xxl', 'packung', 'dose', 'glas']
    for term in remove_terms:
        name = re.sub(r'\b' + term + r'\b', '', name)
    
    # Normalize whitespace
    name = re.sub(r'\s+', ' ', name).strip()
    
    return name


# German to English food terms for better API matching
FOOD_TRANSLATIONS = {
    'milch': 'milk',
    'käse': 'cheese',
    'joghurt': 'yogurt',
    'butter': 'butter',
    'sahne': 'cream',
    'quark': 'quark',
    'ei': 'egg',
    'eier': 'eggs',
    'fleisch': 'meat',
    'hähnchen': 'chicken',
    'rind': 'beef',
    'schwein': 'pork',
    'wurst': 'sausage',
    'schinken': 'ham',
    'brot': 'bread',
    'brötchen': 'roll',
    'nudeln': 'pasta',
    'reis': 'rice',
    'kartoffel': 'potato',
    'kartoffeln': 'potatoes',
    'tomate': 'tomato',
    'tomaten': 'tomatoes',
    'zwiebel': 'onion',
    'zwiebeln': 'onions',
    'apfel': 'apple',
    'äpfel': 'apples',
    'banane': 'banana',
    'bananen': 'bananas',
    'orange': 'orange',
    'orangen': 'oranges',
    'salat': 'lettuce',
    'gurke': 'cucumber',
    'gurken': 'cucumbers',
    'paprika': 'bell pepper',
    'champignons': 'mushrooms',
    'möhre': 'carrot',
    'möhren': 'carrots',
    'karotte': 'carrot',
    'karotten': 'carrots',
}


def get_search_term(german_name: str) -> str:
    """Get English search term for API queries"""
    normalized = normalize_food_name(german_name)
    
    # Check direct translation
    if normalized in FOOD_TRANSLATIONS:
        return FOOD_TRANSLATIONS[normalized]
    
    # Check if any key is substring
    for de, en in FOOD_TRANSLATIONS.items():
        if de in normalized:
            return en
    
    return normalized

