#!/usr/bin/env python3
"""
Repair Recipes Script
Repariert canonical recipe files: assets/recipes/recipes_<market>.json
- Normalisiert Schema (alternative keys mappen)
- Renumeriert IDs (R001, R002, ...)
- Validiert und droppt invalide Rezepte
"""

import json
import re
from pathlib import Path
from typing import Dict, List, Set, Optional, Any
from collections import defaultdict
from datetime import datetime, date
import calendar

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_RECIPES_DIR = PROJECT_ROOT / 'assets' / 'recipes'

# HART: Nur diese Markets sind erlaubt (Globus entfernt)
ALLOWED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'lidl', 'rewe', 'edeka', 'kaufland',
    'netto', 'penny', 'norma', 'biomarkt', 'tegut'
}

# Required fields für from_offer=true ingredients
OFFER_REQUIRED_FIELDS = [
    'offer_id', 'name', 'brand', 'unit', 'pack_size', 
    'packs_used', 'used_amount', 'price_eur', 'price_before_eur'
]

# Basiszutaten (immer vorhanden)
BASE_INGREDIENTS = [
    {"name": "Salz", "amount": "nach Bedarf"},
    {"name": "Pfeffer", "amount": "nach Bedarf"},
    {"name": "Öl", "amount": "nach Bedarf"},
    {"name": "Wasser", "amount": "nach Bedarf"},
]


def normalize_recipe_id(recipe_id: str, index: int) -> str:
    """Normalisiert Recipe-ID zu R### Format (1-999)"""
    # Ignoriere UUIDs, "netto-1", etc.
    # Renumeriere sequenziell
    return f'R{index+1:03d}'


def map_alternative_keys(recipe: Dict) -> Dict:
    """Mappt alternative Keys zu Standard-Keys"""
    mapped = {}
    
    # title
    mapped['title'] = (
        recipe.get('title') or 
        recipe.get('name') or 
        recipe.get('recipe_title') or 
        ''
    )
    
    # retailer
    mapped['retailer'] = (
        recipe.get('retailer') or 
        recipe.get('store') or 
        recipe.get('supermarket') or 
        recipe.get('market') or 
        ''
    )
    
    # valid_from
    mapped['valid_from'] = (
        recipe.get('valid_from') or 
        recipe.get('validFrom') or 
        recipe.get('date_from') or 
        recipe.get('offer_valid_from') or 
        recipe.get('start_date') or 
        None
    )
    
    # servings (keep if present; default to 2)
    servings_raw = (
        recipe.get('servings') or 
        recipe.get('portions') or 
        recipe.get('yield') or 
        2
    )
    try:
        mapped['servings'] = int(servings_raw)
        if mapped['servings'] <= 0:
            mapped['servings'] = 2
    except:
        mapped['servings'] = 2
    
    # duration_minutes
    mapped['duration_minutes'] = (
        recipe.get('duration_minutes') or 
        recipe.get('duration') or 
        recipe.get('time_minutes') or 
        recipe.get('minutes') or 
        None
    )
    
    # difficulty
    difficulty_raw = recipe.get('difficulty') or recipe.get('level') or ''
    difficulty_map = {
        'leicht': 'easy',
        'mittel': 'medium',
        'schwer': 'hard',
    }
    mapped['difficulty'] = difficulty_map.get(difficulty_raw.lower(), difficulty_raw or 'easy')
    
    # categories (ensure list)
    categories_raw = recipe.get('categories') or recipe.get('tags') or recipe.get('labels') or []
    if isinstance(categories_raw, str):
        categories_raw = [c.strip() for c in categories_raw.split(',')]
    if not isinstance(categories_raw, list):
        categories_raw = []
    mapped['categories'] = [c for c in categories_raw if c]
    
    # steps (ensure list)
    steps_raw = recipe.get('steps') or recipe.get('instructions') or recipe.get('method') or []
    if isinstance(steps_raw, str):
        # Split by line breaks or numbers
        steps_raw = re.split(r'\n+|\d+\.\s*', steps_raw)
        steps_raw = [s.strip() for s in steps_raw if s.strip()]
    if not isinstance(steps_raw, list):
        steps_raw = []
    mapped['steps'] = [s for s in steps_raw if s]
    
    # slug
    mapped['slug'] = (
        recipe.get('slug') or 
        recipe.get('id_slug') or 
        recipe.get('url_slug') or 
        None
    )
    if not mapped['slug'] and mapped['title']:
        # Derive from title
        slug = mapped['title'].lower()
        slug = re.sub(r'[^a-z0-9]+', '-', slug)
        slug = slug.strip('-')
        mapped['slug'] = slug[:50]  # Limit length
    
    # week_key
    mapped['week_key'] = (
        recipe.get('week_key') or 
        recipe.get('week') or 
        recipe.get('weekKey') or 
        None
    )
    if not mapped['week_key'] and mapped['valid_from']:
        # Infer from valid_from
        try:
            dt = datetime.strptime(mapped['valid_from'], '%Y-%m-%d').date()
            year, week, _ = dt.isocalendar()
            mapped['week_key'] = f'{year}-W{week:02d}'
        except:
            mapped['week_key'] = 'unknown'
    if not mapped['week_key']:
        mapped['week_key'] = 'unknown'
    
    # Copy other fields
    for key in recipe:
        if key not in ['title', 'name', 'recipe_title', 'retailer', 'store', 'supermarket', 'market',
                       'valid_from', 'validFrom', 'date_from', 'offer_valid_from', 'start_date',
                       'servings', 'portions', 'yield', 'duration_minutes', 'duration', 'time_minutes', 'minutes',
                       'difficulty', 'level', 'categories', 'tags', 'labels',
                       'steps', 'instructions', 'method', 'slug', 'id_slug', 'url_slug',
                       'week_key', 'week', 'weekKey']:
            mapped[key] = recipe[key]
    
    return mapped


