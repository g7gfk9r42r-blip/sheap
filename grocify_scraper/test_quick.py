#!/usr/bin/env python3
"""Quick test script - tests only first 2 pages for speed"""

import os
import sys
from pathlib import Path

# Set API key if provided
if len(sys.argv) > 1:
    os.environ["OPENAI_API_KEY"] = sys.argv[1]

from src.cli import run_pipeline, get_week_key

if __name__ == "__main__":
    week_key = get_week_key()
    supermarket = "biomarkt"
    
    print(f"Quick test: {supermarket} for week {week_key}")
    print("(Testing with limited pages for speed)")
    
    success = run_pipeline(supermarket, week_key)
    
    if success:
        print("✅ Quick test successful!")
        sys.exit(0)
    else:
        print("❌ Quick test failed!")
        sys.exit(1)

