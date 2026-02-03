#!/usr/bin/env python3
"""
Offline Asset Builder (OFFLINE MODE)
- NUR canonical recipe files: assets/recipes/recipes_<market>.json
- NUR 12 erlaubte Markets
- NUR Recipe IDs R001-R999
"""

import json
import shutil
import re
import argparse
from pathlib import Path
from typing import Dict, List, Set, Optional
from collections import defaultdict
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_RECIPES_DIR = PROJECT_ROOT / 'assets' / 'recipes'
ASSETS_IMAGES_DIR = PROJECT_ROOT / 'assets' / 'recipe_images'
ASSETS_INDEX_DIR = PROJECT_ROOT / 'assets' / 'index'
ASSETS_FALLBACK_DIR = ASSETS_IMAGES_DIR / '_fallback'
BUILD_REPORT = PROJECT_ROOT / 'tools' / 'build_report.md'

# HART: Nur diese 12 Markets sind erlaubt
ALLOWED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'lidl', 'rewe', 'edeka', 'kaufland',
    'netto', 'penny', 'norma', 'biomarkt', 'tegut'
}


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


def normalize_market_slug(market: str) -> Optional[str]:
    """Normalisiert Market-Name zu erlaubtem Slug"""
    market = market.lower().strip()
    
    # Direkte Mappings
    mappings = {
        'aldi nord': 'aldi_nord',
        'aldi nörd': 'aldi_nord',
        'aldi süd': 'aldi_sued',
        'aldi sued': 'aldi_sued',
    }
    
    if market in mappings:
        return mappings[market]
    
    market = market.replace(' ', '_').replace('-', '_')
    
    # Prüfe ob erlaubt
    if market in ALLOWED_MARKETS:
        return market
    
    return None


def extract_recipe_ids_from_canonical(market_slug: str) -> Set[str]:
    """Extrahiert Recipe-IDs aus canonical file (nur R001-R999)"""
    if market_slug not in ALLOWED_MARKETS:
        return set()
    
    json_file = ASSETS_RECIPES_DIR / f'recipes_{market_slug}.json'
    
    if not json_file.exists():
        return set()
    
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            recipes = data if isinstance(data, list) else [data]
        
        recipe_ids = set()
        for recipe in recipes:
            rid = recipe.get('id', '')
            if rid:
                normalized = normalize_recipe_id(rid)
                # NUR valide IDs
                if normalized:
                    recipe_ids.add(normalized)
        
        return recipe_ids
    except Exception as e:
        print(f"  ⚠️  Fehler beim Lesen {json_file.name}: {e}")
        return set()


def find_existing_image_ids(market_slug: str) -> Set[str]:
    """Findet vorhandene Bild-IDs (nur R###.webp, 1-999)"""
    if market_slug not in ALLOWED_MARKETS:
        return set()
    
    market_dir = ASSETS_IMAGES_DIR / market_slug
    
    if not market_dir.exists():
        return set()
    
    image_ids = set()
    for img_file in market_dir.glob('*.webp'):
        if img_file.name == 'placeholder.webp':
            continue
        
        # Extrahiere ID (nur R###.webp)
        recipe_id = normalize_recipe_id(img_file.stem)
        if recipe_id:
            image_ids.add(recipe_id)
    
    return image_ids


def find_image_sources() -> Dict[str, List[Path]]:
    """Findet Bild-Quellen (nur für ALLOWED_MARKETS, nur R###.webp)"""
    sources_by_market = defaultdict(list)
    
    source_dirs = [
        ASSETS_IMAGES_DIR,
        PROJECT_ROOT / 'server' / 'media' / 'recipe_images',
    ]
    
    for source_dir in source_dirs:
        if not source_dir.exists():
            continue
        
        for img_file in source_dir.rglob('*.webp'):
            if img_file.name == 'placeholder.webp':
                continue
            
            # Extrahiere Market aus Pfad (nur erlaubte Markets)
            parts = img_file.parts
            market = None
            
            for i, part in enumerate(parts):
                if part in ['recipe_images', 'media'] and i + 1 < len(parts):
                    potential_market = parts[i + 1]
                    # Prüfe direkt in ALLOWED_MARKETS oder normalisiere
                    normalized = normalize_market_slug(potential_market)
                    if normalized and normalized in ALLOWED_MARKETS:
                        market = normalized
                        break
            
            if market:
                sources_by_market[market].append(img_file)
    
    return dict(sources_by_market)


