"""CLI entry point"""

import argparse
import logging
import sys
from pathlib import Path
from datetime import datetime

from .config import SUPERMARKETS, BASE_DIR, SOURCES_DIR, OUTPUT_DIR, REPORTS_DIR, OFFERS_DIR, RECIPES_DIR
from .io.downloader import download_pdf, find_local_pdf
from .io.file_loader import find_list_files
import os
from .io.file_writer import write_offers, write_recipes, write_validation_report, write_flagged_offers, write_json
from .extract.pdf_extractor import PDFExtractor
from .extract.gpt_vision_extractor import GPTVisionExtractor
from .extract.list_parser import ListParser
from .normalize.normalizer import Normalizer
from .validate.validators import Validator
from .reconcile.reconciler import Reconciler
from .generate.recipe_generator import RecipeGenerator
from .pipeline.verification_loops import VerificationLoops
from .pipeline.checkpoint import CheckpointManager

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def get_week_key(date: datetime = None) -> str:
    """Get ISO week key"""
    if date is None:
        date = datetime.now()
    year, week, _ = date.isocalendar()
    return f"{year}-W{week:02d}"


def run_pipeline(supermarket: str, week_key: str = None, source_mode: str = "auto"):
    """
    Run the complete pipeline.
    
    Args:
        supermarket: Supermarket name
        week_key: Week key (YYYY-Www), defaults to current week
        source_mode: "auto", "pdf", "list", or "both"
    """
    if week_key is None:
        week_key = get_week_key()
    
    logger.info(f"Starting pipeline for {supermarket} ({week_key})")
    
    config = SUPERMARKETS.get(supermarket)
    if not config:
        logger.error(f"Unknown supermarket: {supermarket}")
        return False
    
    # Step 1: Collect sources
    pdf_path = None
    list_files = []
    
    # Try to find files in server/media/prospekte/ first
    server_prospekte_dir = BASE_DIR.parent / "server" / "media" / "prospekte"
    
    if source_mode in ["auto", "pdf", "both"] and config.has_pdf:
        # Try server/media/prospekte first
        if server_prospekte_dir.exists():
            supermarket_dir = server_prospekte_dir / supermarket
            if supermarket_dir.exists():
                # Find PDF files
                pdf_files = list(supermarket_dir.glob("*.pdf"))
                if pdf_files:
                    pdf_path = pdf_files[0]  # Use first PDF found
                    logger.info(f"Found PDF in server directory: {pdf_path}")
        
        # Fallback: Try to download PDF
        if not pdf_path and config.pdf_url:
            pdf_path = SOURCES_DIR / "pdf" / supermarket / f"{supermarket}_{week_key}.pdf"
            if not pdf_path.exists():
                logger.info(f"Downloading PDF from {config.pdf_url}")
                download_pdf(config.pdf_url, pdf_path)
        
        # Fallback: Try sources directory
        if not pdf_path:
            pdf_path = find_local_pdf(supermarket, week_key, SOURCES_DIR)
    
    if source_mode in ["auto", "list", "both"] and config.has_list:
        # Try server/media/prospekte first
        if server_prospekte_dir.exists():
            supermarket_dir = server_prospekte_dir / supermarket
            if supermarket_dir.exists():
                # Find JSON files
                json_files = list(supermarket_dir.glob("*.json"))
                if json_files:
                    list_files.extend(json_files)
                    logger.info(f"Found {len(json_files)} JSON files in server directory")
        
        # Fallback: Try sources directory
        if not list_files:
            list_files = find_list_files(supermarket, SOURCES_DIR)
    
    # Step 2: Extract
    pdf_offers_raw = []
    list_offers_raw = []
    
    pdf_page_stats = {}
    if pdf_path and pdf_path.exists():
        try:
            logger.info(f"Extracting from PDF: {pdf_path}")
            
            # Try GPT Vision first (if available)
            vision_extractor = GPTVisionExtractor(supermarket)
            if vision_extractor.client:
                logger.info("Using GPT Vision extraction (page-based with completeness checks)")
                pdf_offers_raw, pdf_page_stats = vision_extractor.extract(pdf_path, week_key, max_passes=3)
                logger.info(f"Extracted {len(pdf_offers_raw)} offers from PDF using GPT Vision")
            else:
                # Fallback to traditional extraction
                logger.info("GPT Vision not available, using traditional PDF extraction")
                extractor = PDFExtractor(supermarket)
                pdf_offers_raw = extractor.extract(pdf_path, week_key)
                pdf_page_stats = {}
                logger.info(f"Extracted {len(pdf_offers_raw)} offers from PDF")
        except Exception as e:
            logger.error(f"Failed to extract from PDF: {e}")
            import traceback
            logger.debug(traceback.format_exc())
            pdf_offers_raw = []
            pdf_page_stats = {}
    
    if list_files:
        try:
            logger.info(f"Parsing {len(list_files)} list files")
            parser = ListParser(supermarket)
            for list_file in list_files:
                try:
                    parsed = parser.parse(list_file, week_key)
                    list_offers_raw.extend(parsed)
                    logger.info(f"Parsed {len(parsed)} offers from {list_file.name}")
                except Exception as e:
                    logger.error(f"Failed to parse {list_file}: {e}")
                    continue
        except Exception as e:
            logger.error(f"Failed to parse list files: {e}")
            list_offers_raw = []
    
    if not pdf_offers_raw and not list_offers_raw:
        logger.error("No offers extracted from any source!")
        # Write empty files to indicate failure
        write_offers([], supermarket, week_key, OFFERS_DIR)
        write_recipes([], supermarket, week_key, RECIPES_DIR)
        validation_report = {
            "total": 0,
            "passed": 0,
            "flagged": 0,
            "rejected": 0,
            "error": "No offers extracted from any source",
        }
        write_validation_report(validation_report, supermarket, week_key, REPORTS_DIR)
        return False
    
    # Step 3: Normalize
    logger.info("Normalizing offers...")
    normalizer = Normalizer(supermarket, week_key)
    pdf_offers_normalized = normalizer.normalize(pdf_offers_raw) if pdf_offers_raw else []
    list_offers_normalized = normalizer.normalize(list_offers_raw) if list_offers_raw else []
    
    # Initialize checkpoint manager
    checkpoint_path = REPORTS_DIR / "checkpoints" / f"checkpoint_{week_key}.json"
    checkpoint = CheckpointManager(checkpoint_path)
    checkpoint_data = checkpoint.load()
    
    # Update checkpoint with week key
    if not checkpoint_data.get("weekKey"):
        checkpoint_data["weekKey"] = week_key
        checkpoint_data["version"] = 1
        checkpoint_data["globalLoop"] = 0
        checkpoint_data["supermarkets"] = checkpoint_data.get("supermarkets", {})
        checkpoint.save(checkpoint_data)
    
    # Step 4: Run Verification Loops (up to 10 loops for completeness)
    logger.info("\n" + "="*60)
    logger.info("STARTING VERIFICATION LOOPS")
    logger.info("="*60)
    
    # Update checkpoint: starting reconciliation
    checkpoint.update_supermarket(supermarket, "RECONCILING", {
        "offers": {
            "pdfCount": len(pdf_offers_normalized),
            "rawCount": len(list_offers_normalized)
        }
    })
    
    verification_loops = VerificationLoops(supermarket, week_key, pdf_path)
    final_offers, loop_stats = verification_loops.run_loops(
        initial_pdf_offers=pdf_offers_normalized,
        initial_raw_offers=list_offers_normalized,
        max_loops=10,
        stability_threshold=0.01
    )
    
    # Update checkpoint: offers locked
    checkpoint.update_supermarket(supermarket, "LOCKED", {
        "offers": {
            "mergedCount": len(final_offers),
            "stableLoops": loop_stats.get("loops", [])[-1].get("loop", 0) if loop_stats.get("loops") else 0
        }
    })
    
    # Write page stats if available
    if pdf_page_stats:
        page_stats_path = REPORTS_DIR / f"pdf_page_stats_{supermarket}_{week_key}.json"
        write_json(pdf_page_stats, page_stats_path)
    
    # Write loop stats
    loop_stats_path = REPORTS_DIR / f"verification_loops_{supermarket}_{week_key}.json"
    write_json(loop_stats, loop_stats_path)
    
    # Write reconciliation report
    reconcile_report_path = REPORTS_DIR / f"reconcile_{supermarket}_{week_key}.json"
    reconcile_report = loop_stats.get("reconcile_report", {})
    write_json(reconcile_report, reconcile_report_path)
    
    # Step 5: Validate
    logger.info("\nValidating offers...")
    validator = Validator()
    validated_offers, flagged_offers, validation_report = validator.validate(final_offers)
    
    # Check duplicates
    duplicates = validator.check_duplicates(validated_offers)
    if duplicates:
        logger.warning(f"Found {len(duplicates)} duplicate offers")
    
    # Step 6: Generate recipes (50-100 per supermarket)
    logger.info("Generating recipes...")
    generator = RecipeGenerator(supermarket, week_key)
    # Target 80 recipes, min 50, max 100
    target_count = max(50, min(100, 80))
    recipes = generator.generate(validated_offers, count=target_count)
    
    # Step 8: Write outputs
    logger.info("Writing outputs...")
    
    # Convert offers to dicts (with error handling)
    offers_dicts = []
    for o in validated_offers:
        try:
            offer_dict = _offer_to_dict(o)
            if offer_dict:
                offers_dicts.append(offer_dict)
        except Exception as e:
            logger.error(f"Failed to convert offer to dict: {e}")
            continue
    
    recipes_dicts = []
    for r in recipes:
        try:
            recipe_dict = _recipe_to_dict(r)
            if recipe_dict:
                recipes_dicts.append(recipe_dict)
        except Exception as e:
            logger.error(f"Failed to convert recipe to dict: {e}")
            continue
    
    write_offers(offers_dicts, supermarket, week_key, OFFERS_DIR)
    write_recipes(recipes_dicts, supermarket, week_key, RECIPES_DIR)
    write_validation_report(validation_report, supermarket, week_key, REPORTS_DIR)
    if flagged_offers:
        write_flagged_offers(flagged_offers, supermarket, week_key, REPORTS_DIR)
    
    # Update checkpoint with final artifacts
    checkpoint.update_supermarket(supermarket, "RECIPES_DONE" if recipes else "LOCKED", {
        "artifacts": {
            "offersOut": f"out/offers/offers_{supermarket}_{week_key}.json",
            "reportsOut": [
                f"out/reports/validation_{supermarket}_{week_key}.json",
                f"out/reports/flagged_{supermarket}_{week_key}.json",
                f"out/reports/summary_{supermarket}_{week_key}.json",
            ],
            "recipesOut": f"out/recipes/recipes_{supermarket}_{week_key}.json" if recipes else None
        }
    })
    
    # Write summary
    summary = {
        "supermarket": supermarket,
        "week_key": week_key,
        "total_offers": len(validated_offers),
        "total_recipes": len(recipes),
        "flagged_offers": len(flagged_offers),
        "flag_rate": len(flagged_offers) / len(validated_offers) if validated_offers else 0,
        "validation_summary": {
            "passed": validation_report.get("passed", 0),
            "flagged": validation_report.get("flagged", 0),
            "rejected": validation_report.get("rejected", 0),
        },
    }
    from .io.file_writer import write_summary
    write_summary(summary, supermarket, week_key, REPORTS_DIR)
    
    logger.info(f"Pipeline completed: {len(validated_offers)} offers, {len(recipes)} recipes")
    return True


