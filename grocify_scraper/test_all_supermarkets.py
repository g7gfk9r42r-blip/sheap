#!/usr/bin/env python3
"""Test pipeline on all supermarkets"""

import sys
import logging
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.pipeline.runner import PipelineRunner
from src.cli import get_week_key

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('pipeline_test.log'),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger(__name__)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Test pipeline on all supermarkets")
    parser.add_argument("--week-key", help="Week key (YYYY-Www)", default=None)
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    week_key = args.week_key or get_week_key()
    
    logger.info("="*80)
    logger.info(f"Testing Pipeline on All Supermarkets - Week {week_key}")
    logger.info("="*80)
    
    runner = PipelineRunner(week_key=week_key)
    report = runner.run_all()
    
    # Print summary
    logger.info("\n" + "="*80)
    logger.info("FINAL REPORT")
    logger.info("="*80)
    logger.info(f"Status: {report['status']}")
    logger.info(f"Total Offers: {report['summary']['total_offers']}")
    logger.info(f"Total Recipes: {report['summary']['total_recipes']}")
    logger.info(f"Flag Rate: {report['summary']['flag_rate']:.2%}")
    logger.info(f"Loyalty Cases: {report['loyalty_analysis']['total_loyalty_cases']}")
    
    if report['status'] == 'BLOCKED':
        logger.error("\nBlocking Reasons:")
        for reason in report.get('blocking_reasons', []):
            logger.error(f"  - {reason}")
    
    # Exit with error code if blocked
    if report["status"] == "BLOCKED":
        sys.exit(1)
    else:
        sys.exit(0)

