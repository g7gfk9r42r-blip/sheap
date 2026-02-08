#!/usr/bin/env python3
"""
Wöchentliche Pipeline für alle Supermärkte
Automatische Erkennung neuer Prospekte und Generierung von Offers + Rezepten
"""

import json
import sys
import os
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List

from src.pipeline.cached_pipeline import CachedPipeline
from src.enrich.availability_checker import AvailabilityChecker
from src.enrich.nutrition_database import NutritionDatabase
from src.enrich.image_generator import ImageGenerator

# Set API keys from environment
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
DALLE_API_KEY = os.getenv("OPENAI_API_KEY")  # Same key for DALL-E


def get_week_key() -> str:
    """Get current week key"""
    now = datetime.now()
    year, week, _ = now.isocalendar()
    return f"{year}-W{week:02d}"


def find_prospekte(supermarket: str) -> Dict[str, Path]:
    """Find PDF and JSON files for supermarket"""
    prospekte_dir = Path("../server/media/prospekte") / supermarket
    
    if not prospekte_dir.exists():
        return {"pdf": None, "json": None}
    
    # Find PDF (most recent)
    pdfs = sorted(prospekte_dir.glob("*.pdf"), key=lambda p: p.stat().st_mtime, reverse=True)
    pdf_path = pdfs[0] if pdfs else None
    
    # Find JSON (most recent)
    jsons = sorted(prospekte_dir.glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)
    json_path = jsons[0] if jsons else None
    
    return {"pdf": pdf_path, "json": json_path}


def run_weekly_pipeline(week_key: str = None, out_dir: Path = Path("out")) -> Dict[str, Any]:
    """Run pipeline for all supermarkets"""
    if week_key is None:
        week_key = get_week_key()
    
    supermarkets = [
        "aldi_nord", "aldi_sued", "biomarkt", "edeka",
        "kaufland", "lidl", "nahkauf", "netto", "norma", "penny", "rewe", "tegut"
    ]
    
    results = {}
    total_offers = 0
    total_recipes = 0
    
    for supermarket in supermarkets:
        print(f"\n{'='*60}")
        print(f"Processing: {supermarket}")
        print(f"{'='*60}")
        
        # Find files
        files = find_prospekte(supermarket)
        
        if not files["pdf"] and not files["json"]:
            print(f"⚠️  No files found for {supermarket}, skipping")
            results[supermarket] = {"status": "SKIPPED", "reason": "no_files"}
            continue
        
        try:
            # Run pipeline
            pipeline = CachedPipeline(
                supermarket=supermarket,
                week_key=week_key,
                out_dir=out_dir,
                pdf_path=files["pdf"],
                raw_list_path=files["json"],
                max_loops=10
            )
            
            result = pipeline.run()
            results[supermarket] = result
            
            if result.get("status") == "OK":
                metrics = result.get("metrics", {})
                offers_count = metrics.get("offers", 0)
                recipes_count = metrics.get("recipes", 0)
                total_offers += offers_count
                total_recipes += recipes_count
                print(f"✅ {supermarket}: {offers_count} offers, {recipes_count} recipes")
            else:
                error_msg = result.get('error', 'Unknown error')
                print(f"❌ {supermarket}: {error_msg}")
                # Still count offers/recipes if available
                metrics = result.get("metrics", {})
                if metrics:
                    total_offers += metrics.get("offers", 0)
                    total_recipes += metrics.get("recipes", 0)
        
        except Exception as e:
            import traceback
            error_msg = f"{str(e)}\n{traceback.format_exc()}"
            print(f"❌ {supermarket}: Failed with error: {e}")
            results[supermarket] = {"status": "ERROR", "error": str(e)}
    
    # Create global manifest
    manifest = {
        "weekKey": week_key,
        "generatedAt": datetime.now().isoformat(),
        "summary": {
            "totalOffers": total_offers,
            "totalRecipes": total_recipes,
            "supermarketsProcessed": len([r for r in results.values() if r.get("status") == "OK"]),
        },
        "supermarkets": results,
    }
    
    manifest_path = out_dir / f"manifest_{week_key}.json"
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    
    print(f"\n{'='*60}")
    print(f"✅ Pipeline completed!")
    print(f"   Total Offers: {total_offers}")
    print(f"   Total Recipes: {total_recipes}")
    print(f"   Manifest: {manifest_path}")
    print(f"{'='*60}")
    
    return {
        "status": "OK",
        "manifestPath": str(manifest_path),
        "metrics": {
            "totalOffers": total_offers,
            "totalRecipes": total_recipes,
        }
    }


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument("--week-key", type=str, default=None)
    parser.add_argument("--out-dir", type=Path, default=Path("out"))
    
    args = parser.parse_args()
    
    result = run_weekly_pipeline(args.week_key, args.out_dir)
    
    # Output ONLY JSON
    print(json.dumps(result, indent=2))
    
    sys.exit(0 if result.get("status") == "OK" else 1)