def copy_and_normalize_images(market_slug: str, sources: List[Path]) -> Set[str]:
    """Kopiert und normalisiert Bilder (nur R###.webp, 1-999)"""
    if market_slug not in ALLOWED_MARKETS:
        return set()
    
    market_dir = ASSETS_IMAGES_DIR / market_slug
    market_dir.mkdir(parents=True, exist_ok=True)
    
    copied_ids = set()
    
    for source in sources:
        # Extrahiere ID aus Dateinamen
        filename = source.stem
        recipe_id = normalize_recipe_id(filename)
        
        # NUR valide R### IDs (1-999)
        if not recipe_id:
            continue
        
        target = market_dir / f'{recipe_id}.webp'
        
        try:
            if not target.exists() or source.stat().st_mtime > target.stat().st_mtime:
                shutil.copy2(source, target)
            copied_ids.add(recipe_id)
        except Exception as e:
            print(f"    ⚠️  Fehler beim Kopieren {source.name}: {e}")
    
    return copied_ids


def fill_missing_placeholders(market_slug: str, missing_ids: Set[str]):
    """Kopiert Placeholder NUR für valide R### IDs (1-999)"""
    if market_slug not in ALLOWED_MARKETS:
        return
    
    market_dir = ASSETS_IMAGES_DIR / market_slug
    market_dir.mkdir(parents=True, exist_ok=True)
    
    placeholder = ASSETS_FALLBACK_DIR / 'placeholder.webp'
    if not placeholder.exists():
        print(f"    ⚠️  Placeholder nicht gefunden: {placeholder}")
        return
    
    for recipe_id in missing_ids:
        # NUR valide R### IDs
        if not recipe_id or not re.match(r'^R\d{3}$', recipe_id):
            continue
        
        # Extrahiere Zahl und prüfe 1-999
        match = re.match(r'R(\d+)', recipe_id)
        if match:
            num = int(match.group(1))
            if not (1 <= num <= 999):
                continue
        
        target = market_dir / f'{recipe_id}.webp'
        if not target.exists():
            try:
                shutil.copy2(placeholder, target)
                print(f"    ✅ Placeholder kopiert: {recipe_id}.webp")
            except Exception as e:
                print(f"    ❌ Fehler beim Kopieren Placeholder {recipe_id}.webp: {e}")


def build_asset_index(fill_placeholders: bool = False) -> Dict:
    """Baut Asset-Index (nur canonical files, nur ALLOWED_MARKETS)"""
    print("\n📋 Baue Asset-Index (canonical files only)...")
    
    # Finde canonical recipe files
    print("\n1️⃣ Prüfe canonical recipe files...")
    canonical_markets = []
    for market in sorted(ALLOWED_MARKETS):
        canonical_file = ASSETS_RECIPES_DIR / f'recipes_{market}.json'
        if canonical_file.exists():
            canonical_markets.append(market)
            print(f"  ✅ {market}: canonical file vorhanden")
        else:
            print(f"  ⚠️  {market}: canonical file fehlt")
    
    if not canonical_markets:
        print("\n❌ Keine canonical recipe files gefunden!")
        return {
            'generated_at': datetime.now().isoformat(),
            'recipes': {},
            'images': {},
            'missing_images': {},
        }
    
    # Kopiere und normalisiere Bilder
    print("\n2️⃣ Kopiere Rezept-Bilder...")
    image_sources = find_image_sources()
    for market in canonical_markets:
        if market in image_sources:
            copied = copy_and_normalize_images(market, image_sources[market])
            print(f"  ✅ {market}: {len(copied)} Bilder kopiert")
        else:
            print(f"  ⚠️  {market}: Keine Bilder gefunden")
    
    # Baue Index
    index = {
        'generated_at': datetime.now().isoformat(),
        'recipes': {},
        'images': {},
        'missing_images': {},
    }
    
    for market in canonical_markets:
        # Recipe-IDs (nur valide, aus canonical file)
        recipe_ids = extract_recipe_ids_from_canonical(market)
        
        # Image-IDs (nur valide)
        image_ids = find_existing_image_ids(market)
        
        # Missing Images
        missing_ids = recipe_ids - image_ids
        
        index['recipes'][market] = {
            'count': len(recipe_ids),
            'ids': sorted(list(recipe_ids)),
        }
        
        index['images'][market] = {
            'count': len(image_ids),
            'ids': sorted(list(image_ids)),
        }
        
        if missing_ids:
            index['missing_images'][market] = sorted(list(missing_ids))
            
            # Fülle Placeholder NUR für valide IDs
            if fill_placeholders:
                fill_missing_placeholders(market, missing_ids)
    
    return index


