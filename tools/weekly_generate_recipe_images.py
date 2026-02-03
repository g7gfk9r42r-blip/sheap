#!/usr/bin/env python3
"""
Wöchentliche Recipe-Image-Generierung
Nur ausgeführt wenn alle 12 Supermärkte erkannt wurden

Usage:
    python tools/weekly_generate_recipe_images.py
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, List, Optional

# Erwartete Markets (Globus entfernt)
EXPECTED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'biomarkt',
    'kaufland', 'lidl', 'nahkauf', 'netto',
    'norma', 'penny', 'rewe', 'tegut'
}

# Projekt-Root
PROJECT_ROOT = Path(__file__).parent.parent
PROSPEKTE_DIR = PROJECT_ROOT / "assets" / "prospekte"
IMAGES_DIR = PROJECT_ROOT / "assets" / "images"


def check_all_markets_present() -> tuple[bool, set[str]]:
    """
    Prüft ob alle 12 Markets vorhanden sind
    
    Returns:
        (success: bool, found_markets: set[str])
    """
    found_markets = set()
    
    if not PROSPEKTE_DIR.exists():
        print(f"❌ FEHLER: Prospekte-Verzeichnis nicht gefunden: {PROSPEKTE_DIR}")
        return False, found_markets
    
    for market_dir in PROSPEKTE_DIR.iterdir():
        if not market_dir.is_dir():
            continue
        
        market = market_dir.name
        
        # Prüfe ob *_recipes.json oder <market>.json existiert
        recipes_file = market_dir / f"{market}_recipes.json"
        fallback_file = market_dir / f"{market}.json"
        
        if recipes_file.exists() or fallback_file.exists():
            found_markets.add(market)
    
    if found_markets != EXPECTED_MARKETS:
        missing = EXPECTED_MARKETS - found_markets
        extra = found_markets - EXPECTED_MARKETS
        
        print(f"\n❌ FEHLER: Nicht alle erwarteten Supermärkte erkannt!")
        print(f"   Gefunden: {len(found_markets)} Markets")
        print(f"   Erwartet: {len(EXPECTED_MARKETS)} Markets")
        
        if missing:
            print(f"\n   ❌ Fehlend ({len(missing)}):")
            for m in sorted(missing):
                print(f"      - {m}")
        
        if extra:
            print(f"\n   ⚠️  Überschüssig ({len(extra)}):")
            for m in sorted(extra):
                print(f"      - {m}")
        
        print(f"\n   ✅ Gefunden ({len(found_markets)}):")
        for m in sorted(found_markets):
            print(f"      - {m}")
        
        return False, found_markets
    
    print(f"\n✅ Alle erwarteten Supermärkte erkannt!")
    print(f"   Markets: {', '.join(sorted(found_markets))}")
    return True, found_markets


def load_all_recipes() -> Dict[str, List[dict]]:
    """
    Lädt alle Rezepte gruppiert nach Market
    
    Returns:
        Dict[market: str, recipes: List[dict]]
    """
    recipes_by_market = {}
    
    for market_dir in PROSPEKTE_DIR.iterdir():
        if not market_dir.is_dir():
            continue
        
        market = market_dir.name
        
        # Versuche *_recipes.json zuerst
        recipes_file = market_dir / f"{market}_recipes.json"
        if not recipes_file.exists():
            recipes_file = market_dir / f"{market}.json"
        
        if not recipes_file.exists():
            continue
        
        try:
            with open(recipes_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Handle verschiedene JSON-Strukturen
            if isinstance(data, list):
                recipes = data
            elif isinstance(data, dict):
                recipes = data.get('recipes', data.get('items', data.get('offers', [])))
            else:
                recipes = []
            
            recipes_by_market[market] = recipes
            print(f"   ✅ {market}: {len(recipes)} Rezepte")
            
        except Exception as e:
            print(f"   ❌ Fehler beim Laden von {market}: {e}")
            recipes_by_market[market] = []
    
    return recipes_by_market


def validate_recipe_id(recipe_id: str) -> bool:
    """
    Validiert Recipe-ID Format: R### (z.B. R001, R023)
    
    Args:
        recipe_id: Recipe-ID String
        
    Returns:
        True wenn gültig
    """
    if not recipe_id:
        return False
    
    recipe_id = recipe_id.strip()
    
    # Format: R### (R gefolgt von 3 Ziffern)
    if len(recipe_id) != 4:
        return False
    
    if not recipe_id.startswith('R'):
        return False
    
    if not recipe_id[1:].isdigit():
        return False
    
    return True


def get_image_prompt(recipe: dict) -> str:
    """
    Extrahiert oder generiert Image-Prompt aus Rezept
    
    Args:
        recipe: Rezept-Dict
        
    Returns:
        Image-Prompt String
    """
    # Versuche image_prompt Feld
    if recipe.get('image_prompt'):
        return recipe['image_prompt']
    
    # Generiere aus title + description
    title = recipe.get('title', '')
    description = recipe.get('description', '')
    
    if title and description:
        return f"{title} - {description}"
    elif title:
        return title
    elif description:
        return description
    else:
        return "Appetitliches Rezept-Gericht"


def generate_image(image_prompt: str, market: str, recipe_id: str) -> Optional[bytes]:
    """
    Generiert Bild für ein Rezept
    
    Args:
        image_prompt: Prompt für Bild-Generierung
        market: Market-Name
        recipe_id: Recipe-ID
        
    Returns:
        Bild-Daten als bytes, oder None bei Fehler
        
    NOTE: Diese Funktion muss mit der tatsächlichen Bild-Generierungs-API
          implementiert werden (z.B. DALL-E, Stable Diffusion, etc.)
    """
    # TODO: Implementiere Bild-Generierung
    # Beispiel mit Replicate API (siehe server/tools/generate_recipe_images.py)
    
    print(f"      ⚠️  Bild-Generierung noch nicht implementiert für {market}_{recipe_id}")
    print(f"         Prompt: {image_prompt[:60]}...")
    
    return None


def save_recipe_image(market: str, recipe_id: str, image_data: bytes) -> Path:
    """
    Speichert Bild mit exaktem Dateinamen
    
    Args:
        market: Market-Name (z.B. "aldi_sued")
        recipe_id: Recipe-ID (z.B. "R023")
        image_data: Bild-Daten als bytes
        
    Returns:
        Path zur gespeicherten Datei
    """
    # Stelle sicher dass images-Verzeichnis existiert
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    
    # Dateiname: <market>_<recipeId>.png
    filename = f"{market}_{recipe_id}.png"
    filepath = IMAGES_DIR / filename
    
    with open(filepath, 'wb') as f:
        f.write(image_data)
    
    return filepath


def validate_all_images(recipes_by_market: Dict[str, List[dict]]) -> List[str]:
    """
    Prüft ob jedes Rezept genau ein Bild hat
    
    Args:
        recipes_by_market: Rezepte gruppiert nach Market
        
    Returns:
        Liste fehlender Bild-Dateinamen
    """
    missing_images = []
    
    for market, recipes in recipes_by_market.items():
        for recipe in recipes:
            recipe_id = recipe.get('id', '').strip()
            
            if not validate_recipe_id(recipe_id):
                continue
            
            filename = f"{market}_{recipe_id}.png"
            filepath = IMAGES_DIR / filename
            
            if not filepath.exists():
                missing_images.append(filename)
    
    return missing_images


def main():
    """Hauptfunktion"""
    print("=" * 70)
    print("🖼️  WÖCHENTLICHE RECIPE-IMAGE-GENERIERUNG")
    print("=" * 70)
    
    # Schritt 1: Prüfe ob alle 12 Markets vorhanden sind
    print("\n📋 Schritt 1: Prüfe alle 12 Supermärkte...")
    success, found_markets = check_all_markets_present()
    
    if not success:
        print("\n" + "=" * 70)
        print("❌ ABBRUCH: Prompt wird NICHT ausgeführt!")
        print("=" * 70)
        print("\n💡 Tipp: Stelle sicher dass alle 12 Markets vorhanden sind:")
        for market in sorted(EXPECTED_MARKETS):
            print(f"   - {market}")
        sys.exit(1)
    
    # Schritt 2: Lade alle Rezepte
    print("\n📋 Schritt 2: Lade alle Rezepte...")
    recipes_by_market = load_all_recipes()
    
    total_recipes = sum(len(recipes) for recipes in recipes_by_market.values())
    print(f"\n   📊 Gesamt: {total_recipes} Rezepte in {len(recipes_by_market)} Markets")
    
    if total_recipes == 0:
        print("\n❌ FEHLER: Keine Rezepte gefunden!")
        sys.exit(1)
    
    # Schritt 3: Generiere Bilder
    print("\n📋 Schritt 3: Generiere Bilder...")
    print("   ⚠️  HINWEIS: Bild-Generierung muss noch implementiert werden!")
    print("   📝 Siehe: server/tools/generate_recipe_images.py für Beispiel")
    
    generated = 0
    skipped = 0
    failed = []
    
    for market, recipes in recipes_by_market.items():
        print(f"\n   🖼️  {market.upper()} ({len(recipes)} Rezepte)...")
        
        for recipe in recipes:
            recipe_id = recipe.get('id', '').strip()
            
            # Validiere Recipe-ID Format (R###)
            if not validate_recipe_id(recipe_id):
                print(f"      ⚠️  Überspringe ungültige ID: '{recipe_id}'")
                skipped += 1
                failed.append(f"{market}_{recipe_id}")
                continue
            
            # Prüfe ob Bild bereits existiert
            filename = f"{market}_{recipe_id}.png"
            filepath = IMAGES_DIR / filename
            
            if filepath.exists():
                print(f"      ⏭️  Überspringe (existiert bereits): {filename}")
                continue
            
            try:
                # Extrahiere Image-Prompt
                image_prompt = get_image_prompt(recipe)
                
                # Generiere Bild
                image_data = generate_image(image_prompt, market, recipe_id)
                
                if image_data is None:
                    print(f"      ⚠️  Bild-Generierung nicht implementiert: {filename}")
                    failed.append(f"{market}_{recipe_id}")
                    continue
                
                # Speichere
                saved_path = save_recipe_image(market, recipe_id, image_data)
                print(f"      ✅ {saved_path.name}")
                generated += 1
                
            except Exception as e:
                print(f"      ❌ Fehler bei {filename}: {e}")
                failed.append(f"{market}_{recipe_id}")
    
    # Schritt 4: Validierung
    print("\n📋 Schritt 4: Validierung...")
    missing_images = validate_all_images(recipes_by_market)
    
    # Report
    print("\n" + "=" * 70)
    print("📊 ZUSAMMENFASSUNG")
    print("=" * 70)
    print(f"✅ Generiert: {generated} Bilder")
    print(f"⏭️  Übersprungen (existieren bereits): {total_recipes - generated - len(missing_images) - skipped} Bilder")
    print(f"⚠️  Übersprungen (ungültige ID): {skipped} Rezepte")
    if failed:
        print(f"❌ Fehlgeschlagen: {len(failed)} Rezepte")
        if len(failed) <= 20:
            for f in failed:
                print(f"   - {f}.png")
        else:
            for f in failed[:10]:
                print(f"   - {f}.png")
            print(f"   ... und {len(failed) - 10} weitere")
    
    if missing_images:
        print(f"\n⚠️  Fehlend: {len(missing_images)} Bilder")
        if len(missing_images) <= 20:
            for m in missing_images:
                print(f"   - {m}")
        else:
            for m in missing_images[:10]:
                print(f"   - {m}")
            print(f"   ... und {len(missing_images) - 10} weitere")
    else:
        print(f"\n✅ Alle {total_recipes} Rezepte haben Bilder!")
    
    print("=" * 70)
    
    # Exit-Code
    if missing_images or failed:
        print("\n⚠️  WARNUNG: Nicht alle Bilder konnten generiert werden!")
        sys.exit(1)
    else:
        print("\n✅ ERFOLG: Alle Bilder erfolgreich generiert!")
        sys.exit(0)


if __name__ == "__main__":
    main()

