#!/usr/bin/env python3
"""
Nutrition Enrichment Pipeline

Scans recipe JSONs and adds nutritional data (calories, macros) using:
- Open Food Facts API (branded/packaged foods)
- USDA FoodData Central API (generic foods)

Usage:
    python tools/enrich_nutrition.py --root ./server/media/prospekte
    python tools/enrich_nutrition.py --root ./server/media/prospekte --only-market aldi_nord
    python tools/enrich_nutrition.py --root ./server/media/prospekte --overwrite
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any, List, Optional, Tuple

# Add nutrition module to path
sys.path.insert(0, str(Path(__file__).parent))

from nutrition.cache import NutritionCache
from nutrition.normalization import (
    get_canonical_key,
    is_pantry_item,
    get_density,
    calculate_string_similarity,
    normalize_name,
)
from nutrition.providers.openfoodfacts import OpenFoodFactsProvider
from nutrition.providers.usda_fdc import USDAFoodDataCentralProvider


class NutritionEnricher:
    """
    Main enrichment pipeline.
    """
    
    CONFIDENCE_THRESHOLD = 0.5  # Minimum confidence to accept match
    
    def __init__(
        self,
        cache_dir: str = "./nutrition_cache",
        exclude_pantry_nutrition: bool = True,
        verbose: bool = False
    ):
        """
        Initialize enricher.
        
        Args:
            cache_dir: Directory for cache files
            exclude_pantry_nutrition: Whether to exclude pantry items from nutrition calc
            verbose: Verbose logging
        """
        self.cache = NutritionCache(cache_dir)
        self.exclude_pantry_nutrition = exclude_pantry_nutrition
        self.verbose = verbose
        
        # Initialize providers
        self.off_provider = OpenFoodFactsProvider()
        self.usda_provider = USDAFoodDataCentralProvider()
        
        if not self.usda_provider.is_available():
            print("⚠️  USDA provider not available (no API key)")
            print("   Set USDA_FDC_API_KEY environment variable")
            print("   Get free key at: https://fdc.nal.usda.gov/api-key-signup.html")
        
        # Statistics
        self.stats = {
            "files_processed": 0,
            "files_failed": 0,
            "recipes_processed": 0,
            "ingredients_processed": 0,
            "ingredients_enriched": 0,
            "ingredients_pantry": 0,
            "ingredients_missing": 0,
            "ingredients_ambiguous": 0,
            "api_calls": 0,
            "cache_hits": 0,
        }
    
    def process_directory(
        self,
        root_dir: Path,
        overwrite: bool = False,
        only_market: Optional[str] = None,
        only_kw: Optional[str] = None
    ):
        """
        Recursively process all recipe JSONs in directory.
        
        Args:
            root_dir: Root directory to scan
            overwrite: Overwrite original files instead of creating _nutrition.json
            only_market: Only process specific market (e.g., 'aldi_nord')
            only_kw: Only process specific week (e.g., 'kw52_2025')
        """
        if not root_dir.exists():
            print(f"❌ Directory not found: {root_dir}")
            return
        
        print(f"🔍 Scanning {root_dir} for recipe JSONs...")
        
        # Find all JSON files
        json_files = list(root_dir.rglob("*.json"))
        
        # Filter by market/week if specified
        if only_market:
            json_files = [f for f in json_files if only_market in str(f)]
        if only_kw:
            json_files = [f for f in json_files if only_kw in f.stem]
        
        # Exclude already-processed _nutrition.json files
        json_files = [f for f in json_files if not f.stem.endswith("_nutrition")]
        
        # Exclude cache files
        json_files = [f for f in json_files if "nutrition_cache" not in str(f)]
        
        print(f"📄 Found {len(json_files)} recipe JSON(s)")
        
        if not json_files:
            print("ℹ️  No files to process")
            return
        
        # Process each file
        for json_file in json_files:
            try:
                self._process_file(json_file, overwrite)
            except Exception as e:
                print(f"❌ Error processing {json_file}: {e}")
                self.stats["files_failed"] += 1
                if self.verbose:
                    import traceback
                    traceback.print_exc()
        
        # Save cache and print summary
        self.cache.save_all()
        self._print_summary()
    
    def _process_file(self, json_file: Path, overwrite: bool = False):
        """
        Process a single recipe JSON file.
        
        Args:
            json_file: Path to JSON file
            overwrite: Whether to overwrite original
        """
        print(f"\n📝 Processing: {json_file.relative_to(Path.cwd())}")
        
        # Load JSON
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception as e:
            print(f"   ❌ Failed to load JSON: {e}")
            self.stats["files_failed"] += 1
            return
        
        # Handle different structures
        recipes = self._extract_recipes(data)
        
        if not recipes:
            print("   ⚠️  No recipes found in file")
            return
        
        print(f"   Found {len(recipes)} recipe(s)")
        
        # Process each recipe
        for recipe in recipes:
            self._enrich_recipe(recipe)
            self.stats["recipes_processed"] += 1
        
        # Write output
        if overwrite:
            output_file = json_file
        else:
            output_file = json_file.parent / f"{json_file.stem}_nutrition.json"
        
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"   ✅ Saved: {output_file.name}")
            self.stats["files_processed"] += 1
        except Exception as e:
            print(f"   ❌ Failed to save: {e}")
            self.stats["files_failed"] += 1
    
    def _extract_recipes(self, data: Any) -> List[Dict[str, Any]]:
        """
        Extract recipe list from various JSON structures.
        
        Args:
            data: Loaded JSON data
        
        Returns:
            List of recipe dicts
        """
        # Direct list
        if isinstance(data, list):
            return data
        
        # Dict with 'recipes' key
        if isinstance(data, dict):
            if "recipes" in data:
                return data["recipes"]
            if "data" in data:
                return data["data"]
            # Single recipe?
            if "title" in data or "name" in data:
                return [data]
        
        return []
    
    def _enrich_recipe(self, recipe: Dict[str, Any]):
        """
        Enrich a single recipe with nutrition data.
        
        Args:
            recipe: Recipe dict (modified in place)
        """
        ingredients = recipe.get("ingredients", [])
        
        if not ingredients:
            return
        
        # Track totals
        total_kcal = 0.0
        total_protein = 0.0
        total_fat = 0.0
        total_carbs = 0.0
        ingredients_with_nutrition = 0
        
        # Process each ingredient
        for ingredient in ingredients:
            nutrition_data = self._enrich_ingredient(ingredient)
            
            if nutrition_data:
                ingredients_with_nutrition += 1
                
                # Aggregate totals
                total = nutrition_data.get("nutrition_total", {})
                if total.get("kcal"):
                    total_kcal += total["kcal"]
                if total.get("protein_g"):
                    total_protein += total["protein_g"]
                if total.get("fat_g"):
                    total_fat += total["fat_g"]
                if total.get("carbs_g"):
                    total_carbs += total["carbs_g"]
        
        # Add recipe-level nutrition
        recipe["nutrition_total"] = {
            "kcal": round(total_kcal, 1),
            "protein_g": round(total_protein, 1),
            "fat_g": round(total_fat, 1),
            "carbs_g": round(total_carbs, 1),
        }
        
        # Per serving (if servings specified)
        servings = recipe.get("servings") or recipe.get("portions") or 1
        if servings and servings > 0:
            recipe["nutrition_per_serving"] = {
                "kcal": round(total_kcal / servings, 1),
                "protein_g": round(total_protein / servings, 1),
                "fat_g": round(total_fat / servings, 1),
                "carbs_g": round(total_carbs / servings, 1),
            }
        
        # Coverage stats
        recipe["nutrition_coverage"] = {
            "ingredients_total": len(ingredients),
            "ingredients_with_nutrition": ingredients_with_nutrition,
            "missing": len(ingredients) - ingredients_with_nutrition,
        }
    
    def _enrich_ingredient(self, ingredient: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Enrich a single ingredient with nutrition data.
        
        Args:
            ingredient: Ingredient dict (modified in place)
        
        Returns:
            Nutrition data dict or None
        """
        name = ingredient.get("name") or ingredient.get("ingredient")
        if not name:
            return None
        
        self.stats["ingredients_processed"] += 1
        
        # Generate canonical key
        canonical_key = get_canonical_key(name)
        ingredient["canonical_key"] = canonical_key
        
        # Check if pantry item
        is_pantry = is_pantry_item(name)
        flags = {
            "exclude_from_shopping": is_pantry,
            "exclude_from_price": is_pantry,
            "exclude_from_nutrition": is_pantry and self.exclude_pantry_nutrition,
            "needs_manual_check": False,
        }
        ingredient["flags"] = flags
        
        if is_pantry:
            self.stats["ingredients_pantry"] += 1
            if self.exclude_pantry_nutrition:
                ingredient["nutrition_source"] = None
                ingredient["nutrition_per_100g"] = None
                ingredient["nutrition_total"] = None
                return None
        
        # Check cache first
        cached = self.cache.get(canonical_key)
        if cached:
            self.stats["cache_hits"] += 1
            nutrition_data = cached["nutrition"]
            metadata = cached.get("metadata", {})
            
            ingredient["nutrition_source"] = metadata.get("source")
            ingredient["nutrition_per_100g"] = nutrition_data
            
            # Calculate total based on qty/unit
            total = self._calculate_total_nutrition(
                ingredient,
                nutrition_data
            )
            ingredient["nutrition_total"] = total
            
            if total:
                self.stats["ingredients_enriched"] += 1
                return {"nutrition_per_100g": nutrition_data, "nutrition_total": total}
            
            return None
        
        # Check if already known to be missing/ambiguous
        if self.cache.is_missing(canonical_key):
            self.stats["ingredients_missing"] += 1
            self.cache.add_missing(canonical_key, name)
            ingredient["nutrition_source"] = None
            ingredient["nutrition_per_100g"] = None
            ingredient["nutrition_total"] = None
            return None
        
        # Fetch from APIs
        nutrition_source, nutrition_data = self._fetch_nutrition(canonical_key, name, ingredient)
        
        if nutrition_data:
            # Cache it
            self.cache.set(canonical_key, nutrition_data, {"source": nutrition_source})
            
            ingredient["nutrition_source"] = nutrition_source
            ingredient["nutrition_per_100g"] = nutrition_data
            
            # Calculate total
            total = self._calculate_total_nutrition(ingredient, nutrition_data)
            ingredient["nutrition_total"] = total
            
            self.stats["ingredients_enriched"] += 1
            return {"nutrition_per_100g": nutrition_data, "nutrition_total": total}
        else:
            # Mark as missing
            self.cache.add_missing(canonical_key, name, reason="not_found")
            self.stats["ingredients_missing"] += 1
            
            ingredient["nutrition_source"] = None
            ingredient["nutrition_per_100g"] = None
            ingredient["nutrition_total"] = None
            return None
    
    def _fetch_nutrition(
        self,
        canonical_key: str,
        original_name: str,
        ingredient: Dict[str, Any]
    ) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]]]:
        """
        Fetch nutrition data from APIs.
        
        Args:
            canonical_key: Normalized ingredient key
            original_name: Original ingredient name
            ingredient: Full ingredient dict (for offer_ref hints)
        
        Returns:
            (nutrition_source, nutrition_data) or (None, None)
        """
        # Try OFF first if there's an offer_ref (likely branded product)
        offer_ref = ingredient.get("offer_ref")
        
        all_matches = []
        
        if offer_ref:
            if self.verbose:
                print(f"      Searching OFF for: {canonical_key}")
            off_results = self.off_provider.search(canonical_key, limit=3)
            self.stats["api_calls"] += 1
            all_matches.extend(off_results)
        
        # Try USDA for generic foods
        if self.usda_provider.is_available():
            if self.verbose:
                print(f"      Searching USDA for: {canonical_key}")
            usda_results = self.usda_provider.search(canonical_key, limit=3)
            self.stats["api_calls"] += 1
            all_matches.extend(usda_results)
        
        # If no offer_ref, try OFF anyway for better coverage
        elif not offer_ref:
            if self.verbose:
                print(f"      Searching OFF for: {canonical_key}")
            off_results = self.off_provider.search(canonical_key, limit=3)
            self.stats["api_calls"] += 1
            all_matches.extend(off_results)
        
        if not all_matches:
            return None, None
        
        # Sort by confidence
        all_matches.sort(key=lambda x: x.get("confidence", 0), reverse=True)
        
        best_match = all_matches[0]
        best_confidence = best_match.get("confidence", 0)
        
        # Check if confidence is high enough
        if best_confidence < self.CONFIDENCE_THRESHOLD:
            # Add to ambiguous
            self.cache.add_ambiguous(canonical_key, original_name, all_matches[:3])
            self.stats["ingredients_ambiguous"] += 1
            
            if self.verbose:
                print(f"      ⚠️  Low confidence ({best_confidence:.2f}) for: {original_name}")
            
            return None, None
        
        # Check if there are multiple high-confidence matches
        high_confidence_matches = [m for m in all_matches if m.get("confidence", 0) >= self.CONFIDENCE_THRESHOLD]
        if len(high_confidence_matches) > 1:
            # Add to ambiguous but still use best match
            self.cache.add_ambiguous(canonical_key, original_name, high_confidence_matches[:3])
            self.stats["ingredients_ambiguous"] += 1
        
        # Extract nutrition data
        nutrition_per_100g = best_match.get("nutrition_per_100g")
        
        source = {
            "provider": best_match.get("provider"),
            "id": best_match.get("id"),
            "name": best_match.get("name"),
            "confidence": best_confidence,
        }
        
        if self.verbose:
            print(f"      ✓ Matched: {best_match.get('name')} ({best_confidence:.2f})")
        
        return source, nutrition_per_100g
    
    def _calculate_total_nutrition(
        self,
        ingredient: Dict[str, Any],
        nutrition_per_100g: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Calculate total nutrition based on qty and unit.
        
        Args:
            ingredient: Ingredient dict with qty/unit
            nutrition_per_100g: Nutrition per 100g/ml
        
        Returns:
            Total nutrition dict or None
        """
        qty = ingredient.get("qty") or ingredient.get("quantity")
        unit = ingredient.get("unit")
        
        if not qty or not unit:
            ingredient["flags"]["needs_manual_check"] = True
            return None
        
        # Convert qty to number
        try:
            qty = float(qty)
        except (ValueError, TypeError):
            ingredient["flags"]["needs_manual_check"] = True
            return None
        
        # Normalize unit
        unit_lower = unit.lower().strip()
        
        # Convert to grams
        grams = None
        
        if unit_lower in ["g", "gr", "gramm", "gram"]:
            grams = qty
        elif unit_lower in ["kg", "kilo", "kilogramm"]:
            grams = qty * 1000
        elif unit_lower in ["ml", "milliliter"]:
            # Use density table
            density, needs_check = get_density(ingredient.get("name", ""), unit_lower)
            grams = qty * density
            if needs_check:
                ingredient["flags"]["needs_manual_check"] = True
        elif unit_lower in ["l", "liter"]:
            density, needs_check = get_density(ingredient.get("name", ""), "ml")
            grams = qty * 1000 * density
            if needs_check:
                ingredient["flags"]["needs_manual_check"] = True
        elif unit_lower in ["stk", "stuck", "stueck", "stück", "piece", "pieces"]:
            # Can't convert pieces to grams without item weight
            ingredient["flags"]["needs_manual_check"] = True
            return None
        else:
            # Unknown unit
            ingredient["flags"]["needs_manual_check"] = True
            return None
        
        if not grams or grams <= 0:
            return None
        
        # Calculate totals
        factor = grams / 100.0
        
        return {
            "kcal": round(nutrition_per_100g["kcal"] * factor, 1) if nutrition_per_100g.get("kcal") else None,
            "protein_g": round(nutrition_per_100g["protein_g"] * factor, 1) if nutrition_per_100g.get("protein_g") else None,
            "fat_g": round(nutrition_per_100g["fat_g"] * factor, 1) if nutrition_per_100g.get("fat_g") else None,
            "carbs_g": round(nutrition_per_100g["carbs_g"] * factor, 1) if nutrition_per_100g.get("carbs_g") else None,
        }
    
    def _print_summary(self):
        """Print processing summary."""
        print("\n" + "="*60)
        print("📊 SUMMARY")
        print("="*60)
        print(f"Files processed:          {self.stats['files_processed']}")
        print(f"Files failed:             {self.stats['files_failed']}")
        print(f"Recipes processed:        {self.stats['recipes_processed']}")
        print(f"Ingredients processed:    {self.stats['ingredients_processed']}")
        print(f"  ✅ Enriched:            {self.stats['ingredients_enriched']}")
        print(f"  🥫 Pantry (excluded):   {self.stats['ingredients_pantry']}")
        print(f"  ❓ Ambiguous:           {self.stats['ingredients_ambiguous']}")
        print(f"  ❌ Missing:             {self.stats['ingredients_missing']}")
        print(f"\nAPI calls:                {self.stats['api_calls']}")
        print(f"Cache hits:               {self.stats['cache_hits']}")
        print("="*60)
        
        # Cache stats
        cache_stats = self.cache.get_stats()
        print(f"\n📦 Cache:")
        print(f"  Cached entries:         {cache_stats['cached']}")
        print(f"  Missing ingredients:    {cache_stats['missing']}")
        print(f"  Ambiguous ingredients:  {cache_stats['ambiguous']}")
        print("="*60)


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Enrich recipe JSONs with nutrition data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python tools/enrich_nutrition.py --root ./server/media/prospekte
  python tools/enrich_nutrition.py --root ./server/media/prospekte --only-market aldi_nord
  python tools/enrich_nutrition.py --root ./server/media/prospekte --only-kw kw52_2025 --overwrite
  
Environment Variables:
  USDA_FDC_API_KEY    API key for USDA FoodData Central (get at https://fdc.nal.usda.gov/api-key-signup.html)
        """
    )
    
    parser.add_argument(
        "--root",
        type=str,
        required=True,
        help="Root directory to scan for recipe JSONs"
    )
    
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite original files instead of creating _nutrition.json"
    )
    
    parser.add_argument(
        "--only-market",
        type=str,
        help="Only process specific market (e.g., 'aldi_nord')"
    )
    
    parser.add_argument(
        "--only-kw",
        type=str,
        help="Only process specific week (e.g., 'kw52_2025')"
    )
    
    parser.add_argument(
        "--exclude-pantry-nutrition",
        action="store_true",
        default=True,
        help="Exclude pantry items from nutrition calculation (default: True)"
    )
    
    parser.add_argument(
        "--cache-dir",
        type=str,
        default="./nutrition_cache",
        help="Directory for cache files (default: ./nutrition_cache)"
    )
    
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Verbose output"
    )
    
    args = parser.parse_args()
    
    # Convert root to absolute path
    root_dir = Path(args.root).resolve()
    
    # Initialize enricher
    enricher = NutritionEnricher(
        cache_dir=args.cache_dir,
        exclude_pantry_nutrition=args.exclude_pantry_nutrition,
        verbose=args.verbose
    )
    
    # Process directory
    enricher.process_directory(
        root_dir=root_dir,
        overwrite=args.overwrite,
        only_market=args.only_market,
        only_kw=args.only_kw
    )
    
    print("\n✨ Done!")


if __name__ == "__main__":
    main()