def _offer_to_dict(offer) -> dict:
    """Convert Offer to dict (handles both Offer objects and dicts)"""
    try:
        # Handle dicts
        if isinstance(offer, dict):
            # Ensure required fields
            if not offer.get("id"):
                # Generate ID if missing
                title = offer.get("title") or offer.get("name", "")
                import hashlib
                offer["id"] = hashlib.sha256(f"{title}{offer.get('supermarket', '')}{offer.get('weekKey', '')}".encode()).hexdigest()[:16]
            return offer
        
        # Handle Offer objects
        # Ensure all required fields exist
        if not hasattr(offer, 'id') or not offer.id:
            # Generate ID if missing
            title = getattr(offer, 'title', '') or getattr(offer, 'name', '')
            import hashlib
            offer.id = hashlib.sha256(f"{title}{getattr(offer, 'supermarket', '')}{getattr(offer, 'week_key', '')}".encode()).hexdigest()[:16]
        
        if not hasattr(offer, 'title') or not offer.title:
            # Try to get title from name
            offer.title = getattr(offer, 'name', '') or getattr(offer, 'title', '')
            if not offer.title:
                raise ValueError("Offer missing title")
        
        return {
        "id": offer.id,
        "supermarket": offer.supermarket,
        "weekKey": offer.week_key,
        "title": offer.title,
        "brand": offer.brand,
        "brandConfidence": offer.brand_confidence,
        "category": offer.category,
        "quantity": {
            "value": offer.quantity.value,
            "unit": offer.quantity.unit,
        },
        "basePrice": {
            "amount": offer.base_price.amount,
            "currency": offer.base_price.currency,
        },
        "referencePrice": {
            "amount": offer.reference_price.amount,
            "currency": offer.reference_price.currency,
            "type": offer.reference_price.type,
        } if offer.reference_price else None,
        "priceTiers": [
            {
                "amount": tier.amount,
                "currency": tier.currency,
                "condition": {
                    "type": tier.condition.type,
                    "label": tier.condition.label,
                    "requiresCard": tier.condition.requires_card,
                    "requiresApp": tier.condition.requires_app,
                    "minQty": tier.condition.min_qty,
                    "notes": tier.condition.notes,
                },
            }
            for tier in offer.price_tiers
        ],
        "discount": {
            "percent": offer.discount.percent,
            "derived": offer.discount.derived,
        } if offer.discount else None,
        "source": {
            "primary": offer.source.primary,
            "pdfFile": offer.source.pdf_file,
            "listFile": offer.source.list_file,
            "page": offer.source.page,
        },
        "confidence": offer.confidence,
        "flags": offer.flags if hasattr(offer, 'flags') else [],
        }
    except Exception as e:
        logger.error(f"Error converting offer to dict: {e}")
        # Return minimal valid dict
        return {
            "id": getattr(offer, 'id', 'unknown'),
            "supermarket": getattr(offer, 'supermarket', 'unknown'),
            "weekKey": getattr(offer, 'week_key', 'unknown'),
            "title": getattr(offer, 'title', 'Unknown'),
            "priceTiers": [],
            "confidence": "low",
            "flags": ["CONVERSION_ERROR"],
        }


