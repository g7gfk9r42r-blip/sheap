#!/usr/bin/env python3
"""
Recipe Collage Builder - Erstellt Collagen (Spritesheets) aus Rezeptbildern

Ziel:
- Lädt Rezepte aus JSON
- Stellt sicher, dass jedes Rezept ein Hero-Bild hat
- Erstellt Collagen (Grid) aus den Bildern
- Generiert Manifest für App-Zuordnung

Usage:
    python build_recipe_collages.py --input recipes.json --out-recipes recipes_with_images.json --tile 512 --cols 5 --rows 6
    python build_recipe_collages.py --input recipes.json --limit 12  # Test-Modus
"""

import json
import argparse
import sys
from pathlib import Path
from typing import List, Dict, Optional, Tuple
from PIL import Image, ImageDraw
import re

# Paths
BASE_MEDIA_DIR = Path(__file__).parent.parent / "media" / "media"
RECIPE_IMAGES_DIR = BASE_MEDIA_DIR / "recipe_images"
RECIPE_COLLAGES_DIR = BASE_MEDIA_DIR / "recipe_collages"

# Standard-Werte
DEFAULT_TILE_SIZE = 512
DEFAULT_COLS = 5
DEFAULT_ROWS = 6


def slugify_supermarket(name: str) -> str:
    """Konvertiert Supermarket-Name zu Slug (z.B. 'ALDI Nord' -> 'aldi_nord')"""
    slug = name.lower()
    # Umlaute ersetzen
    slug = slug.replace("ä", "ae").replace("ö", "oe").replace("ü", "ue").replace("ß", "ss")
    # Sonderzeichen/Leerzeichen -> underscore
    slug = re.sub(r'[^a-z0-9]+', '_', slug)
    # Mehrfache underscores entfernen
    slug = re.sub(r'_+', '_', slug)
    return slug.strip('_')


def get_image_path(recipe: Dict, supermarket_slug: str) -> Path:
    """Gibt den deterministischen Pfad für ein Rezept-Bild zurück"""
    recipe_id = recipe.get("id", "")
    if not recipe_id:
        raise ValueError(f"Recipe hat keine ID: {recipe.get('name', 'Unknown')}")
    
    return RECIPE_IMAGES_DIR / supermarket_slug / f"{recipe_id}.webp"


def ensure_hero_image(recipe: Dict, supermarket_slug: str, generate_fn=None) -> Optional[str]:
    """
    Stellt sicher, dass ein Hero-Bild für das Rezept existiert.
    Gibt den relativen Pfad zurück (für heroImageUrl) oder None.
    """
    image_path = get_image_path(recipe, supermarket_slug)
    
    # Wenn bereits existiert, Pfad zurückgeben
    if image_path.exists():
        return f"server/media/media/recipe_images/{supermarket_slug}/{image_path.name}"
    
    # Wenn heroImageUrl bereits gesetzt, aber Datei nicht existiert -> Download?
    existing_url = recipe.get("heroImageUrl")
    if existing_url and "recipe_images" in existing_url:
        # Datei sollte existieren, aber tut es nicht - Warnung
        print(f"  ⚠️  heroImageUrl existiert, aber Datei nicht: {image_path.name}")
        return existing_url
    
    # Generiere Bild (wenn Funktion gegeben)
    if generate_fn:
        try:
            image_path.parent.mkdir(parents=True, exist_ok=True)
            image_bytes = generate_fn(recipe)
            if image_bytes:
                with open(image_path, "wb") as f:
                    f.write(image_bytes)
                print(f"  ✅ Generated image: {image_path.name}")
                return f"server/media/media/recipe_images/{supermarket_slug}/{image_path.name}"
        except Exception as e:
            print(f"  ❌ Error generating image for {recipe.get('id')}: {e}")
            return None
    
    return None


