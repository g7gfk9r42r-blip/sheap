#!/usr/bin/env python3
"""Run pipeline for all supermarkets"""

import sys
import logging
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent))

from src.pipeline.runner import PipelineRunner
from src.cli import get_week_key

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Run pipeline for all supermarkets")
    parser.add_argument("--week-key", help="Week key (YYYY-Www)", default=None)
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    week_key = args.week_key or get_week_key()
    
    runner = PipelineRunner(week_key=week_key)
    report = runner.run_all()
    
    # Exit with error code if blocked
    if report["status"] == "BLOCKED":
        print("\n❌ Pipeline BLOCKED. Check global_report.json for details.")
        sys.exit(1)
    else:
        print("\n✅ Pipeline READY_FOR_PRODUCTION")
        sys.exit(0)