def normalize_ingredients(ingredients: List[Dict]) -> List[Dict]:
    """Normalisiert Ingredients (nur offer-based)"""
    normalized = []
    
    for ing in ingredients:
        if not isinstance(ing, dict):
            continue
        
        # Setze from_offer=true wenn fehlt
        if 'from_offer' not in ing:
            ing['from_offer'] = True
        
        # Prüfe Required Fields
        missing_fields = []
        for field in OFFER_REQUIRED_FIELDS:
            if field not in ing or ing[field] is None:
                missing_fields.append(field)
        
        # Nur wenn alle Required Fields vorhanden
        if not missing_fields:
            normalized.append(ing)
    
    return normalized


def augment_categories(recipe: Dict) -> List[str]:
    """Auto-augmentiert Categories basierend auf Heuristiken"""
    categories = recipe.get('categories', [])
    categories_lower = [c.lower() for c in categories]
    
    # Sammle Keywords
    ingredients_text = ' '.join([
        ing.get('name', '').lower() 
        for ing in recipe.get('ingredients', [])
    ])
    
    title_lower = recipe.get('title', '').lower()
    text = ingredients_text + ' ' + title_lower
    
    # High Protein
    protein_keywords = ['fleisch', 'fleisch', 'huhn', 'hähnchen', 'puten', 'schwein', 'rind', 'lachs', 'thunfisch', 'fisch', 'skyr', 'quark', 'protein']
    if any(kw in text for kw in protein_keywords) and 'high protein' not in categories_lower:
        categories.append('High Protein')
    
    # Vegetarisch
    meat_keywords = ['fleisch', 'huhn', 'hähnchen', 'puten', 'schwein', 'rind', 'lachs', 'thunfisch', 'fisch']
    dairy_egg_keywords = ['milch', 'käse', 'butter', 'ei', 'eier', 'quark', 'joghurt']
    if not any(kw in text for kw in meat_keywords) and any(kw in text for kw in dairy_egg_keywords) and 'vegetarisch' not in categories_lower:
        categories.append('Vegetarisch')
    
    # Vegan
    animal_keywords = ['fleisch', 'huhn', 'hähnchen', 'puten', 'schwein', 'rind', 'lachs', 'thunfisch', 'fisch', 'milch', 'käse', 'butter', 'ei', 'eier']
    if not any(kw in text for kw in animal_keywords) and 'vegan' not in categories_lower:
        categories.append('Vegan')
    
    # Low Carb (wenn keine carbs vorhanden)
    carb_keywords = ['reis', 'pasta', 'nudeln', 'brot', 'kartoffeln', 'mehl']
    if not any(kw in text for kw in carb_keywords) and 'low carb' not in categories_lower:
        categories.append('Low Carb')
    
    # Kalorienarm
    vegetable_keywords = ['salat', 'gemüse', 'tomate', 'gurke', 'paprika', 'zucchini']
    lean_protein_keywords = ['huhn', 'hähnchen', 'puten', 'fisch']
    if (any(kw in text for kw in vegetable_keywords) and 
        any(kw in text for kw in lean_protein_keywords) and
        'kalorienarm' not in categories_lower):
        categories.append('Kalorienarm')
    
    # Kalorienreich
    rich_keywords = ['käse', 'sahne', 'creme', 'öl', 'butter', 'nüsse', 'nuss']
    if any(kw in text for kw in rich_keywords) and 'kalorienreich' not in categories_lower:
        categories.append('Kalorienreich')
    
    # Entferne Duplikate
    seen = set()
    unique = []
    for cat in categories:
        cat_lower = cat.lower()
        if cat_lower not in seen:
            seen.add(cat_lower)
            unique.append(cat)
    
    return unique