def build_collage(
    recipes: List[Dict],
    supermarket_slug: str,
    tile_size: int = DEFAULT_TILE_SIZE,
    cols: int = DEFAULT_COLS,
    rows: int = DEFAULT_ROWS,
    collage_index: int = 0
) -> Tuple[Image.Image, List[Dict]]:
    """
    Erstellt eine Collage aus Rezeptbildern.
    Gibt zurück: (PIL Image, tiles_info List)
    """
    total_tiles = cols * rows
    tiles_info = []
    
    # Leere Collage erstellen
    collage = Image.new('RGB', (cols * tile_size, rows * tile_size), color=(245, 245, 245))
    
    for idx, recipe in enumerate(recipes[:total_tiles]):
        recipe_id = recipe.get("id", "")
        if not recipe_id:
            continue
        
        # Bild-Pfad
        image_path = get_image_path(recipe, supermarket_slug)
        
        # Position im Grid
        col = idx % cols
        row = idx // cols
        x = col * tile_size
        y = row * tile_size
        
        # Bild laden und auf Tile-Größe skalieren
        if image_path.exists():
            try:
                with Image.open(image_path) as tile_img:
                    # Resize mit Aspect-Ratio (zentriert, mit Padding)
                    tile_img.thumbnail((tile_size, tile_size), Image.Resampling.LANCZOS)
                    
                    # Zentriert auf Tile platzieren
                    paste_x = x + (tile_size - tile_img.width) // 2
                    paste_y = y + (tile_size - tile_img.height) // 2
                    collage.paste(tile_img, (paste_x, paste_y))
                    
                    tiles_info.append({
                        "recipeId": recipe_id,
                        "x": x,
                        "y": y,
                        "w": tile_size,
                        "h": tile_size
                    })
            except Exception as e:
                print(f"  ⚠️  Error loading {image_path.name}: {e}")
                # Neutraler Platzhalter
                draw = ImageDraw.Draw(collage)
                draw.rectangle([x, y, x + tile_size, y + tile_size], fill=(235, 235, 235))
        else:
            # Neutraler Platzhalter
            draw = ImageDraw.Draw(collage)
            draw.rectangle([x, y, x + tile_size, y + tile_size], fill=(235, 235, 235))
    
    # Restliche Tiles mit Platzhalter füllen (falls limit < total_tiles)
    filled_count = len(tiles_info)
    for idx in range(filled_count, total_tiles):
        col = idx % cols
        row = idx // cols
        x = col * tile_size
        y = row * tile_size
        draw = ImageDraw.Draw(collage)
        draw.rectangle([x, y, x + tile_size, y + tile_size], fill=(235, 235, 235))
    
    return collage, tiles_info


def create_manifest(
    all_recipes: List[Dict],
    supermarket_slug: str,
    tile_size: int,
    cols: int,
    rows: int
) -> Dict:
    """Erstellt das Manifest-JSON für Collage-Zuordnung"""
    total_tiles_per_collage = cols * rows
    num_collages = (len(all_recipes) + total_tiles_per_collage - 1) // total_tiles_per_collage
    
    collages = []
    
    for collage_idx in range(num_collages):
        start_idx = collage_idx * total_tiles_per_collage
        end_idx = min(start_idx + total_tiles_per_collage, len(all_recipes))
        collage_recipes = all_recipes[start_idx:end_idx]
        
        collage_filename = f"collage_{collage_idx + 1}.webp"
        recipe_ids = [r.get("id", "") for r in collage_recipes if r.get("id")]
        
        # Tile-Positionen berechnen
        tiles = []
        for idx, recipe in enumerate(collage_recipes):
            recipe_id = recipe.get("id", "")
            if not recipe_id:
                continue
            
            col = idx % cols
            row = idx // cols
            tiles.append({
                "recipeId": recipe_id,
                "x": col * tile_size,
                "y": row * tile_size,
                "w": tile_size,
                "h": tile_size
            })
        
        collages.append({
            "file": collage_filename,
            "index": collage_idx + 1,
            "recipeIds": recipe_ids,
            "tiles": tiles
        })
    
    return {
        "tileWidth": tile_size,
        "tileHeight": tile_size,
        "cols": cols,
        "rows": rows,
        "collages": collages
    }


