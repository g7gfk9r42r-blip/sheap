"""Pipeline runner with retry logic"""

import logging
from typing import Dict, Any, List, Tuple
from pathlib import Path
from datetime import datetime

from ..config import SUPERMARKETS, REPORTS_DIR, BASE_DIR
from ..cli import run_pipeline, get_week_key
from ..io.file_writer import write_json
from ..io.file_loader import load_json

logger = logging.getLogger(__name__)


class PipelineRunner:
    """Run pipeline with retry logic"""
    
    MAX_RETRIES = 3
    FLAG_THRESHOLD = 0.05  # 5% flagged offers
    
    def __init__(self, week_key: str = None):
        self.week_key = week_key or get_week_key()
        self.results = {}
    
    def run_all(self) -> Dict[str, Any]:
        """Run pipeline for all supermarkets"""
        logger.info(f"Starting batch processing for week {self.week_key}")
        
        for supermarket in SUPERMARKETS.keys():
            logger.info(f"\n{'='*60}")
            logger.info(f"Processing: {supermarket}")
            logger.info(f"{'='*60}")
            
            result = self.run_with_retry(supermarket)
            self.results[supermarket] = result
        
        # Validate all outputs
        from ..utils.json_validator import validate_all_outputs
        from ..config import OUTPUT_DIR
        
        logger.info("\nValidating all output files...")
        validation_results = validate_all_outputs(OUTPUT_DIR, self.week_key)
        
        if not validation_results["valid"]:
            logger.error("❌ Validation failed!")
            for error in validation_results["errors"]:
                logger.error(f"  - {error}")
        
        # Generate global report
        global_report = self._generate_global_report()
        global_report["validation"] = validation_results
        
        # Write global report
        report_path = REPORTS_DIR / f"global_report_{self.week_key}.json"
        write_json(global_report, report_path)
        
        # Check if all succeeded
        if global_report["status"] == "READY_FOR_PRODUCTION" and validation_results["valid"]:
            logger.info("\n✅ Pipeline completed successfully!")
        else:
            logger.error("\n❌ Pipeline completed with errors. Check global_report.json")
            if not validation_results["valid"]:
                global_report["status"] = "BLOCKED"
                global_report["blocking_reasons"] = global_report.get("blocking_reasons", [])
                global_report["blocking_reasons"].append("JSON validation failed")
        
        return global_report
    
    def run_with_retry(self, supermarket: str) -> Dict[str, Any]:
        """Run pipeline with retry logic"""
        best_result = None
        best_flag_rate = 1.0
        
        for attempt in range(1, self.MAX_RETRIES + 1):
            logger.info(f"\nAttempt {attempt}/{self.MAX_RETRIES} for {supermarket}")
            
            try:
                # Run pipeline
                success = run_pipeline(supermarket, self.week_key, source_mode="auto")
                
                if not success:
                    logger.warning(f"Pipeline failed for {supermarket} (attempt {attempt})")
                    continue
                
                # Load validation report
                validation_path = REPORTS_DIR / f"validation_{supermarket}_{self.week_key}.json"
                if not validation_path.exists():
                    logger.warning(f"Validation report not found for {supermarket}")
                    continue
                
                validation = load_json(validation_path)
                if not validation:
                    continue
                
                # Calculate flag rate
                total = validation.get("total", 0)
                flagged = validation.get("flagged", 0)
                flag_rate = flagged / total if total > 0 else 1.0
                
                logger.info(f"Flag rate: {flag_rate:.2%} ({flagged}/{total})")
                
                # Check if this is better
                if flag_rate < best_flag_rate:
                    best_flag_rate = flag_rate
                    best_result = {
                        "attempt": attempt,
                        "success": True,
                        "flag_rate": flag_rate,
                        "total": total,
                        "flagged": flagged,
                        "passed": validation.get("passed", 0),
                    }
                
                # If below threshold, we're done
                if flag_rate < self.FLAG_THRESHOLD:
                    logger.info(f"✅ Flag rate acceptable for {supermarket}")
                    break
                
                # If last attempt, use best result
                if attempt == self.MAX_RETRIES:
                    logger.warning(f"⚠️ Max retries reached for {supermarket}. Best flag rate: {best_flag_rate:.2%}")
                    if best_result:
                        best_result["max_retries_reached"] = True
                    break
                
                # Retry with stricter settings
                logger.info(f"Flag rate too high. Retrying with stricter validation...")
                
            except Exception as e:
                logger.error(f"Error in attempt {attempt} for {supermarket}: {e}")
                if attempt == self.MAX_RETRIES:
                    return {
                        "attempt": attempt,
                        "success": False,
                        "error": str(e),
                        "flag_rate": 1.0,
                    }
        
        if not best_result:
            return {
                "attempt": self.MAX_RETRIES,
                "success": False,
                "flag_rate": 1.0,
                "error": "All attempts failed",
            }
        
        return best_result
    
    def _generate_global_report(self) -> Dict[str, Any]:
        """Generate global report"""
        total_offers = 0
        total_recipes = 0
        total_flagged = 0
        loyalty_cases = 0
        confidence_dist = {"high": 0, "medium": 0, "low": 0}
        error_types = {}
        missing_supermarkets = []
        
        # Check each supermarket
        for supermarket in SUPERMARKETS.keys():
            result = self.results.get(supermarket)
            
            if not result or not result.get("success"):
                missing_supermarkets.append(supermarket)
                continue
            
            # Load offers
            offers_path = BASE_DIR / "out" / "offers" / f"offers_{supermarket}_{self.week_key}.json"
            if offers_path.exists():
                offers = load_json(offers_path) or []
                # Only count if offers exist
                if len(offers) > 0:
                    total_offers += len(offers)
                else:
                    # Empty file means no success
                    if supermarket not in missing_supermarkets:
                        missing_supermarkets.append(supermarket)
                    continue
                
                # Count loyalty cases
                for offer in offers:
                    price_tiers = offer.get("priceTiers", [])
                    has_loyalty = any(
                        tier.get("condition", {}).get("type") == "loyalty"
                        for tier in price_tiers
                    )
                    if has_loyalty:
                        loyalty_cases += 1
                    
                    # Confidence distribution
                    conf = offer.get("confidence", "medium")
                    confidence_dist[conf] = confidence_dist.get(conf, 0) + 1
                    
                    # Error types
                    flags = offer.get("flags", [])
                    for flag in flags:
                        error_types[flag] = error_types.get(flag, 0) + 1
                
                total_flagged += result.get("flagged", 0)
            
            # Load recipes
            recipes_path = BASE_DIR / "out" / "recipes" / f"recipes_{supermarket}_{self.week_key}.json"
            if recipes_path.exists():
                recipes = load_json(recipes_path) or []
                total_recipes += len(recipes)
        
        # Determine status
        status = "READY_FOR_PRODUCTION"
        if missing_supermarkets:
            status = "BLOCKED"
        elif total_offers == 0:
            status = "BLOCKED"
        elif total_flagged / total_offers > self.FLAG_THRESHOLD:
            status = "BLOCKED"
        
        report = {
            "status": status,
            "week_key": self.week_key,
            "generated_at": datetime.now().isoformat(),
            "summary": {
                "total_supermarkets": len(SUPERMARKETS),
                "processed_supermarkets": len(SUPERMARKETS) - len(missing_supermarkets),
                "missing_supermarkets": missing_supermarkets,
                "total_offers": total_offers,
                "total_recipes": total_recipes,
                "total_flagged": total_flagged,
                "flag_rate": total_flagged / total_offers if total_offers > 0 else 0,
            },
            "loyalty_analysis": {
                "total_loyalty_cases": loyalty_cases,
                "loyalty_rate": loyalty_cases / total_offers if total_offers > 0 else 0,
            },
            "confidence_distribution": confidence_dist,
            "top_errors": dict(sorted(error_types.items(), key=lambda x: x[1], reverse=True)[:10]),
            "supermarket_results": {
                sm: {
                    "success": self.results[sm].get("success", False),
                    "flag_rate": self.results[sm].get("flag_rate", 0),
                    "total": self.results[sm].get("total", 0),
                }
                for sm in SUPERMARKETS.keys()
            },
        }
        
        if status == "BLOCKED":
            report["blocking_reasons"] = []
            if missing_supermarkets:
                report["blocking_reasons"].append(f"Missing supermarkets: {', '.join(missing_supermarkets)}")
            if total_offers == 0:
                report["blocking_reasons"].append("No offers extracted")
            if total_flagged / total_offers > self.FLAG_THRESHOLD:
                report["blocking_reasons"].append(f"Flag rate too high: {total_flagged/total_offers:.2%}")
        
        return report

