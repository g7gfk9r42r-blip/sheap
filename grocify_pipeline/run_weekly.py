#!/usr/bin/env python3
"""
Weekly Grocify Pipeline Orchestrator

Runs complete pipeline: extract offers → enrich nutrition → generate recipes → generate images
"""

import argparse
import sys
import os
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

from src.utils.weekkey import get_current_weekkey, validate_weekkey
from src.utils.io import read_json, write_json, ensure_dir
from src.utils.logging import Logger
from src.offers.extract_offers import OfferExtractor
from src.nutrition.enrich import NutritionEnricher
from src.recipes.generate import RecipeGenerator
from src.images.generate_images import ImageGenerator


class PipelineOrchestrator:
    """Orchestrate weekly pipeline"""
    
    def __init__(self, weekkey: str, verbose: bool = False):
        self.weekkey = weekkey
        self.verbose = verbose
        self.logger = Logger(verbose=verbose)
        
        # Paths
        self.root = Path(__file__).parent
        self.prospekte_dir = self.root / "Prospekte"
        self.output_dir = self.root / "output"
        self.cache_dir = self.root / "cache"
        
        ensure_dir(self.output_dir / "offers")
        ensure_dir(self.output_dir / "recipes")
        ensure_dir(self.output_dir / "images")
        ensure_dir(self.output_dir / "reports")
        ensure_dir(self.cache_dir)
        
        # Load environment
        load_dotenv()
        
        self.openai_key = os.getenv("OPENAI_API_KEY")
        self.usda_key = os.getenv("USDA_API_KEY")
        
        if not self.openai_key:
            self.logger.error("OPENAI_API_KEY not set")
            sys.exit(1)
        
        # Report
        self.report = {
            "weekkey": weekkey,
            "started_at": datetime.now().isoformat(),
            "markets": {}
        }
    
    def process_market(
        self,
        market: str,
        recipes_count: int = 75,
        generate_images: bool = False
    ) -> bool:
        """Process one market through pipeline"""
        
        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"Processing market: {market}")
        self.logger.info(f"{'='*60}")
        
        market_report = {
            "status": "started",
            "stages": {}
        }
        
        try:
            # Stage 1: Extract offers
            self.logger.info("Stage 1: Extracting offers...")
            input_file = self.prospekte_dir / market / f"{market}.json"
            offers_file = self.output_dir / "offers" / market / f"offers_{self.weekkey}.json"
            
            if not input_file.exists():
                raise FileNotFoundError(f"Input file not found: {input_file}")
            
            ensure_dir(offers_file.parent)
            
            extractor = OfferExtractor(self.logger)
            offers_count = extractor.extract_and_save(input_file, offers_file, market, self.weekkey)
            
            market_report["stages"]["extract_offers"] = {
                "status": "success",
                "offers_count": offers_count
            }
            
            # Stage 2: Enrich nutrition
            self.logger.info("Stage 2: Enriching nutrition...")
            enriched_file = self.output_dir / "offers" / market / f"offers_{self.weekkey}_enriched.json"
            cache_file = self.cache_dir / "nutrition_cache.json"
            
            enricher = NutritionEnricher(cache_file, self.logger)
            nutrition_stats = enricher.enrich_file(offers_file, enriched_file)
            
            market_report["stages"]["enrich_nutrition"] = {
                "status": "success",
                **nutrition_stats
            }
            
            # Stage 3: Generate recipes
            self.logger.info("Stage 3: Generating recipes...")
            recipes_dir = self.output_dir / "recipes" / market
            ensure_dir(recipes_dir)
            
            recipe_model = os.getenv("OPENAI_MODEL_RECIPES", "gpt-4o-mini")
            generator = RecipeGenerator(self.openai_key, recipe_model, self.logger)
            recipe_stats = generator.generate_recipes(
                enriched_file,
                recipes_dir,
                market,
                self.weekkey,
                total_recipes=recipes_count
            )
            
            market_report["stages"]["generate_recipes"] = {
                "status": "success",
                **recipe_stats
            }
            
            # Stage 4: Generate images (optional)
            if generate_images:
                self.logger.info("Stage 4: Generating images...")
                images_dir = self.output_dir / "images" / market
                ensure_dir(images_dir)
                
                recipes_file = recipes_dir / f"recipes_{market}_{self.weekkey}.json"
                image_model = os.getenv("OPENAI_MODEL_IMAGES", "dall-e-3")
                
                img_generator = ImageGenerator(self.openai_key, image_model, self.logger)
                image_stats = img_generator.generate_images_for_recipes(
                    recipes_file,
                    images_dir,
                    market,
                    self.weekkey
                )
                
                market_report["stages"]["generate_images"] = {
                    "status": "success",
                    **image_stats
                }
            
            market_report["status"] = "success"
            self.logger.info(f"✅ {market} pipeline complete")
            return True
        
        except Exception as e:
            market_report["status"] = "failed"
            market_report["error"] = str(e)
            self.logger.error(f"❌ {market} pipeline failed: {e}")
            return False
        
        finally:
            self.report["markets"][market] = market_report
    
    def run(self, markets: list, recipes_count: int, generate_images: bool):
        """Run pipeline for all markets"""
        
        success_count = 0
        
        for market in markets:
            if self.process_market(market, recipes_count, generate_images):
                success_count += 1
        
        # Finalize report
        self.report["finished_at"] = datetime.now().isoformat()
        self.report["summary"] = {
            "total_markets": len(markets),
            "successful": success_count,
            "failed": len(markets) - success_count
        }
        
        # Save report
        report_file = self.output_dir / "reports" / f"run_report_{self.weekkey}.json"
        write_json(report_file, self.report)
        
        self.logger.info(f"\n{'='*60}")
        self.logger.info(f"PIPELINE SUMMARY")
        self.logger.info(f"{'='*60}")
        self.logger.info(f"Week: {self.weekkey}")
        self.logger.info(f"Markets processed: {success_count}/{len(markets)}")
        self.logger.info(f"Report: {report_file}")
        self.logger.info(f"{'='*60}")
        
        return success_count == len(markets)


def main():
    parser = argparse.ArgumentParser(description="Run weekly Grocify pipeline")
    parser.add_argument("--weekKey", type=str, help="Week key (YYYY-Www), defaults to current week")
    parser.add_argument("--markets", type=str, default="all", help="Comma-separated market IDs or 'all'")
    parser.add_argument("--recipes", type=int, default=75, help="Number of recipes to generate per market")
    parser.add_argument("--images", action="store_true", help="Generate recipe images")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    
    args = parser.parse_args()
    
    # Get week key
    weekkey = args.weekKey if args.weekKey else get_current_weekkey()
    if not validate_weekkey(weekkey):
        print(f"Invalid week key: {weekkey}")
        sys.exit(1)
    
    # Get markets
    if args.markets == "all":
        config_file = Path(__file__).parent / "config" / "markets.json"
        config = read_json(config_file)
        markets = [m["id"] for m in config["markets"] if m.get("enabled", True)]
    else:
        markets = [m.strip() for m in args.markets.split(",")]
    
    # Run pipeline
    orchestrator = PipelineOrchestrator(weekkey, verbose=args.verbose)
    success = orchestrator.run(markets, args.recipes, args.images)
    
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

