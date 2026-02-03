#!/usr/bin/env python3
"""
Hard Validator für Rezepte
Validiert NUR canonical files: assets/recipes/recipes_<market>.json
"""

import json
import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Set, Optional
from collections import defaultdict
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_RECIPES_DIR = PROJECT_ROOT / 'assets' / 'recipes'

# HART: Nur diese Markets sind erlaubt (Globus entfernt)
ALLOWED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'lidl', 'rewe', 'edeka', 'kaufland',
    'netto', 'penny', 'norma', 'biomarkt', 'tegut'
}

# Required fields pro Rezept
REQUIRED_FIELDS = ['id', 'title', 'retailer', 'valid_from', 'servings', 'categories', 'ingredients', 'steps']

# Konfigurierbare Limits (CLI)
MIN_RECIPES_PER_MARKET = 50
MAX_RECIPES_PER_MARKET = 100
MIN_CATEGORIES = 3
MIN_INGREDIENTS = 3

# Basiszutaten (nicht erlaubt in extra_ingredients)
BASIC_INGREDIENTS = {'salz', 'pfeffer', 'öl', 'wasser', 'zucker', 'butter', 'mehl'}

# Required fields für from_offer=true ingredients
OFFER_REQUIRED_FIELDS = [
    'offer_id', 'name', 'brand', 'unit', 'pack_size', 
    'packs_used', 'used_amount', 'price_eur', 'price_before_eur'
]


def normalize_recipe_id(recipe_id: str) -> Optional[str]:
    """Normalisiert Recipe-ID zu R### Format (1-999), R000 und >999 sind invalid"""
    if not recipe_id:
        return None
    
    if '-' in recipe_id:
        recipe_id = recipe_id.split('-')[-1]
    
    match = re.match(r'[rR]?(\d+)', recipe_id)
    if match:
        num = int(match.group(1))
        # NUR 1-999 erlaubt
        if 1 <= num <= 999:
            return f'R{num:03d}'
    
    # Invalid: R000, >999, Hex, etc.
    return None


def extract_market_slug_from_canonical(filename: str) -> Optional[str]:
    """Extrahiert market_slug aus recipes_<market_slug>.json (NUR canonical, kein weekKey)"""
    if not filename.startswith('recipes_') or not filename.endswith('.json'):
        return None
    
    # Canonical: recipes_<market>.json (kein _weekKey, kein _with, kein _unknown)
    slug_part = filename[8:-5]  # Nach "recipes_" und vor ".json"
    
    # Filtere "with" und "unknown"
    if 'with' in slug_part.lower() or 'unknown' in slug_part.lower():
        return None
    
    # Prüfe ob in ALLOWED_MARKETS
    if slug_part in ALLOWED_MARKETS:
        return slug_part
    
    return None


