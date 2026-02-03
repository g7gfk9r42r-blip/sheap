#!/usr/bin/env python3
"""
Flatten Recipe Images Structure

Verschiebt Bilder von:
  assets/images/recipes/<market>/R001.png
  
Zu:
  assets/images/recipes/<market>_R001.png

Aktualisiert auch image_path in allen Recipe JSON-Dateien.
"""

import json
import shutil
from pathlib import Path
from typing import List, Tuple

# Bestimme Projekt-Root automatisch
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent

def find_all_recipes() -> List[Tuple[str, Path]]:
    """Findet alle Recipe JSON-Dateien (in assets/prospekte/) oder Märkte mit Bildern"""
    prospekte_dir = PROJECT_ROOT / 'assets' / 'prospekte'
    images_dir = PROJECT_ROOT / 'assets' / 'images'
    
    if not prospekte_dir.exists():
        print(f"❌ Verzeichnis nicht gefunden: {prospekte_dir}")
        return []
    
    recipes = []
    markets_with_images = set()
    
    # Finde Märkte mit JSON-Dateien
    for market_dir in prospekte_dir.iterdir():
        if not market_dir.is_dir():
            continue
        
        market_name = market_dir.name
        json_file = market_dir / f"{market_name}_recipes.json"
        if json_file.exists():
            recipes.append((market_name, json_file))
            markets_with_images.add(market_name)
    
    # Finde Märkte mit Bildern (auch ohne JSON-Datei)
    if images_dir.exists():
        for image_subdir in images_dir.iterdir():
            if not image_subdir.is_dir():
                continue
            
            market_name = image_subdir.name
            if market_name == 'recipes':  # Überspringe das Ziel-Verzeichnis
                continue
            
            # Prüfe ob Bilder vorhanden sind
            images = list(image_subdir.glob('*.png'))
            if images and market_name not in markets_with_images:
                # Markt hat Bilder, aber keine JSON-Datei - trotzdem hinzufügen
                # Verwende None für JSON-Pfad (wird nur für Bilder verwendet)
                recipes.append((market_name, None))
    
    return recipes

def flatten_images(market: str, dry_run: bool = False) -> Tuple[int, int]:
    """
    Flacht Bilder für einen Markt:
    assets/images/<market>/R001.png -> assets/images/recipes/<market>_R001.png
    
    Returns: (moved_count, error_count)
    """
    source_dir = PROJECT_ROOT / 'assets' / 'images' / market
    target_dir = PROJECT_ROOT / 'assets' / 'images' / 'recipes'
    
    # Erstelle Ziel-Verzeichnis falls nicht vorhanden
    if not dry_run:
        target_dir.mkdir(parents=True, exist_ok=True)
    
    if not source_dir.exists():
        return 0, 0
    
    moved_count = 0
    error_count = 0
    
    for image_file in source_dir.glob('*.png'):
        if not image_file.is_file():
            continue
        
        # Neuer Dateiname: <market>_R001.png
        new_name = f"{market}_{image_file.name}"
        target_path = target_dir / new_name
        
        if target_path.exists():
            # Überspringe wenn identisch (gleiche Größe)
            source_size = image_file.stat().st_size
            target_size = target_path.stat().st_size
            if source_size == target_size:
                if dry_run:
                    print(f"   📝 Würde überspringen (identisch): {new_name}")
                continue
            elif not dry_run:
                print(f"   ⚠️  Überschreibe: {new_name}")
        
        try:
            if not dry_run:
                shutil.move(str(image_file), str(target_path))
            moved_count += 1
            if dry_run:
                print(f"   📝 Würde verschieben: {image_file.name} -> {new_name}")
        except Exception as e:
            print(f"   ❌ Fehler beim Verschieben {image_file.name}: {e}")
            error_count += 1
    
    # Lösche leeren Source-Ordner
    if not dry_run and source_dir.exists():
        try:
            if not any(source_dir.iterdir()):
                source_dir.rmdir()
                print(f"   🗑️  Leeren Ordner gelöscht: {source_dir.name}")
        except Exception:
            pass
    
    return moved_count, error_count

