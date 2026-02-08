#!/usr/bin/env python3
"""Test single supermarket"""

import sys
import logging
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from src.cli import run_pipeline, get_week_key

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument("supermarket", help="Supermarket name")
    parser.add_argument("--week-key", default=None)
    
    args = parser.parse_args()
    
    week_key = args.week_key or get_week_key()
    
    print(f"Testing {args.supermarket} for week {week_key}")
    success = run_pipeline(args.supermarket, week_key)
    
    if success:
        print(f"✅ Success!")
        sys.exit(0)
    else:
        print(f"❌ Failed!")
        sys.exit(1)

