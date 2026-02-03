#!/usr/bin/env python3
"""
Generiere Bilder für Rezepte basierend auf Titel und Zutaten.

Optionen:
1. OpenAI DALL-E (benötigt OPENAI_API_KEY)
2. Unsplash API (kostenlos, benötigt API Key)
3. Placeholder/Food-APIs (kostenlos, keine API Key nötig)
"""

import json
import os
import sys
import time
from pathlib import Path
from typing import Optional

# Option 1: DALL-E (OpenAI)
try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False

# Option 2: Unsplash
try:
    import requests
    REQUESTS_AVAILABLE = True
except ImportError:
    REQUESTS_AVAILABLE = False


def generate_image_with_dalle(recipe_title: str, ingredients: list, api_key: str) -> Optional[str]:
    """Generiere Bild mit DALL-E 3"""
    if not OPENAI_AVAILABLE:
        return None
    
    try:
        client = OpenAI(api_key=api_key)
        
        # Erstelle einen beschreibenden Prompt
        # Extrahiere Hauptzutat aus Ingredients
        main_ingredients = [ing for ing in ingredients[:5] if ing and len(ing) > 2]
        ingredients_text = ", ".join(main_ingredients) if main_ingredients else "fresh ingredients"
        
        # Verbessere Titel falls generisch
        title_clean = recipe_title.replace("Einfach", "").replace("Klassisch", "").replace("Schnell", "").strip()
        if not title_clean or len(title_clean) < 3:
            # Fallback: Nutze Hauptzutat
            title_clean = main_ingredients[0] if main_ingredients else "delicious dish"
        
        # Erstelle detaillierten Prompt für DALL-E
        prompt = (
            f"A beautiful, professional food photography of {title_clean}. "
            f"The dish includes {ingredients_text}. "
            f"Appetizing presentation on a white plate, bright natural lighting, "
            f"high quality food photography, restaurant style, vibrant colors, "
            f"sharp focus, shallow depth of field."
        )
        
        # Kürze Prompt falls zu lang (DALL-E Limit: 4000 Zeichen)
        if len(prompt) > 1000:
            prompt = prompt[:1000]
        
        response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            size="1024x1024",
            quality="standard",
            n=1,
        )
        
        return response.data[0].url
    except Exception as e:
        print(f"  ⚠️  DALL-E Error: {e}")
        return None