def generate_report(index: Dict):
    """Generiert Build-Report"""
    print("\n📄 Generiere Build-Report...")
    
    lines = [
        "# Build Report: Offline Assets",
        "",
        f"Generated: {index['generated_at']}",
        "",
        "## Summary",
        "",
    ]
    
    total_recipes = sum(m['count'] for m in index['recipes'].values())
    total_images = sum(m['count'] for m in index['images'].values())
    total_missing = sum(len(ids) for ids in index['missing_images'].values())
    
    lines.append(f"- **Total Recipes**: {total_recipes}")
    lines.append(f"- **Total Images**: {total_images}")
    lines.append(f"- **Total Missing Images**: {total_missing}")
    lines.append(f"- **Markets**: {len(index['recipes'])} (nur erlaubte: {', '.join(sorted(ALLOWED_MARKETS))})")
    lines.append("")
    lines.append("## Per Market")
    lines.append("")
    
    for market in sorted(index['recipes'].keys()):
        recipe_data = index['recipes'][market]
        image_data = index['images'][market]
        missing = index['missing_images'].get(market, [])
        
        lines.append(f"### {market}")
        lines.append(f"- **recipes_count**: {recipe_data['count']}")
        lines.append(f"- **images_count**: {image_data['count']}")
        lines.append(f"- **missing_images_count**: {len(missing)}")
        
        if missing:
            missing_list = missing[:20]
            lines.append(f"- **missing_images**: {missing_list}")
            if len(missing) > 20:
                lines.append(f"  ... and {len(missing) - 20} more")
        
        lines.append("")
    
    BUILD_REPORT.write_text('\n'.join(lines), encoding='utf-8')
    print(f"✅ Report geschrieben: {BUILD_REPORT.relative_to(PROJECT_ROOT)}")


def main():
    parser = argparse.ArgumentParser(description='Baut Offline-Assets (nur canonical files)')
    parser.add_argument('--fill-missing-with-placeholder', action='store_true',
                       help='Kopiert Placeholder für fehlende Bilder (nur R001-R999)')
    parser.add_argument('--only-allowed-markets', action='store_true',
                       help='Nur erlaubte Markets verarbeiten')
    args = parser.parse_args()
    
    print("🔨 Build Offline Assets (OFFLINE MODE)")
    print("=" * 60)
    print(f"Erlaubte Markets: {', '.join(sorted(ALLOWED_MARKETS))}")
    print(f"Recipe IDs: R001-R999 (1-999)")
    print("Canonical files only: assets/recipes/recipes_<market>.json")
    print("=" * 60)
    
    # Baue Index
    index = build_asset_index(fill_placeholders=args.fill_missing_with_placeholder)
    
    if not index['recipes']:
        print("\n❌ Keine Rezepte gefunden!")
        sys.exit(1)
    
    # Speichere Index
    ASSETS_INDEX_DIR.mkdir(parents=True, exist_ok=True)
    index_file = ASSETS_INDEX_DIR / 'asset_index.json'
    index_file.write_text(json.dumps(index, indent=2, ensure_ascii=False), encoding='utf-8')
    print(f"\n✅ Asset-Index geschrieben: {index_file.relative_to(PROJECT_ROOT)}")
    
    # Generiere Report
    generate_report(index)
    
    print("\n" + "=" * 60)
    print("✅ Build abgeschlossen!")
    
    # Terminal-Ausgabe
    print("\n📋 Per Market:")
    for market in sorted(index['recipes'].keys()):
        recipe_count = index['recipes'][market]['count']
        image_count = index['images'][market]['count']
        missing_count = len(index['missing_images'].get(market, []))
        print(f"   {market}: recipes={recipe_count} images={image_count} missing_images={missing_count}")


if __name__ == '__main__':
    import sys
    main()