def infer_valid_from(recipe: Dict) -> Optional[str]:
    """Inferiert valid_from aus ingredient offer data"""
    ingredients = recipe.get('ingredients', [])
    valid_froms = []
    
    for ing in ingredients:
        if isinstance(ing, dict):
            # Prüfe verschiedene mögliche Felder
            for field in ['valid_from', 'validFrom', 'date_from', 'offer_valid_from', 'start_date']:
                if field in ing and ing[field]:
                    valid_froms.append(ing[field])
    
    if valid_froms:
        # Wähle minimum (frühestes Datum)
        try:
            dates = []
            for vf in valid_froms:
                try:
                    dt = datetime.strptime(str(vf), '%Y-%m-%d')
                    dates.append(dt)
                except:
                    pass
            if dates:
                min_date = min(dates)
                return min_date.strftime('%Y-%m-%d')
        except:
            pass
    
    return None


def repair_recipe(recipe: Dict, index: int) -> Optional[Dict]:
    """Repariert ein einzelnes Rezept"""
    # 1. Map alternative keys
    repaired = map_alternative_keys(recipe)
    
    # 2. Renumber ID
    repaired['id'] = normalize_recipe_id(recipe.get('id', ''), index)
    
    # 3. Normalize ingredients (nur offer-based)
    ingredients = recipe.get('ingredients', [])
    if not isinstance(ingredients, list):
        ingredients = []
    
    normalized_ingredients = normalize_ingredients(ingredients)
    
    # Recipe muss >=3 ingredients haben
    if len(normalized_ingredients) < 3:
        return None  # Drop recipe
    
    repaired['ingredients'] = normalized_ingredients
    
    # 4. Categories (>=3)
    categories = repaired.get('categories', [])
    if len(categories) < 3:
        # Auto-augment
        categories = augment_categories(repaired)
        repaired['categories'] = categories
    
    # Nochmal prüfen: muss >=3 sein
    if len(repaired['categories']) < 3:
        return None  # Drop recipe
    
    # 5. servings (keep if present; default to 2)
    try:
        servings_int = int(repaired.get('servings', 2))
    except Exception:
        servings_int = 2
    if servings_int <= 0:
        servings_int = 2
    repaired['servings'] = servings_int
    
    # 6. base_ingredients
    repaired['base_ingredients'] = BASE_INGREDIENTS
    
    # 7. extra_ingredients
    extra_ingredients = recipe.get('extra_ingredients', [])
    if not isinstance(extra_ingredients, list):
        extra_ingredients = []
    
    # Normalisiere extra_ingredients
    normalized_extra = []
    for extra in extra_ingredients:
        if isinstance(extra, str):
            normalized_extra.append({
                'name': extra,
                'amount': 'nach Bedarf'
            })
        elif isinstance(extra, dict):
            normalized_extra.append({
                'name': extra.get('name') or extra.get('ingredient') or '',
                'amount': extra.get('amount') or extra.get('quantity') or 'nach Bedarf'
            })
    
    repaired['extra_ingredients'] = normalized_extra
    
    # 8. valid_from
    if not repaired.get('valid_from'):
        inferred = infer_valid_from(repaired)
        if inferred:
            repaired['valid_from'] = inferred
        else:
            repaired['valid_from'] = datetime.now().strftime('%Y-%m-%d')
            repaired['notes'] = repaired.get('notes', '') + ' valid_from_auto'
    
    # 9. Ensure required fields exist
    if not repaired.get('title'):
        return None  # Drop recipe
    if not repaired.get('retailer'):
        return None  # Drop recipe
    if not repaired.get('steps') or len(repaired['steps']) == 0:
        return None  # Drop recipe
    
    return repaired