def _recipe_to_dict(recipe) -> dict:
    """Convert Recipe to dict"""
    try:
        # Ensure all required fields exist
        if not hasattr(recipe, 'id') or not recipe.id:
            raise ValueError("Recipe missing id")
        if not hasattr(recipe, 'title') or not recipe.title:
            raise ValueError("Recipe missing title")
        
        return {
        "id": recipe.id,
        "supermarket": recipe.supermarket,
        "weekKey": recipe.week_key,
        "title": recipe.title,
        "tags": recipe.tags,
        "heroImageUrl": recipe.hero_image_url,
        "images": recipe.images,
        "servings": recipe.servings,
        "timeMinutes": recipe.time_minutes,
        "difficulty": recipe.difficulty,
        "ingredients": [
            {
                "name": ing.name,
                "amount": ing.amount,
                "unit": ing.unit,
                "fromOfferId": ing.from_offer_id,
                "isFromOffer": ing.is_from_offer,
                "price": ing.price,
            }
            for ing in recipe.ingredients
        ],
        "steps": recipe.steps,
        "nutrition": {
            "kcal": {"min": recipe.nutrition.kcal.min, "max": recipe.nutrition.kcal.max} if recipe.nutrition.kcal else None,
            "protein_g": {"min": recipe.nutrition.protein_g.min, "max": recipe.nutrition.protein_g.max} if recipe.nutrition.protein_g else None,
            "carbs_g": {"min": recipe.nutrition.carbs_g.min, "max": recipe.nutrition.carbs_g.max} if recipe.nutrition.carbs_g else None,
            "fat_g": {"min": recipe.nutrition.fat_g.min, "max": recipe.nutrition.fat_g.max} if recipe.nutrition.fat_g else None,
        },
        "pricing": {
            "estimatedTotal": recipe.pricing.estimated_total,
            "notes": recipe.pricing.notes,
        },
        "warnings": recipe.warnings if hasattr(recipe, 'warnings') else [],
        }
    except Exception as e:
        logger.error(f"Error converting recipe to dict: {e}")
        # Return minimal valid dict
        return {
            "id": getattr(recipe, 'id', 'unknown'),
            "supermarket": getattr(recipe, 'supermarket', 'unknown'),
            "weekKey": getattr(recipe, 'week_key', 'unknown'),
            "title": getattr(recipe, 'title', 'Unknown'),
            "heroImageUrl": getattr(recipe, 'hero_image_url', 'https://via.placeholder.com/400x300'),
            "ingredients": [],
            "nutrition": {
                "kcal": {"min": 0, "max": 0},
                "protein_g": {"min": 0, "max": 0},
            },
            "warnings": ["CONVERSION_ERROR"],
        }


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description="Grocify Scraper Pipeline")
    parser.add_argument("supermarket", help="Supermarket name")
    parser.add_argument("--week-key", help="Week key (YYYY-Www)", default=None)
    parser.add_argument("--source-mode", choices=["auto", "pdf", "list", "both"], default="auto")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    success = run_pipeline(args.supermarket, args.week_key, args.source_mode)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()

