#!/usr/bin/env python3
"""
Extrahiert Bilder aus Aldi Nord Collage und ordnet sie den ersten 12 Rezepten zu.
Das Collage-Bild ist ein 3x4 Grid (12 Rezepte).
"""

import json
import sys
from pathlib import Path
from PIL import Image

# Pfade
PROJECT_ROOT = Path(__file__).parent.parent.parent
COLLAGE_PATH = PROJECT_ROOT / "server" / "media" / "recipe_images" / "aldi_nord" / "images_aldi_nord_0-12.webp"
RECIPES_FILE = PROJECT_ROOT / "assets" / "recipes" / "recipes_aldi_nord.json"
OUTPUT_DIR = PROJECT_ROOT / "server" / "media" / "recipe_images" / "aldi_nord"

def extract_tiles_from_collage():
    """Extrahiert 12 Tiles aus dem Collage (3x4 Grid)"""
    if not COLLAGE_PATH.exists():
        print(f"❌ Collage nicht gefunden: {COLLAGE_PATH}")
        return False
    
    print(f"📷 Lade Collage: {COLLAGE_PATH}")
    collage = Image.open(COLLAGE_PATH)
    
    # Collage-Größe
    width, height = collage.size
    print(f"   Größe: {width}x{height}")
    
    # 3 Zeilen, 4 Spalten = 12 Tiles
    rows = 3
    cols = 4
    
    tile_width = width // cols
    tile_height = height // rows
    
    print(f"   Tile-Größe: {tile_width}x{tile_height}")
    
    # Erstelle Output-Verzeichnis
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    tiles = []
    for row in range(rows):
        for col in range(cols):
            left = col * tile_width
            top = row * tile_height
            right = left + tile_width if col < cols - 1 else width
            bottom = top + tile_height if row < rows - 1 else height
            
            tile = collage.crop((left, top, right, bottom))
            
            # Speichere als WebP
            tile_index = row * cols + col
            output_path = OUTPUT_DIR / f"R{tile_index:03d}.webp"
            tile.save(output_path, format='WEBP', quality=90)
            
            tiles.append(str(output_path.relative_to(PROJECT_ROOT)))
            print(f"   ✓ Tile {tile_index}: {output_path.name}")
    
    return tiles

def update_recipes_with_images(recipe_ids, image_paths):
    """Aktualisiert Rezepte mit heroImageUrl"""
    if not RECIPES_FILE.exists():
        print(f"❌ Rezepte-Datei nicht gefunden: {RECIPES_FILE}")
        return False
    
    print(f"\n📝 Lade Rezepte: {RECIPES_FILE}")
    with open(RECIPES_FILE, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    print(f"   {len(recipes)} Rezepte gefunden")
    
    # Aktualisiere erste 12 Rezepte
    updated_count = 0
    for i, recipe in enumerate(recipes[:12]):
        if i < len(image_paths):
            recipe['heroImageUrl'] = image_paths[i]
            updated_count += 1
            print(f"   ✓ {recipe.get('id', '?')}: {recipe.get('title', '?')[:40]} -> {Path(image_paths[i]).name}")
    
    # Speichere aktualisierte Rezepte
    print(f"\n💾 Speichere aktualisierte Rezepte...")
    with open(RECIPES_FILE, 'w', encoding='utf-8') as f:
        json.dump(recipes, f, indent=2, ensure_ascii=False)
    
    print(f"✅ {updated_count} Rezepte aktualisiert!")
    return True

def main():
    print("🎨 Aldi Nord Bild-Extraktion")
    print("=" * 60)
    
    # Schritt 1: Extrahiere Tiles
    print("\n1️⃣  Extrahiere Tiles aus Collage...")
    image_paths = extract_tiles_from_collage()
    
    if not image_paths:
        print("❌ Fehler beim Extrahieren der Tiles")
        sys.exit(1)
    
    # Schritt 2: Lade Rezepte-IDs
    print("\n2️⃣  Lade Rezepte...")
    with open(RECIPES_FILE, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    recipe_ids = [r.get('id', f'R{i:03d}') for i, r in enumerate(recipes[:12])]
    
    # Schritt 3: Aktualisiere Rezepte
    print("\n3️⃣  Aktualisiere Rezepte mit Bildern...")
    if update_recipes_with_images(recipe_ids, image_paths):
        print("\n✅ Fertig!")
        print(f"   • {len(image_paths)} Bilder extrahiert")
        print(f"   • {len(recipe_ids)} Rezepte aktualisiert")
        print(f"   • Bilder gespeichert in: {OUTPUT_DIR.relative_to(PROJECT_ROOT)}")
    else:
        print("❌ Fehler beim Aktualisieren der Rezepte")
        sys.exit(1)

if __name__ == '__main__':
    main()

