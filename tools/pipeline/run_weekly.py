#!/usr/bin/env python3
"""
Weekly Recipe Pipeline - Main Entry Point

Usage:
    python tools/pipeline/run_weekly.py --supermarket aldi_sued \\
        --input server/media/prospekte/aldi_sued/aldi_sued.json \\
        --target-recipes 40 \\
        --with-nutrition
"""

import argparse
import json
import os
import sys
from pathlib import Path

# Add tools to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from pipeline.weekkey import extract_weekkey_from_text, get_current_weekkey
from pipeline.offer_extractor import OfferExtractor
from pipeline.nutrition_enricher import NutritionEnricher
from pipeline.reporting import create_report, save_report

# Try real generator, fallback to mock
try:
    from pipeline.recipe_generator import RecipeGenerator
    USE_MOCK = False
except Exception:
    USE_MOCK = True

if USE_MOCK or not os.getenv('OPENAI_API_KEY'):
    from pipeline.mock_recipe_generator import MockRecipeGenerator as RecipeGenerator
    USE_MOCK = True


def main():
    parser = argparse.ArgumentParser(description="Weekly Recipe Pipeline")
    parser.add_argument('--supermarket', required=True, help="Supermarket name (e.g., aldi_sued)")
    parser.add_argument('--input', required=True, help="Input JSON file path")
    parser.add_argument('--target-recipes', type=int, default=40, help="Target recipe count")
    parser.add_argument('--with-nutrition', action='store_true', help="Enable nutrition enrichment")
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    supermarket = args.supermarket
    
    if not input_path.exists():
        print(f"❌ Input file not found: {input_path}")
        sys.exit(1)
    
    # Determine output directory
    output_dir = input_path.parent
    
    print(f"\n{'='*60}")
    print(f"🚀 WEEKLY RECIPE PIPELINE")
    print(f"{'='*60}")
    print(f"Supermarket: {supermarket}")
    print(f"Input: {input_path}")
    print(f"Target recipes: {args.target_recipes}")
    print(f"Nutrition: {'Yes' if args.with_nutrition else 'No'}")
    print(f"{'='*60}\n")
    
    try:
        # Step 1: Determine week key - read as text first
        with open(input_path, 'r', encoding='utf-8') as f:
            raw_text = f.read()
        
        # Try to parse as JSON, fallback to text
        try:
            raw_data = json.loads(raw_text)
            sample_text = json.dumps(raw_data)[:1000] if not isinstance(raw_data, str) else raw_data[:1000]
        except json.JSONDecodeError:
            # Not valid JSON, use raw text
            raw_data = raw_text
            sample_text = raw_text[:1000]
        
        weekkey = extract_weekkey_from_text(sample_text)
        print(f"📅 Week key: {weekkey}\n")
        
        # Step 2: Extract offers
        print("STEP 1: Extract Offers")
        print("-" * 60)
        extractor = OfferExtractor()
        offers = extractor.extract(input_path, supermarket)
        
        if len(offers) < 5:
            print(f"⚠️  Warning: Only {len(offers)} offers extracted. Continuing anyway...")
        
        # Save offers
        offers_file = output_dir / f"offers_{weekkey}.json"
        with open(offers_file, 'w', encoding='utf-8') as f:
            json.dump(offers, f, ensure_ascii=False, indent=2)
        print(f"💾 Saved offers to {offers_file}\n")
        
        # Step 3: Generate recipes
        print("STEP 2: Generate Recipes")
        print("-" * 60)
        if USE_MOCK:
            print("⚠️  Using mock generator (no OpenAI API key)")
        generator = RecipeGenerator()
        recipes = generator.generate(offers, supermarket, args.target_recipes)
        
        if len(recipes) < args.target_recipes * 0.3:
            print(f"⚠️  Warning: Only {len(recipes)} recipes generated (target: {args.target_recipes})")
        
        # Enrich with offer references
        recipes = generator.enrich_with_offer_refs(recipes, offers)
        
        # Calculate cost ranges
        for recipe in recipes:
            cost_min = 0.0
            cost_max = 0.0
            for ing in recipe.get('ingredients', []):
                if ing.get('availability') == 'offer' and ing.get('offerRefs'):
                    price = ing['offerRefs'][0].get('price', 0)
                    cost_min += price
                    cost_max += price
                elif ing.get('availability') == 'basic' and ing.get('price_range'):
                    pr_min, pr_max = ing['price_range']
                    cost_min += pr_min
                    cost_max += pr_max
            
            recipe['cost_estimate'] = {
                'total_range': [round(cost_min, 2), round(cost_max, 2)],
                'per_serving_range': [
                    round(cost_min / recipe.get('servings', 2), 2),
                    round(cost_max / recipe.get('servings', 2), 2)
                ]
            }
        
        # Step 4: Nutrition enrichment (optional)
        nutrition_stats = {'total_ingredients': 0, 'enriched': 0, 'missing': 0, 'cache_hits': 0}
        
        if args.with_nutrition:
            print("\nSTEP 3: Nutrition Enrichment")
            print("-" * 60)
            cache_dir = Path(__file__).parent.parent.parent / "cache" / "nutrition"
            cache_dir.mkdir(parents=True, exist_ok=True)
            
            enricher = NutritionEnricher(cache_dir)
            recipes = enricher.enrich_recipes(recipes)
            nutrition_stats = enricher.stats
        else:
            # Add placeholder nutrition
            for recipe in recipes:
                if 'nutrition' not in recipe:
                    recipe['nutrition'] = {
                        'kcal_total_range': None,
                        'kcal_per_serving_range': None,
                        'nutrition_source': 'not_calculated',
                        'coverage': {
                            'ingredients_total': len(recipe.get('ingredients', [])),
                            'ingredients_enriched': 0,
                            'ingredients_missing': 0
                        },
                        'disclaimer_short': 'Nährwerte nicht berechnet.'
                    }
        
        # Save recipes
        recipes_file = output_dir / f"recipes_{weekkey}.json"
        with open(recipes_file, 'w', encoding='utf-8') as f:
            json.dump(recipes, f, ensure_ascii=False, indent=2)
        print(f"\n💾 Saved recipes to {recipes_file}\n")
        
        # Step 5: Create report
        print("STEP 4: Generate Report")
        print("-" * 60)
        report = create_report(
            weekkey=weekkey,
            supermarket=supermarket,
            offers_count=len(offers),
            recipes_count=len(recipes),
            nutrition_stats=nutrition_stats,
            output_dir=output_dir
        )
        
        report_file = output_dir / f"run_{weekkey}.report.json"
        save_report(report, report_file)
        print(f"💾 Saved report to {report_file}\n")
        
        # Final summary
        print(f"{'='*60}")
        print(f"✅ PIPELINE COMPLETE")
        print(f"{'='*60}")
        print(f"Week: {weekkey}")
        print(f"Offers extracted: {len(offers)}")
        print(f"Recipes generated: {len(recipes)}")
        if args.with_nutrition:
            coverage = nutrition_stats.get('enriched', 0) / max(nutrition_stats.get('total_ingredients', 1), 1) * 100
            print(f"Nutrition coverage: {coverage:.1f}%")
        print(f"\nOutput files:")
        print(f"  - {offers_file}")
        print(f"  - {recipes_file}")
        print(f"  - {report_file}")
        print(f"{'='*60}\n")
        
        sys.exit(0)
    
    except Exception as e:
        print(f"\n{'='*60}")
        print(f"❌ PIPELINE FAILED")
        print(f"{'='*60}")
        print(f"Error: {e}")
        print(f"{'='*60}\n")
        
        import traceback
        traceback.print_exc()
        
        sys.exit(1)


if __name__ == '__main__':
    main()