def validate_recipe(recipe: Dict, index: int) -> List[str]:
    """Validiert ein einzelnes Rezept"""
    errors = []
    recipe_id = recipe.get('id', f'INDEX_{index}')
    
    # Required Fields
    for field in REQUIRED_FIELDS:
        if field not in recipe or not recipe[field]:
            errors.append(f"[{recipe_id}] Missing required field: {field}")
    
    # ID Format (R001-R999)
    if 'id' in recipe:
        rid = recipe['id']
        normalized = normalize_recipe_id(rid)
        if not normalized or not re.match(r'^R\d{3}$', normalized):
            errors.append(f"[{recipe_id}] Invalid ID format: {rid} (expected R001-R999, got invalid)")
    
    # Categories >= 3
    categories = recipe.get('categories', [])
    if not isinstance(categories, list) or len(categories) < MIN_CATEGORIES:
        errors.append(f"[{recipe_id}] categories count < {MIN_CATEGORIES}: {len(categories) if isinstance(categories, list) else 0}")
    
    # Ingredients >= 3
    ingredients = recipe.get('ingredients', [])
    if not isinstance(ingredients, list):
        errors.append(f"[{recipe_id}] ingredients must be a list")
    elif len(ingredients) < MIN_INGREDIENTS:
        errors.append(f"[{recipe_id}] ingredients count < {MIN_INGREDIENTS}: {len(ingredients)}")
    else:
        # Validiere from_offer ingredients
        for i, ing in enumerate(ingredients):
            if isinstance(ing, dict) and ing.get('from_offer') is True:
                for field in OFFER_REQUIRED_FIELDS:
                    if field not in ing or ing[field] is None:
                        errors.append(f"[{recipe_id}] ingredient[{i}] missing field '{field}' (from_offer=true)")
    
    # valid_from Format (YYYY-MM-DD)
    valid_from = recipe.get('valid_from')
    if valid_from:
        if not isinstance(valid_from, str) or not re.match(r'^\d{4}-\d{2}-\d{2}$', valid_from):
            errors.append(f"[{recipe_id}] invalid valid_from format: {valid_from} (expected YYYY-MM-DD)")
    
    # servings > 0
    servings = recipe.get('servings')
    if servings is None or (isinstance(servings, (int, float)) and servings <= 0):
        errors.append(f"[{recipe_id}] invalid servings: {servings}")
    
    # steps non-empty
    steps = recipe.get('steps', [])
    if not isinstance(steps, list) or len(steps) == 0:
        errors.append(f"[{recipe_id}] steps must be non-empty list")
    
    # extra_ingredients: keine Basiszutaten
    extra_ingredients = recipe.get('extra_ingredients', [])
    if extra_ingredients:
        for extra in extra_ingredients:
            if isinstance(extra, str):
                name_lower = extra.lower()
                if any(basic in name_lower for basic in BASIC_INGREDIENTS):
                    errors.append(f"[{recipe_id}] extra_ingredients contains basic ingredient: {extra}")
    
    return errors


def validate_market(market_slug: str) -> Dict:
    """Validiert canonical file für einen Markt"""
    json_file = ASSETS_RECIPES_DIR / f'recipes_{market_slug}.json'
    
    if not json_file.exists():
        return {
            'market': market_slug,
            'valid': False,
            'error': f'Canonical file not found: {json_file.name}',
            'recipes_count': 0,
            'unique_id_count': 0,
            'duplicate_ids': [],
            'errors': [],
        }
    
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            recipes = data if isinstance(data, list) else [data]
    except Exception as e:
        return {
            'market': market_slug,
            'valid': False,
            'error': f'Error reading file: {e}',
            'recipes_count': 0,
            'unique_id_count': 0,
            'duplicate_ids': [],
            'errors': [],
        }
    
    recipes_count = len(recipes)
    
    # Sammle IDs (nur valide R001-R999)
    recipe_ids = []
    id_to_indices = defaultdict(list)
    
    for i, recipe in enumerate(recipes):
        rid = recipe.get('id', '')
        if rid:
            normalized = normalize_recipe_id(rid)
            # NUR valide IDs
            if normalized:
                recipe_ids.append(normalized)
                id_to_indices[normalized].append(i)
    
    unique_ids = set(recipe_ids)
    unique_id_count = len(unique_ids)
    duplicate_ids = [rid for rid, indices in id_to_indices.items() if len(indices) > 1]
    
    # Validiere Rezepte
    all_errors = []
    for i, recipe in enumerate(recipes):
        errors = validate_recipe(recipe, i)
        all_errors.extend(errors)
    
    # Recipe Count Validation
    count_valid = MIN_RECIPES_PER_MARKET <= recipes_count <= MAX_RECIPES_PER_MARKET
    
    # Gesamtvalidierung
    valid = (
        count_valid and
        len(duplicate_ids) == 0 and
        len(all_errors) == 0
    )
    
    return {
        'market': market_slug,
        'valid': valid,
        'recipes_count': recipes_count,
        'unique_id_count': unique_id_count,
        'duplicate_ids': duplicate_ids,
        'errors': all_errors,
        'count_valid': count_valid,
    }