def update_recipe_json(market: str, json_path: Path, dry_run: bool = False) -> int:
    """
    Aktualisiert image_path in Recipe JSON:
    assets/images/recipes/<market>/R001.png -> assets/images/recipes/<market>_R001.png
    """
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        recipes = data if isinstance(data, list) else data.get('recipes', [])
        updated_count = 0
        
        for recipe in recipes:
            old_path = recipe.get('image_path')
            if not old_path or not isinstance(old_path, str):
                continue
            
            # Alte Strukturen erkennen:
            # 1. assets/images/<market>/R001.png (aktuell)
            # 2. assets/images/recipes/<market>/R001.png (falls vorhanden)
            if f'/images/{market}/' in old_path or f'/recipes/{market}/' in old_path:
                recipe_id = recipe.get('id', '')
                new_path = f'assets/images/recipes/{market}_{recipe_id}.png'
                
                if old_path != new_path:
                    recipe['image_path'] = new_path
                    updated_count += 1
                    if dry_run:
                        print(f"      {recipe_id}: {old_path.split('/')[-1]} -> {new_path.split('/')[-1]}")
        
        if updated_count > 0 and not dry_run:
            # Backup erstellen
            backup_path = json_path.with_suffix('.json.backup')
            if not backup_path.exists():
                shutil.copy2(json_path, backup_path)
            
            # Speichere aktualisierte JSON
            with open(json_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        
        return updated_count
    
    except Exception as e:
        print(f"   ❌ Fehler beim Aktualisieren {json_path}: {e}")
        return 0

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Flatten recipe images structure')
    parser.add_argument('--dry-run', action='store_true', help='Nur anzeigen, keine Änderungen')
    parser.add_argument('--market', help='Nur diesen Markt verarbeiten')
    args = parser.parse_args()
    
    print("🔄 Flatten Recipe Images Structure")
    print("=" * 60)
    print()
    
    if args.dry_run:
        print("⚠️  DRY-RUN MODUS: Keine Änderungen werden durchgeführt")
        print()
    
    recipes = find_all_recipes()
    
    if args.market:
        recipes = [(m, p) for m, p in recipes if m == args.market]
        if not recipes:
            print(f"❌ Markt '{args.market}' nicht gefunden!")
            return
    
    print(f"📋 Gefundene Märkte: {len(recipes)}")
    print()
    
    total_moved = 0
    total_updated = 0
    total_errors = 0
    
    for market, json_path in sorted(recipes):
        print(f"📦 Verarbeite {market}...")
        
        # Bilder verschieben
        moved, errors = flatten_images(market, dry_run=args.dry_run)
        total_moved += moved
        total_errors += errors
        
        if moved > 0 or errors > 0:
            print(f"   📸 Bilder: {moved} verschoben, {errors} Fehler")
        
        # JSON aktualisieren (nur wenn JSON-Datei vorhanden)
        if json_path is not None:
            updated = update_recipe_json(market, json_path, dry_run=args.dry_run)
            total_updated += updated
            
            if updated > 0:
                print(f"   📝 JSON: {updated} image_path aktualisiert")
        else:
            print(f"   ⚠️  Keine JSON-Datei gefunden (nur Bilder verschoben)")
        
        print()
    
    print("=" * 60)
    print(f"✅ Zusammenfassung:")
    print(f"   📸 Bilder verschoben: {total_moved}")
    print(f"   📝 JSON-Dateien aktualisiert: {total_updated}")
    if total_errors > 0:
        print(f"   ❌ Fehler: {total_errors}")
    
    if args.dry_run:
        print()
        print("💡 Führe ohne --dry-run aus, um die Änderungen durchzuführen")

if __name__ == '__main__':
    main()