def generate_image_with_unsplash(recipe_title: str, api_key: Optional[str] = None) -> Optional[str]:
    """Finde passendes Food-Bild auf Unsplash"""
    if not REQUESTS_AVAILABLE:
        return None
    
    try:
        # Erstelle Suchbegriff aus Rezept-Titel
        search_query = recipe_title.lower().replace(" ", ",")
        
        if api_key:
            # Mit API Key: bessere Ergebnisse
            url = "https://api.unsplash.com/search/photos"
            headers = {"Authorization": f"Client-ID {api_key}"}
            params = {
                "query": search_query,
                "per_page": 1,
                "orientation": "squarish",
            }
        else:
            # Ohne API Key: verwende Unsplash Source (einfacher, aber weniger genau)
            # Für jetzt: Placeholder verwenden
            return None
        
        response = requests.get(url, headers=headers, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("results") and len(data["results"]) > 0:
                return data["results"][0]["urls"]["regular"]
        
        return None
    except Exception as e:
        print(f"  ⚠️  Unsplash Error: {e}")
        return None


def generate_image_with_unsplash_free(recipe_title: str, ingredients: list) -> Optional[str]:
    """Nutze Unsplash Source API (kostenlos, KEIN API Key nötig)"""
    if not REQUESTS_AVAILABLE:
        return None
    
    try:
        # Erstelle Suchbegriff aus Titel und Hauptzutaten
        search_terms = [recipe_title]
        for ing in ingredients[:2]:  # Max 2 Zutaten für Suchbegriff
            if isinstance(ing, dict):
                ing_name = ing.get('name', '')
            else:
                ing_name = str(ing)
            if ing_name and len(ing_name) > 3:
                search_terms.append(ing_name)
        
        # Nutze Unsplash Source (kostenlos, kein API Key)
        # Format: https://source.unsplash.com/featured/800x800/?keyword1,keyword2
        keywords = ",".join([term.replace(" ", ",") for term in search_terms[:3]])
        url = f"https://source.unsplash.com/featured/800x800/?{keywords},food"
        
        # Teste ob URL erreichbar ist
        response = requests.head(url, timeout=10, allow_redirects=True)
        if response.status_code == 200 or response.status_code == 302:
            return url
        
        return None
    except Exception as e:
        return None


def generate_image_with_foodish(recipe_title: str, ingredients: list) -> Optional[str]:
    """Nutze Foodish API (kostenlos, keine API Key nötig)"""
    if not REQUESTS_AVAILABLE:
        return None
    
    try:
        # Erweiterte Kategorien-Map
        categories_map = {
            "burger": ["burger", "hamburger", "fleisch", "meat"],
            "pizza": ["pizza"],
            "pasta": ["pasta", "spaghetti", "nudel", "fusilli", "penne", "risotto"],
            "rice": ["reis", "rice", "biryani"],
            "chicken": ["hühn", "chicken", "hähnchen", "poulet"],
            "dessert": ["dessert", "eis", "kuchen", "torte", "süß", "sweet"],
            "salad": ["salat", "salad"],
            "soup": ["suppe", "soup"],
            "bread": ["brot", "bread", "toast"],
        }
        
        # Prüfe Titel und Zutaten
        search_text = recipe_title.lower()
        for ing in ingredients[:3]:
            if isinstance(ing, dict):
                search_text += " " + ing.get('name', '').lower()
            else:
                search_text += " " + str(ing).lower()
        
        category = None
        for cat, keywords in categories_map.items():
            if any(keyword in search_text for keyword in keywords):
                category = cat
                break
        
        # Foodish API scheint nicht mehr zuverlässig zu funktionieren
        # Nutze Unsplash Source als Alternative (kostenlos, kein API Key)
        import random
        search_terms = []
        
        if category:
            search_terms.append(category)
        
        # Füge Hauptzutaten hinzu
        for ing in ingredients[:2]:
            if isinstance(ing, dict):
                ing_name = ing.get('name', '').lower()
            else:
                ing_name = str(ing).lower()
            if ing_name and len(ing_name) > 3:
                search_terms.append(ing_name)
        
        # Erstelle Unsplash Source URL (kostenlos, kein API Key)
        keywords = ",".join(search_terms[:3]) if search_terms else "food"
        url = f"https://source.unsplash.com/featured/800x800/?{keywords},food,meal"
        return url
    except Exception as e:
        return None


def generate_image_url_for_recipe(
    recipe_title: str,
    ingredients: list,
    openai_key: Optional[str] = None,
    unsplash_key: Optional[str] = None,
    method: str = "auto"
) -> Optional[str]:
    """
    Generiere eine Bild-URL für ein Rezept.
    
    Args:
        recipe_title: Titel des Rezepts
        ingredients: Liste von Zutaten (Strings oder Dicts mit 'name')
        openai_key: OpenAI API Key (optional)
        unsplash_key: Unsplash API Key (optional)
        method: "dalle", "unsplash", "foodish", oder "auto"
    
    Returns:
        Bild-URL oder None
    """
    # Extrahiere Zutaten-Namen
    ingredient_names = []
    for ing in ingredients[:5]:  # Erste 5 Zutaten
        if isinstance(ing, dict):
            ingredient_names.append(ing.get("name", ""))
        elif isinstance(ing, str):
            ingredient_names.append(ing)
    
    ingredient_names = [i for i in ingredient_names if i]
    
    # Wähle Methode
    if method == "auto":
        # Priorität für kostenlose Version: Foodish (zuverlässig)
        method = "foodish"
    
    # Generiere Bild
    if method == "dalle" and openai_key:
        return generate_image_with_dalle(recipe_title, ingredient_names, openai_key)
    elif method == "unsplash" and unsplash_key:
        return generate_image_with_unsplash(recipe_title, unsplash_key)
    elif method == "unsplash_free":
        return generate_image_with_unsplash_free(recipe_title, ingredient_names)
    elif method == "foodish":
        return generate_image_with_foodish(recipe_title, ingredient_names)
    
    return None


def add_images_to_recipes(
    recipes_file: Path,
    openai_key: Optional[str] = None,
    unsplash_key: Optional[str] = None,
    method: str = "auto",
    skip_existing: bool = True
):
    """Füge heroImageUrl zu allen Rezepten hinzu"""
    print(f"\n📝 Verarbeite: {recipes_file.name}")
    
    with open(recipes_file, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    updated = 0
    skipped = 0
    errors = 0
    start_time = time.time()
    
    for i, recipe in enumerate(recipes, 1):
        recipe_id = recipe.get('id', 'unknown')
        recipe_title = recipe.get('title') or recipe.get('shortTitle', 'Unknown Recipe')
        
        # Überspringe wenn bereits vorhanden
        if skip_existing and recipe.get('heroImageUrl'):
            skipped += 1
            continue
        
        # Extrahiere Zutaten
        ingredients = recipe.get('ingredients', [])
        
        # Generiere Bild-URL
        try:
            image_url = generate_image_url_for_recipe(
                recipe_title,
                ingredients,
                openai_key=openai_key,
                unsplash_key=unsplash_key,
                method=method
            )
            
            if image_url:
                recipe['heroImageUrl'] = image_url
                updated += 1
                elapsed = time.time() - start_time
                avg_time = elapsed / i
                remaining = (len(recipes) - i) * avg_time
                print(f"  ✅ [{i}/{len(recipes)}] {recipe_title[:40]:<40} → Bild generiert | ~{int(remaining/60)}min verbleibend")
            else:
                errors += 1
                elapsed = time.time() - start_time
                avg_time = elapsed / i if i > 0 else 0
                remaining = (len(recipes) - i) * avg_time
                print(f"  ⚠️  [{i}/{len(recipes)}] {recipe_title[:40]:<40} → Kein Bild | ~{int(remaining/60)}min verbleibend")
            
            # Rate limiting (besonders für DALL-E wichtig)
            # DALL-E 3 hat natürliche Rate Limits, keine zusätzliche Pause nötig
            if method == "unsplash":
                time.sleep(0.5)
                
        except Exception as e:
            errors += 1
            print(f"  ❌ [{i}/{len(recipes)}] {recipe_title[:40]:<40} → Error: {e}")
    
    # Speichere aktualisierte Rezepte
    if updated > 0:
        with open(recipes_file, 'w', encoding='utf-8') as f:
            json.dump(recipes, f, indent=2, ensure_ascii=False)
        print(f"  💾 {updated} Rezepte aktualisiert, {skipped} übersprungen, {errors} Fehler")
    else:
        print(f"  ℹ️  Keine Updates ({skipped} bereits vorhanden, {errors} Fehler)")


def main():
    """Hauptfunktion"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Generiere Bilder für Rezepte")
    parser.add_argument(
        "--method",
        choices=["dalle", "unsplash", "unsplash_free", "foodish", "auto"],
        default="auto",
        help="Bild-Generierungs-Methode (default: auto = kostenlos)"
    )
    parser.add_argument(
        "--openai-key",
        help="OpenAI API Key für DALL-E",
        default=os.environ.get("OPENAI_API_KEY")
    )
    parser.add_argument(
        "--unsplash-key",
        help="Unsplash API Key",
        default=os.environ.get("UNSPLASH_ACCESS_KEY")
    )
    parser.add_argument(
        "--recipes-dir",
        type=Path,
        default=Path("assets/recipes"),
        help="Verzeichnis mit Rezept-JSON-Dateien"
    )
    parser.add_argument(
        "--file",
        type=Path,
        help="Nur eine spezifische Datei verarbeiten"
    )
    parser.add_argument(
        "--skip-existing",
        action="store_true",
        default=True,
        help="Überspringe Rezepte mit bereits vorhandenen Bildern"
    )
    
    args = parser.parse_args()
    
    # Prüfe Verfügbarkeit
    print("=" * 70)
    print("🍽️  REZEPT-BILD GENERIERUNG")
    print("=" * 70)
    print()
    
    if args.method == "dalle" or (args.method == "auto" and args.openai_key):
        if not OPENAI_AVAILABLE:
            print("❌ OpenAI-Paket nicht installiert. Installiere mit: pip install openai")
            sys.exit(1)
        if not args.openai_key:
            print("⚠️  Kein OpenAI API Key gefunden. Nutze --openai-key oder setze OPENAI_API_KEY")
    
    if args.method == "unsplash" and not REQUESTS_AVAILABLE:
        print("⚠️  Requests-Paket nicht installiert. Installiere mit: pip install requests")
    
    print(f"📁 Verzeichnis: {args.recipes_dir}")
    print(f"🔧 Methode: {args.method}")
    print()
    
    # Finde Rezept-Dateien
    if args.file:
        recipe_files = [args.file] if args.file.exists() else []
    else:
        recipe_files = list(args.recipes_dir.glob("recipes_*.json"))
    
    if not recipe_files:
        print(f"❌ Keine Rezept-Dateien gefunden in {args.recipes_dir}")
        sys.exit(1)
    
    print(f"📊 {len(recipe_files)} Dateien gefunden")
    print()
    
    # Verarbeite alle Dateien
    total_updated = 0
    for recipe_file in recipe_files:
        add_images_to_recipes(
            recipe_file,
            openai_key=args.openai_key,
            unsplash_key=args.unsplash_key,
            method=args.method,
            skip_existing=args.skip_existing
        )
        total_updated += 1
    
    print()
    print("=" * 70)
    print(f"✅ ABGESCHLOSSEN: {total_updated} Dateien verarbeitet")
    print("=" * 70)


if __name__ == '__main__':
    main()
