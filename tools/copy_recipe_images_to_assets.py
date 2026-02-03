#!/usr/bin/env python3
"""
Kopiert Rezept-Bilder von server/media/recipe_images/ nach assets/recipe_images/
Struktur: assets/recipe_images/<retailer>/<week_key>/<id>.webp
Unterstützt verschiedene Dateinamen-Konventionen
"""
import json
import shutil
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
SOURCE_DIR = PROJECT_ROOT / "server" / "media" / "recipe_images"
TARGET_DIR = PROJECT_ROOT / "assets" / "recipe_images"

# Retailer-Mapping
RETAILER_MAPPING = {
    "aldi_nord": ["aldi_nord"],
    "aldi_sued": ["aldi_sued"],
    "biomarkt": ["biomarkt"],
    "kaufland": ["kaufland"],
    "lidl": ["lidl"],
    "rewe": ["rewe"],
    "netto": ["netto"],
    "penny": ["penny"],
    "norma": ["norma"],
    "nahkauf": ["nahkauf"],
    "tegut": ["tegut"],
}

def load_recipes_json(retailer_slug: str) -> list:
    """Lädt Rezepte-JSON für einen Retailer"""
    recipe_files = [
        PROJECT_ROOT / "server" / "media" / "prospekte" / retailer_slug / "_recipes.json",
        PROJECT_ROOT / "server" / "media" / "prospekte" / retailer_slug / f"{retailer_slug}_recipes.json",
        PROJECT_ROOT / "server" / "media" / "prospekte" / retailer_slug / f"{retailer_slug}.json",
        PROJECT_ROOT / "assets" / "recipes" / f"recipes_{retailer_slug}.json",
    ]
    
    for recipe_file in recipe_files:
        if recipe_file.exists():
            try:
                with open(recipe_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        return data
                    elif isinstance(data, dict) and "recipes" in data:
                        return data["recipes"]
                    return []
            except Exception as e:
                print(f"⚠️  Fehler beim Laden von {recipe_file}: {e}")
                continue
    return []

def normalize_id(recipe_id: str) -> str:
    """Normalisiert Recipe-ID für Matching (z.B. 'R001' -> 'r001', '001')"""
    return recipe_id.upper().strip()

def find_image_file(retailer_slug: str, recipe_id: str) -> Path | None:
    """Findet Bild-Datei für ein Rezept (verschiedene Namenskonventionen)"""
    retailer_dir = SOURCE_DIR / retailer_slug
    if not retailer_dir.exists():
        return None
    
    normalized_id = normalize_id(recipe_id)
    
    # Suche nach verschiedenen Namenskonventionen
    patterns = [
        f"{recipe_id}.webp",           # Exakt: R001.webp
        f"{normalized_id}.webp",       # R001.webp (upper)
        f"{recipe_id.lower()}.webp",   # r001.webp (lower)
        f"{retailer_slug}-{recipe_id}.webp",  # aldi_nord-R001.webp
        f"{retailer_slug}-{normalized_id}.webp",
        f"{retailer_slug}-{recipe_id.lower()}.webp",
    ]
    
    # Entferne Präfix aus ID für weitere Suche (z.B. "R001" -> "001")
    id_without_prefix = re.sub(r'^[A-Z]+', '', normalized_id, count=1) if re.match(r'^[A-Z]+\d+', normalized_id) else normalized_id
    if id_without_prefix != normalized_id:
        patterns.extend([
            f"{id_without_prefix}.webp",
            f"{retailer_slug}-{id_without_prefix}.webp",
        ])
    
    # Prüfe alle Patterns
    for pattern in patterns:
        path = retailer_dir / pattern
        if path.exists():
            return path
    
    # Suche in allen Bildern nach ID in Dateiname
    for img_path in retailer_dir.glob("*.webp"):
        img_stem = img_path.stem.lower()
        recipe_id_lower = recipe_id.lower()
        normalized_id_lower = normalized_id.lower()
        
        # Prüfe ob ID im Dateinamen vorkommt
        if recipe_id_lower in img_stem or normalized_id_lower in img_stem:
            # Entferne Retailer-Präfix und prüfe Match
            clean_stem = re.sub(r'^[a-z_]+-', '', img_stem, flags=re.I)
            if clean_stem == normalized_id_lower or clean_stem == recipe_id_lower:
                return img_path
    
    return None

def copy_images_for_retailer(retailer_slug: str):
    """Kopiert alle Bilder für einen Retailer"""
    recipes = load_recipes_json(retailer_slug)
    if not recipes:
        print(f"⚠️  Keine Rezepte für {retailer_slug} gefunden")
        return
    
    print(f"\n📦 {retailer_slug}: {len(recipes)} Rezepte")
    
    copied = 0
    missing = 0
    
    # Lade alle verfügbaren Bilder
    retailer_dir = SOURCE_DIR / retailer_slug
    available_images = {}
    if retailer_dir.exists():
        for img_path in retailer_dir.glob("*.webp"):
            img_stem = img_path.stem.lower()
            # Extrahiere mögliche IDs aus Dateiname
            # z.B. "aldi_sued-r058" -> "R058", "r058", "058"
            parts = re.split(r'[-_]', img_stem)
            for part in parts:
                # Prüfe ob Teil wie eine ID aussieht (z.B. r001, R001, 001)
                if re.match(r'^[a-z]?\d+$', part, re.I):
                    normalized = part.upper()
                    if normalized not in available_images:
                        available_images[normalized] = []
                    available_images[normalized].append(img_path)
    
    for recipe in recipes:
        recipe_id = recipe.get('id', '').strip()
        week_key = recipe.get('weekKey') or recipe.get('week_key') or 'unknown'
        
        if not recipe_id:
            continue
        
        # Finde Bild
        source_image = find_image_file(retailer_slug, recipe_id)
        
        if not source_image:
            # Versuche auch mit available_images zu matchen
            normalized_id = normalize_id(recipe_id)
            if normalized_id in available_images:
                source_image = available_images[normalized_id][0]
            elif recipe_id.upper() in available_images:
                source_image = available_images[recipe_id.upper()][0]
        
        if not source_image:
            missing += 1
            continue
        
        # Ziel-Pfad: assets/recipe_images/<retailer>/<week_key>/<id>.webp
        target_dir = TARGET_DIR / retailer_slug / week_key
        target_dir.mkdir(parents=True, exist_ok=True)
        target_path = target_dir / f"{recipe_id}.webp"
        
        # Kopiere Bild
        try:
            shutil.copy2(source_image, target_path)
            copied += 1
            if copied <= 5:  # Zeige erste 5
                print(f"  ✅ {recipe_id} → {target_path.relative_to(PROJECT_ROOT)}")
        except Exception as e:
            print(f"  ❌ Fehler beim Kopieren von {recipe_id}: {e}")
            missing += 1
    
    print(f"  📊 Kopiert: {copied}, Fehlend: {missing}")

def main():
    print("🖼️  Kopiere Rezept-Bilder nach assets/recipe_images/")
    print("=" * 60)
    
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    
    # Alle Retailer durchgehen
    for retailer_slug in RETAILER_MAPPING.keys():
        copy_images_for_retailer(retailer_slug)
    
    print("\n✅ Abgeschlossen!")

if __name__ == "__main__":
    main()