def repair_market(market_slug: str) -> Dict:
    """Repariert alle Rezepte eines Markts"""
    json_file = ASSETS_RECIPES_DIR / f'recipes_{market_slug}.json'
    
    if not json_file.exists():
        return {
            'market': market_slug,
            'before_count': 0,
            'after_count': 0,
            'dropped_count': 0,
            'missing_fields_stats': {},
            'error': f'File not found: {json_file.name}',
        }
    
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            recipes = data if isinstance(data, list) else [data]
    except Exception as e:
        return {
            'market': market_slug,
            'before_count': 0,
            'after_count': 0,
            'dropped_count': 0,
            'missing_fields_stats': {},
            'error': f'Error reading file: {e}',
        }
    
    before_count = len(recipes)
    repaired_recipes = []
    missing_fields_stats = defaultdict(int)
    
    for i, recipe in enumerate(recipes):
        if not isinstance(recipe, dict):
            missing_fields_stats['invalid_recipe_object'] += 1
            continue
        
        repaired = repair_recipe(recipe, len(repaired_recipes))
        if repaired:
            repaired_recipes.append(repaired)
        else:
            missing_fields_stats['dropped_recipe'] += 1
    
    # Überschreibe Datei
    try:
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(repaired_recipes, f, indent=2, ensure_ascii=False)
    except Exception as e:
        return {
            'market': market_slug,
            'before_count': before_count,
            'after_count': len(repaired_recipes),
            'dropped_count': before_count - len(repaired_recipes),
            'missing_fields_stats': dict(missing_fields_stats),
            'error': f'Error writing file: {e}',
        }
    
    return {
        'market': market_slug,
        'before_count': before_count,
        'after_count': len(repaired_recipes),
        'dropped_count': before_count - len(repaired_recipes),
        'missing_fields_stats': dict(missing_fields_stats),
    }


def main():
    print("🔧 Repair Recipes\n")
    print("=" * 60)
    
    # Finde canonical files
    canonical_files = list(ASSETS_RECIPES_DIR.glob('recipes_*.json'))
    markets = []
    
    for f in canonical_files:
        market = f.stem.replace('recipes_', '')
        if market in ALLOWED_MARKETS:
            markets.append(market)
    
    markets.sort()
    
    if not markets:
        print("❌ Keine canonical recipe files gefunden")
        return
    
    print(f"\n📋 Gefundene Markets: {len(markets)}")
    print(f"   {', '.join(markets)}\n")
    
    results = []
    
    for market in markets:
        print(f"🔧 Repariere {market}...")
        result = repair_market(market)
        results.append(result)
        
        if result.get('error'):
            print(f"   ❌ {result['error']}")
            continue
        
        before = result['before_count']
        after = result['after_count']
        dropped = result['dropped_count']
        
        print(f"   ✅ {before} -> {after} Rezepte (dropped: {dropped})")
        
        if after < 50:
            print(f"   ⚠️  NEEDS REGEN: {after} < 50 Rezepte")
    
    print("\n" + "=" * 60)
    print("\n📊 Zusammenfassung:")
    print()
    
    for result in results:
        if result.get('error'):
            continue
        
        market = result['market']
        before = result['before_count']
        after = result['after_count']
        dropped = result['dropped_count']
        
        print(f"{market}:")
        print(f"  before_count: {before}")
        print(f"  after_count: {after}")
        print(f"  dropped_recipes_count: {dropped}")
        if result['missing_fields_stats']:
            print(f"  missing_fields_stats: {result['missing_fields_stats']}")
        if after < 50:
            print(f"  ⚠️  NEEDS REGEN")
        print()
    
    print("✅ Repair abgeschlossen!")


if __name__ == '__main__':
    main()