def main():
    parser = argparse.ArgumentParser(
        description="Build recipe collages from recipe JSON"
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Input JSON file with recipes"
    )
    parser.add_argument(
        "--out-recipes",
        help="Output JSON file for updated recipes (default: <input>_with_images.json)"
    )
    parser.add_argument(
        "--tile",
        type=int,
        default=DEFAULT_TILE_SIZE,
        help=f"Tile size in pixels (default: {DEFAULT_TILE_SIZE})"
    )
    parser.add_argument(
        "--cols",
        type=int,
        default=DEFAULT_COLS,
        help=f"Number of columns in collage (default: {DEFAULT_COLS})"
    )
    parser.add_argument(
        "--rows",
        type=int,
        default=DEFAULT_ROWS,
        help=f"Number of rows in collage (default: {DEFAULT_ROWS})"
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Limit number of recipes to process (for testing)"
    )
    
    args = parser.parse_args()
    
    # Input-Pfad
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"❌ Error: Input file not found: {input_path}")
        sys.exit(1)
    
    # Output-Pfad für Recipes
    if args.out_recipes:
        output_recipes_path = Path(args.out_recipes)
    else:
        output_recipes_path = input_path.parent / f"{input_path.stem}_with_images{input_path.suffix}"
    
    # Rezepte laden
    print(f"📋 Loading recipes from: {input_path}")
    with open(input_path, "r", encoding="utf-8") as f:
        recipes = json.load(f)
    
    if not isinstance(recipes, list):
        print("❌ Error: JSON muss ein Array sein")
        sys.exit(1)
    
    original_count = len(recipes)
    
    # Limit anwenden
    if args.limit:
        recipes = recipes[:args.limit]
        print(f"⚠️  Limiting to {len(recipes)} recipes (of {original_count})")
    
    if not recipes:
        print("❌ Error: Keine Rezepte gefunden")
        sys.exit(1)
    
    # Supermarket bestimmen
    supermarket = recipes[0].get("retailer") or recipes[0].get("supermarket", "")
    if not supermarket:
        print("❌ Error: Kein supermarket/retailer im ersten Rezept gefunden")
        sys.exit(1)
    
    supermarket_slug = slugify_supermarket(supermarket)
    print(f"🏪 Supermarket: {supermarket} -> {supermarket_slug}")
    
    # Verzeichnisse erstellen
    RECIPE_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    RECIPE_COLLAGES_DIR.mkdir(parents=True, exist_ok=True)
    (RECIPE_IMAGES_DIR / supermarket_slug).mkdir(parents=True, exist_ok=True)
    (RECIPE_COLLAGES_DIR / supermarket_slug).mkdir(parents=True, exist_ok=True)
    
    # Hero-Images sicherstellen
    print(f"\n🖼️  Ensuring hero images for {len(recipes)} recipes...")
    updated_recipes = []
    for recipe in recipes:
        hero_url = ensure_hero_image(recipe, supermarket_slug, generate_fn=None)  # Keine Generierung, nur Mapping
        if not hero_url:
            # Wenn kein Bild existiert, trotzdem Pfad setzen (für spätere Generierung)
            image_path = get_image_path(recipe, supermarket_slug)
            hero_url = f"server/media/media/recipe_images/{supermarket_slug}/{image_path.name}"
        
        recipe_copy = recipe.copy()
        recipe_copy["heroImageUrl"] = hero_url
        updated_recipes.append(recipe_copy)
    
    # Updated Recipes JSON schreiben
    print(f"\n💾 Writing updated recipes to: {output_recipes_path}")
    with open(output_recipes_path, "w", encoding="utf-8") as f:
        json.dump(updated_recipes, f, ensure_ascii=False, indent=2)
    print(f"✅ Wrote {len(updated_recipes)} recipes")
    
    # Collagen erstellen
    print(f"\n🎨 Building collages ({args.cols}x{args.rows} = {args.cols*args.rows} tiles per collage)...")
    total_tiles_per_collage = args.cols * args.rows
    num_collages = (len(recipes) + total_tiles_per_collage - 1) // total_tiles_per_collage
    
    for collage_idx in range(num_collages):
        start_idx = collage_idx * total_tiles_per_collage
        end_idx = min(start_idx + total_tiles_per_collage, len(recipes))
        collage_recipes = recipes[start_idx:end_idx]
        
        collage, tiles_info = build_collage(
            collage_recipes,
            supermarket_slug,
            tile_size=args.tile,
            cols=args.cols,
            rows=args.rows,
            collage_index=collage_idx
        )
        
        collage_filename = f"collage_{collage_idx + 1}.webp"
        collage_path = RECIPE_COLLAGES_DIR / supermarket_slug / collage_filename
        
        collage.save(collage_path, "WEBP", quality=85)
        print(f"✅ Wrote {collage_filename} ({len(tiles_info)} tiles)")
    
    # Manifest erstellen
    print(f"\n📝 Creating manifest...")
    manifest = create_manifest(
        recipes,
        supermarket_slug,
        tile_size=args.tile,
        cols=args.cols,
        rows=args.rows
    )
    
    manifest_path = RECIPE_COLLAGES_DIR / supermarket_slug / "collage_manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f"✅ Wrote manifest: {manifest_path}")
    
    # Zusammenfassung
    print(f"\n✅ Complete!")
    print(f"   Recipes processed: {len(recipes)}")
    print(f"   Collages created: {num_collages}")
    print(f"   Manifest: {manifest_path}")
    print(f"\n📁 File structure:")
    print(f"   {RECIPE_IMAGES_DIR / supermarket_slug}/<recipe_id>.webp")
    print(f"   {RECIPE_COLLAGES_DIR / supermarket_slug}/collage_*.webp")
    print(f"   {manifest_path}")


if __name__ == "__main__":
    main()

