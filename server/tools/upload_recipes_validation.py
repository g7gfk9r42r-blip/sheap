#!/usr/bin/env python3
"""
Wöchentliche Rezept-Upload-Validierung
Prüft, ob alle Rezepte für die Woche hochgeladen wurden und erstellt einen Report.
"""

import json
import sys
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).parent.parent.parent

def get_week_key(date=None):
    """Berechnet ISO-Wochen-Schlüssel (z.B. '2025-W03')"""
    if date is None:
        date = datetime.now()
    
    iso_calendar = date.isocalendar()
    year = iso_calendar[0]
    week = iso_calendar[1]
    
    return f"{year}-W{week:02d}"

def validate_all_recipes():
    """Validiert alle Rezepte und erstellt einen Upload-Report"""
    current_week = get_week_key()
    
    print("🔍 Rezept-Upload-Validierung")
    print("=" * 60)
    print(f"📅 Aktuelle Woche: {current_week}")
    print()
    
    # Definiere Supermärkte
    supermarkets = [
        'kaufland', 'lidl', 'rewe', 'aldi_nord', 'aldi_sued',
        'netto', 'penny', 'norma', 'nahkauf', 'tegut', 'biomarkt'
    ]
    
    # Datei-Mappings
    file_mappings = {
        'aldi_nord': ['assets/recipes/recipes_aldi_nord.json'],
        'aldi_sued': ['assets/recipes/recipes_aldi_sued.json'],
        'kaufland': ['assets/recipes/recipes_kaufland.json'],
        'lidl': ['assets/recipes/recipes_lidl.json'],
        'rewe': ['assets/recipes/recipes_rewe.json'],
        'netto': ['assets/recipes/recipes_netto.json'],
        'penny': ['assets/recipes/recipes_penny.json'],
        'norma': ['assets/recipes/recipes_norma.json'],
        'nahkauf': ['assets/recipes/recipes_nahkauf.json'],
        'tegut': ['assets/recipes/recipes_tegut.json'],
        'biomarkt': ['assets/recipes/recipes_biomarkt.json'],
    }
    
    results = {}
    
    for supermarket in supermarkets:
        files = file_mappings.get(supermarket, [])
        found = False
        recipe_count = 0
        image_count = 0
        recipes_with_prices = 0
        recipes_with_ingredients = 0
        
        for file_path in files:
            full_path = PROJECT_ROOT / file_path
            if full_path.exists():
                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        recipes = json.load(f)
                        if isinstance(recipes, list):
                            recipe_count = len(recipes)
                            
                            for recipe in recipes:
                                # Prüfe Bilder
                                if recipe.get('heroImageUrl'):
                                    image_count += 1
                                
                                # Prüfe Preise
                                if recipe.get('price_total_eur') or recipe.get('cost_total_offer_eur'):
                                    recipes_with_prices += 1
                                
                                # Prüfe Zutaten
                                if recipe.get('ingredients') and len(recipe.get('ingredients', [])) > 0:
                                    recipes_with_ingredients += 1
                            
                            found = True
                            break
                except Exception as e:
                    print(f"⚠️  Fehler beim Lesen von {file_path}: {e}")
        
        results[supermarket] = {
            'found': found,
            'recipe_count': recipe_count,
            'image_count': image_count,
            'has_images': image_count > 0,
            'recipes_with_prices': recipes_with_prices,
            'recipes_with_ingredients': recipes_with_ingredients,
            'completeness': {
                'images': (image_count / recipe_count * 100) if recipe_count > 0 else 0,
                'prices': (recipes_with_prices / recipe_count * 100) if recipe_count > 0 else 0,
                'ingredients': (recipes_with_ingredients / recipe_count * 100) if recipe_count > 0 else 0,
            }
        }
    
    # Zeige Ergebnisse
    print("📊 Ergebnisse:\n")
    total_recipes = 0
    total_images = 0
    missing = []
    incomplete = []
    
    for supermarket, data in results.items():
        status = "✅" if data['found'] and data['recipe_count'] > 0 else "❌"
        image_status = "📸" if data['has_images'] else "🖼️"
        
        if data['found']:
            completeness = data['completeness']
            completeness_icon = "🟢" if completeness['images'] > 50 and completeness['prices'] > 80 else "🟡"
            
            print(f"{status} {supermarket.upper():15} | Rezepte: {data['recipe_count']:3} | {image_status} Bilder: {data['image_count']:3} | {completeness_icon} Vollständig: {completeness['images']:.0f}%")
            
            if data['recipe_count'] > 0:
                total_recipes += data['recipe_count']
                total_images += data['image_count']
                
                if completeness['images'] < 50 or completeness['prices'] < 80:
                    issues = []
                    if completeness['images'] < 50:
                        issues.append(f"Bilder: {completeness['images']:.0f}%")
                    if completeness['prices'] < 80:
                        issues.append(f"Preise: {completeness['prices']:.0f}%")
                    incomplete.append({
                        'supermarket': supermarket,
                        'issues': issues
                    })
        else:
            missing.append(supermarket)
            print(f"{status} {supermarket.upper():15} | Rezepte:   0 | ❌ NICHT GEFUNDEN")
    
    print()
    print("=" * 60)
    print(f"📈 Zusammenfassung:")
    print(f"   Gesamt Rezepte: {total_recipes}")
    print(f"   Gesamt Bilder:  {total_images}")
    print(f"   Supermärkte:    {len([r for r in results.values() if r['found']])}/{len(supermarkets)}")
    
    if missing:
        print(f"\n❌ Fehlende Supermärkte:")
        for m in missing:
            print(f"   • {m}")
    
    if incomplete:
        print(f"\n⚠️  Unvollständige Supermärkte:")
        for item in incomplete:
            print(f"   • {item['supermarket']}: {', '.join(item['issues'])}")
    
    # Prüfe Bild-Qualität
    print(f"\n📸 Bild-Status:")
    if total_images > 0:
        coverage = (total_images / total_recipes * 100) if total_recipes > 0 else 0
        print(f"   Bild-Abdeckung: {coverage:.1f}%")
        if coverage < 50:
            print("   ⚠️  Viele Rezepte haben noch keine Bilder!")
            print("   💡 Verwende: python3 server/tools/extract_aldi_nord_images.py")
    else:
        print("   ❌ Keine Bilder gefunden!")
    
    # Upload-Status
    print(f"\n✅ Upload-Status für {current_week}:")
    if total_recipes > 0:
        upload_complete = len(missing) == 0 and len(incomplete) == 0
        if upload_complete:
            print("   ✅ Alle Rezepte sind vollständig hochgeladen!")
        else:
            print("   ⚠️  Einige Rezepte sind noch unvollständig")
            print("   💡 Prüfe die obige Liste für Details")
    else:
        print("   ❌ Keine Rezepte gefunden!")
        print("   💡 Stelle sicher, dass alle Rezept-Dateien in assets/recipes/ vorhanden sind")
    
    print()
    
    # Exportiere Report
    report = {
        'week_key': current_week,
        'validated_at': datetime.now().isoformat(),
        'total_recipes': total_recipes,
        'total_images': total_images,
        'supermarkets': results,
        'missing_supermarkets': missing,
        'incomplete_supermarkets': incomplete,
        'upload_complete': len(missing) == 0 and len(incomplete) == 0,
    }
    
    report_file = PROJECT_ROOT / f"server/tools/upload_validation_{current_week.replace('-W', '_W')}.json"
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"📄 Report gespeichert: {report_file.name}")
    print()
    
    return report

if __name__ == '__main__':
    validate_all_recipes()

