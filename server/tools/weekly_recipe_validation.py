#!/usr/bin/env python3
"""
Wöchentliche Rezept-Validierung
Prüft, ob alle Rezepte für die aktuelle Woche hochgeladen wurden.
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
    
    # ISO Week: Woche beginnt Montag, Woche 1 ist die erste Woche mit mindestens 4 Tagen im Jahr
    iso_calendar = date.isocalendar()
    year = iso_calendar[0]
    week = iso_calendar[1]
    
    return f"{year}-W{week:02d}"

def validate_recipes_for_week(week_key=None):
    """Validiert, ob alle Rezepte für eine Woche vorhanden sind"""
    if week_key is None:
        week_key = get_week_key()
    
    print(f"🔍 Rezept-Validierung für {week_key}")
    print("=" * 60)
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
        
        for file_path in files:
            full_path = PROJECT_ROOT / file_path
            if full_path.exists():
                try:
                    with open(full_path, 'r', encoding='utf-8') as f:
                        recipes = json.load(f)
                        if isinstance(recipes, list):
                            recipe_count = len(recipes)
                            image_count = sum(1 for r in recipes if r.get('heroImageUrl'))
                            found = True
                            break
                except Exception as e:
                    print(f"⚠️  Fehler beim Lesen von {file_path}: {e}")
        
        results[supermarket] = {
            'found': found,
            'recipe_count': recipe_count,
            'image_count': image_count,
            'has_images': image_count > 0
        }
    
    # Zeige Ergebnisse
    print("📊 Ergebnisse:\n")
    total_recipes = 0
    total_images = 0
    missing = []
    
    for supermarket, data in results.items():
        status = "✅" if data['found'] else "❌"
        image_status = "📸" if data['has_images'] else "🖼️"
        
        print(f"{status} {supermarket.upper():15} | Rezepte: {data['recipe_count']:3} | {image_status} Bilder: {data['image_count']:3}")
        
        if data['found']:
            total_recipes += data['recipe_count']
            total_images += data['image_count']
        else:
            missing.append(supermarket)
    
    print()
    print("=" * 60)
    print(f"📈 Zusammenfassung:")
    print(f"   Gesamt Rezepte: {total_recipes}")
    print(f"   Gesamt Bilder:  {total_images}")
    print(f"   Supermärkte:    {len([r for r in results.values() if r['found']])}/{len(supermarkets)}")
    
    if missing:
        print(f"\n⚠️  Fehlende Supermärkte:")
        for m in missing:
            print(f"   • {m}")
    
    # Prüfe Bild-Qualität
    print(f"\n📸 Bild-Status:")
    if total_images > 0:
        coverage = (total_images / total_recipes * 100) if total_recipes > 0 else 0
        print(f"   Bild-Abdeckung: {coverage:.1f}%")
        if coverage < 50:
            print("   ⚠️  Viele Rezepte haben noch keine Bilder!")
    else:
        print("   ❌ Keine Bilder gefunden!")
    
    print()
    
    # Exportiere Report
    report = {
        'week_key': week_key,
        'validated_at': datetime.now().isoformat(),
        'total_recipes': total_recipes,
        'total_images': total_images,
        'supermarkets': results,
        'missing_supermarkets': missing
    }
    
    report_file = PROJECT_ROOT / f"server/tools/recipe_validation_{week_key.replace('-W', '_W')}.json"
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    
    print(f"📄 Report gespeichert: {report_file.name}")
    print()
    
    return report

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Validiert Rezepte für eine Woche')
    parser.add_argument('--week', type=str, help='Wochen-Key (z.B. 2025-W03), Standard: aktuelle Woche')
    args = parser.parse_args()
    
    week_key = args.week or get_week_key()
    validate_recipes_for_week(week_key)

if __name__ == '__main__':
    main()

