#!/usr/bin/env python3
"""
Konvertiert Aldi Nord Rezepte auf das neue Format (wie Nahkauf)
und stellt sicher, dass alle Felder korrekt sind.
"""

import json
import sys
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent.parent
INPUT_FILE = PROJECT_ROOT / "assets/recipes/recipes_aldi_nord.json"
OUTPUT_FILE = PROJECT_ROOT / "assets/recipes/recipes_aldi_nord.json"

def get_current_week_key():
    """Berechnet ISO-Wochen-Schlüssel"""
    date = datetime.now()
    iso_calendar = date.isocalendar()
    year = iso_calendar[0]
    week = iso_calendar[1]
    return f"{year}-W{week:02d}"

def convert_recipe_to_new_format(old_recipe):
    """Konvertiert ein Rezept vom alten Format zum neuen Format"""
    new_recipe = {
        "id": old_recipe.get("id", ""),
        "title": old_recipe.get("title", ""),
        "retailer": old_recipe.get("retailer") or old_recipe.get("supermarket", "ALDI NORD"),
        "week_key": old_recipe.get("week_key") or get_current_week_key(),
        "servings": old_recipe.get("servings") or old_recipe.get("portions", 2),
        "durationMinutes": old_recipe.get("durationMinutes") or old_recipe.get("duration_minutes") or 30,
        "categories": old_recipe.get("categories", []),
        "dietary_flags": old_recipe.get("dietary_flags", {}),
        "base_ingredients": old_recipe.get("base_ingredients", [
            "Salz", "Pfeffer", "Öl", "Wasser"
        ]),
    }
    
    # Konvertiere ingredients
    ingredients = []
    base_ingredients_set = set([bi.lower() for bi in new_recipe["base_ingredients"]])
    
    if "ingredients" in old_recipe and isinstance(old_recipe["ingredients"], list):
        for ing in old_recipe["ingredients"]:
            if isinstance(ing, str):
                # Einfache String-Zutat (wahrscheinlich Basis-Zutat)
                ing_lower = ing.lower()
                if any(base in ing_lower for base in base_ingredients_set):
                    # Ist Basis-Zutat, nicht hinzufügen
                    continue
                # Sonst als normale Zutat hinzufügen
                ingredients.append({
                    "from_offer": False,
                    "name": ing,
                })
            elif isinstance(ing, dict):
                # Objekt-Zutat - konvertiere vom alten zum neuen Format
                new_ing = {}
                
                # from_offer
                new_ing["from_offer"] = ing.get("from_offer", False) or bool(ing.get("offerId") or ing.get("offer_id"))
                
                # offer_id
                new_ing["offer_id"] = ing.get("offer_id") or ing.get("offerId", "")
                
                # name
                new_ing["name"] = ing.get("name") or ing.get("offerName", "")
                
                # brand
                if ing.get("brand"):
                    new_ing["brand"] = ing.get("brand")
                
                # Preise
                new_ing["price_eur"] = ing.get("price_eur") or ing.get("priceEur") or ing.get("priceOffer") or ing.get("price")
                if ing.get("price_before_eur") or ing.get("priceBeforeEur") or ing.get("priceRegular"):
                    new_ing["price_before_eur"] = ing.get("price_before_eur") or ing.get("priceBeforeEur") or ing.get("priceRegular")
                
                # Menge und Unit
                if ing.get("amount"):
                    amount_str = str(ing.get("amount", ""))
                    # Versuche Menge und Unit zu extrahieren
                    import re
                    match = re.match(r'(\d+(?:[.,]\d+)?)\s*(\w+)', amount_str)
                    if match:
                        new_ing["used_amount"] = float(match.group(1).replace(',', '.'))
                        new_ing["unit"] = match.group(2)
                elif ing.get("used_amount"):
                    new_ing["used_amount"] = ing.get("used_amount")
                    new_ing["unit"] = ing.get("unit", "")
                
                # pack_size
                if ing.get("packSize"):
                    pack_size_str = str(ing.get("packSize", ""))
                    match = re.match(r'(\d+(?:[.,]\d+)?)\s*(\w+)', pack_size_str)
                    if match:
                        new_ing["pack_size"] = float(match.group(1).replace(',', '.'))
                        new_ing["unit"] = match.group(2)
                elif ing.get("pack_size"):
                    new_ing["pack_size"] = ing.get("pack_size")
                
                # packs_used
                if ing.get("quantityPacks") or ing.get("quantity_packs"):
                    new_ing["packs_used"] = ing.get("quantityPacks") or ing.get("quantity_packs", 1)
                else:
                    new_ing["packs_used"] = 1
                
                ingredients.append(new_ing)
    
    new_recipe["ingredients"] = ingredients
    
    # Konvertiere steps/instructions
    if "steps" in old_recipe:
        new_recipe["steps"] = old_recipe["steps"]
    elif "instructions" in old_recipe:
        new_recipe["steps"] = old_recipe["instructions"]
    else:
        new_recipe["steps"] = []
    
    # Preise
    if old_recipe.get("price_total_eur") or old_recipe.get("cost_total_offer_eur"):
        new_recipe["price_total_eur"] = old_recipe.get("price_total_eur") or old_recipe.get("cost_total_offer_eur")
    if old_recipe.get("price_total_before_eur") or old_recipe.get("cost_total_regular_eur"):
        new_recipe["price_total_before_eur"] = old_recipe.get("price_total_before_eur") or old_recipe.get("cost_total_regular_eur")
    if old_recipe.get("savings_eur"):
        new_recipe["savings_eur"] = old_recipe.get("savings_eur")
    
    # notes
    if old_recipe.get("notes"):
        new_recipe["notes"] = old_recipe["notes"]
    
    # heroImageUrl - WICHTIG: Behalte das Format, das bereits gesetzt ist
    if old_recipe.get("heroImageUrl"):
        new_recipe["heroImageUrl"] = old_recipe["heroImageUrl"]
    
    # Entferne leere Felder
    return {k: v for k, v in new_recipe.items() if v is not None and v != ""}