def main():
    parser = argparse.ArgumentParser(description='Validiert canonical recipe files')
    parser.add_argument('--strict-count', action='store_true',
                       help='Erzwingt 50-100 Rezepte pro Markt')
    parser.add_argument('--repair-before-validate', action='store_true',
                       help='Führt repair_recipes.py aus vor Validierung')
    parser.add_argument('--market', type=str, help='Validiere nur diesen Markt')
    args = parser.parse_args()
    
    # Repair vor Validierung falls gewünscht
    if args.repair_before_validate:
        print("🔧 Repair vor Validierung...")
        import subprocess
        result = subprocess.run(
            [sys.executable, str(PROJECT_ROOT / 'tools' / 'repair_recipes.py')],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(f"⚠️  Repair fehlgeschlagen: {result.stderr}")
        else:
            print(result.stdout)
        print()
    
    if args.strict_count:
        global MIN_RECIPES_PER_MARKET, MAX_RECIPES_PER_MARKET
        MIN_RECIPES_PER_MARKET = 50
        MAX_RECIPES_PER_MARKET = 100
    
    print("🔍 Rezept-Validierung (Canonical Files Only)\n")
    print("=" * 60)
    
    # Finde Markets: NUR canonical files (recipes_<market>.json)
    if args.market:
        if args.market not in ALLOWED_MARKETS:
            print(f"❌ Market '{args.market}' nicht in erlaubten Markets: {', '.join(sorted(ALLOWED_MARKETS))}")
            sys.exit(2)
        markets = [args.market]
    else:
        # Scan canonical files only
        canonical_files = list(ASSETS_RECIPES_DIR.glob('recipes_*.json'))
        markets_set = set()
        
        for f in canonical_files:
            market = extract_market_slug_from_canonical(f.name)
            # NUR erlaubte Markets, NUR canonical (kein weekKey im Namen)
            if market and market in ALLOWED_MARKETS:
                markets_set.add(market)
        
        markets = sorted(list(markets_set))
    
    if not markets:
        print("❌ Keine canonical recipe files gefunden in assets/recipes/")
        print(f"   Erwartet: recipes_<market>.json für Markets: {', '.join(sorted(ALLOWED_MARKETS))}")
        sys.exit(2)
    
    print(f"\n📋 Gefundene Markets (canonical): {len(markets)}")
    print(f"   {', '.join(markets)}\n")
    
    results = []
    all_valid = True
    
    for market in markets:
        print(f"🔍 Validiere {market}...")
        result = validate_market(market)
        results.append(result)
        
        if result.get('error'):
            print(f"   ❌ {result['error']}")
            all_valid = False
            continue
        
        count = result['recipes_count']
        unique = result['unique_id_count']
        duplicates = len(result['duplicate_ids'])
        errors = len(result['errors'])
        
        status = "✅" if result['valid'] else "❌"
        print(f"   {status} {count} Rezepte, {unique} unique IDs")
        
        if not result['count_valid']:
            print(f"      ⚠️  Recipe count: {count} (erwartet: {MIN_RECIPES_PER_MARKET}-{MAX_RECIPES_PER_MARKET})")
            all_valid = False
        
        if duplicates > 0:
            print(f"      ⚠️  {duplicates} Duplikate: {result['duplicate_ids'][:5]}")
            all_valid = False
        
        if errors > 0:
            print(f"      ⚠️  {errors} Fehler gefunden")
            all_valid = False
            # Zeige erste 5 Fehler
            for error in result['errors'][:5]:
                print(f"         - {error}")
            if errors > 5:
                print(f"         ... und {errors - 5} weitere")
    
    print("\n" + "=" * 60)
    
    # Zusammenfassung
    total_recipes = sum(r['recipes_count'] for r in results)
    total_duplicates = sum(len(r['duplicate_ids']) for r in results)
    total_errors = sum(len(r['errors']) for r in results)
    
    print(f"\n📊 Zusammenfassung:")
    print(f"   Märkte (canonical): {len(markets)}")
    print(f"   Rezepte gesamt: {total_recipes}")
    print(f"   Duplikate: {total_duplicates}")
    print(f"   Validierungsfehler: {total_errors}")
    
    if all_valid:
        print("\n✅ Alle Märkte validiert!")
        sys.exit(0)
    else:
        print("\n❌ Validierung fehlgeschlagen!")
        sys.exit(2)


if __name__ == '__main__':
    main()
