#!/usr/bin/env python3
"""
Schema Adapter: Normalisiert verschiedene Recipe-JSON-Formate zu einem Standard-Schema
KEINE Inhalte erfinden, nur Felder umbenennen/normalisieren
"""

from typing import Dict, List, Any, Optional


def normalize_recipe(recipe: Dict) -> Dict:
    """
    Normalisiert ein Rezept zu Standard-Schema.
    KEINE neuen Inhalte, nur Feld-Mapping.
    """
    normalized = {}
    
    # ID (muss vorhanden sein)
    normalized['id'] = recipe.get('id') or recipe.get('recipe_id') or recipe.get('_id')
    
    # Title/Name
    normalized['title'] = (
        recipe.get('title') or 
        recipe.get('name') or 
        recipe.get('recipe_title') or 
        recipe.get('headline') or
        ''
    )
    
    # Description (optional)
    normalized['description'] = (
        recipe.get('description') or 
        recipe.get('desc') or 
        recipe.get('summary') or
        ''
    )
    
    # Categories/Tags
    categories = (
        recipe.get('categories') or 
        recipe.get('tags') or 
        recipe.get('labels') or
        []
    )
    if isinstance(categories, str):
        categories = [c.strip() for c in categories.split(',') if c.strip()]
    normalized['categories'] = [str(c).strip() for c in categories if c] if isinstance(categories, list) else []
    
    # Servings
    servings = (
        recipe.get('servings') or 
        recipe.get('portions') or 
        recipe.get('yield') or
        1
    )
    try:
        normalized['servings'] = int(servings)
        if normalized['servings'] <= 0:
            normalized['servings'] = 1
    except:
        normalized['servings'] = 1
    
    # Ingredients (Angebotszutaten) - from_offer=true
    # WICHTIG: Behalte die bestehende Struktur bei, normalisiere nur Felder
    ingredients_raw = recipe.get('ingredients') or recipe.get('ingredients_offers') or []
    
    if isinstance(ingredients_raw, list):
        # Normalisiere jedes Ingredient-Objekt
        normalized_ingredients = []
        for ing in ingredients_raw:
            if isinstance(ing, dict):
                # Normalisiere Felder (behalte alle bestehenden)
                normalized_ing = dict(ing)  # Kopiere alle Felder
                
                # Normalisiere nur Feldnamen (keine Inhalte erfinden)
                if 'offerId' in normalized_ing and 'offer_id' not in normalized_ing:
                    normalized_ing['offer_id'] = normalized_ing.pop('offerId')
                if 'fromOffer' in normalized_ing and 'from_offer' not in normalized_ing:
                    normalized_ing['from_offer'] = normalized_ing.pop('fromOffer')
                if 'priceEur' in normalized_ing and 'price_eur' not in normalized_ing:
                    normalized_ing['price_eur'] = normalized_ing.pop('priceEur')
                if 'priceBeforeEur' in normalized_ing and 'price_before_eur' not in normalized_ing:
                    normalized_ing['price_before_eur'] = normalized_ing.pop('priceBeforeEur')
                if 'packsUsed' in normalized_ing and 'packs_used' not in normalized_ing:
                    normalized_ing['packs_used'] = normalized_ing.pop('packsUsed')
                if 'usedAmount' in normalized_ing and 'used_amount' not in normalized_ing:
                    normalized_ing['used_amount'] = normalized_ing.pop('usedAmount')
                if 'packSize' in normalized_ing and 'pack_size' not in normalized_ing:
                    normalized_ing['pack_size'] = normalized_ing.pop('packSize')
                
                # Stelle sicher dass from_offer gesetzt ist
                if 'from_offer' not in normalized_ing:
                    normalized_ing['from_offer'] = bool(normalized_ing.get('offer_id'))
                
                normalized_ingredients.append(normalized_ing)
            else:
                # Fallback: String oder andere Typen (behalte bei)
                normalized_ingredients.append(ing)
        
        normalized['ingredients'] = normalized_ingredients
    
    # Extra Ingredients (ohne from_offer)
    extra_ingredients = []
    extra_raw = recipe.get('extra_ingredients') or recipe.get('extraIngredients') or recipe.get('additional_ingredients') or []
    
    if isinstance(extra_raw, list):
        for extra in extra_raw:
            if isinstance(extra, dict):
                extra_ing = {
                    'name': extra.get('name') or extra.get('ingredient') or '',
                    'amount': extra.get('amount') or extra.get('quantity') or '',
                    'unit': extra.get('unit') or '',
                }
                if extra_ing['name']:
                    extra_ingredients.append(extra_ing)
            elif isinstance(extra, str):
                extra_ingredients.append({
                    'name': extra,
                    'amount': '',
                    'unit': '',
                })
    
    normalized['extra_ingredients'] = extra_ingredients
    
    # Instructions/Steps
    steps_raw = (
        recipe.get('steps') or 
        recipe.get('instructions') or 
        recipe.get('method') or
        []
    )
    
    if isinstance(steps_raw, str):
        # Split by newlines or numbers
        import re
        steps_raw = re.split(r'\n+|\d+\.\s*', steps_raw)
        steps_raw = [s.strip() for s in steps_raw if s.strip()]
    
    normalized['steps'] = [str(s).strip() for s in steps_raw if s] if isinstance(steps_raw, list) else []
    
    # Duration
    normalized['duration_minutes'] = (
        recipe.get('duration_minutes') or 
        recipe.get('durationMinutes') or 
        recipe.get('duration') or 
        recipe.get('time_minutes') or
        None
    )
    
    # Difficulty
    difficulty = recipe.get('difficulty') or recipe.get('level') or ''
    difficulty_map = {
        'leicht': 'easy',
        'mittel': 'medium',
        'schwer': 'hard',
    }
    normalized['difficulty'] = difficulty_map.get(difficulty.lower(), difficulty or 'easy')
    
    # Retailer
    normalized['retailer'] = (
        recipe.get('retailer') or 
        recipe.get('supermarket') or 
        recipe.get('market') or
        ''
    )
    
    # Valid from
    normalized['valid_from'] = (
        recipe.get('valid_from') or 
        recipe.get('validFrom') or 
        recipe.get('date_from') or
        None
    )
    
    # Week key
    normalized['week_key'] = (
        recipe.get('week_key') or 
        recipe.get('weekKey') or 
        recipe.get('week') or
        None
    )
    
    # Copy other fields (falls vorhanden)
    known_fields = {
        'id', 'recipe_id', '_id', 'title', 'name', 'recipe_title', 'headline',
        'description', 'desc', 'summary', 'categories', 'tags', 'labels',
        'servings', 'portions', 'yield', 'ingredients', 'ingredients_offers',
        'extra_ingredients', 'extraIngredients', 'additional_ingredients',
        'steps', 'instructions', 'method', 'duration_minutes', 'durationMinutes',
        'duration', 'time_minutes', 'difficulty', 'level', 'retailer',
        'supermarket', 'market', 'valid_from', 'validFrom', 'date_from',
        'week_key', 'weekKey', 'week', 'image_path', 'imagePath', 'image_asset',
    }
    
    for key, value in recipe.items():
        if key not in known_fields and key not in normalized:
            normalized[key] = value
    
    return normalized