def main():
    print("🔄 Konvertiere Aldi Nord Rezepte auf neues Format...")
    print("=" * 60)
    
    if not INPUT_FILE.exists():
        print(f"❌ Datei nicht gefunden: {INPUT_FILE}")
        sys.exit(1)
    
    # Lade alte Rezepte
    print(f"📖 Lade Rezepte von: {INPUT_FILE.name}")
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        old_recipes = json.load(f)
    
    print(f"   {len(old_recipes)} Rezepte gefunden")
    print()
    
    # Konvertiere alle Rezepte
    print("🔄 Konvertiere Rezepte...")
    new_recipes = []
    for i, old_recipe in enumerate(old_recipes, 1):
        try:
            new_recipe = convert_recipe_to_new_format(old_recipe)
            new_recipes.append(new_recipe)
            
            # Zeige Fortschritt für erste 3 Rezepte
            if i <= 3:
                print(f"   ✓ {new_recipe['id']}: {new_recipe['title']}")
                print(f"     → Retailer: {new_recipe.get('retailer')}")
                print(f"     → Ingredients: {len(new_recipe.get('ingredients', []))}")
                print(f"     → Steps: {len(new_recipe.get('steps', []))}")
                if new_recipe.get('heroImageUrl'):
                    print(f"     → Bild: {new_recipe['heroImageUrl']}")
        except Exception as e:
            print(f"   ⚠️  Fehler bei Rezept {i}: {e}")
            continue
    
    print(f"\n✅ {len(new_recipes)} Rezepte konvertiert")
    print()
    
    # Speichere neue Rezepte
    print(f"💾 Speichere konvertierte Rezepte...")
    
    # Backup erstellen
    backup_file = INPUT_FILE.parent / f"{INPUT_FILE.stem}_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        backup_content = f.read()
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(backup_content)
    print(f"   📦 Backup erstellt: {backup_file.name}")
    
    # Speichere neue Rezepte
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        json.dump(new_recipes, f, indent=2, ensure_ascii=False)
    
    print(f"   ✅ Gespeichert in: {OUTPUT_FILE.name}")
    print()
    
    # Zeige Zusammenfassung
    print("📊 Zusammenfassung:")
    print(f"   Rezepte: {len(new_recipes)}")
    
    recipes_with_images = sum(1 for r in new_recipes if r.get('heroImageUrl'))
    print(f"   Mit Bildern: {recipes_with_images}/{len(new_recipes)}")
    
    recipes_with_prices = sum(1 for r in new_recipes if r.get('price_total_eur'))
    print(f"   Mit Preisen: {recipes_with_prices}/{len(new_recipes)}")
    
    print()
    print("✅ Fertig!")

if __name__ == '__main__':
    main()

