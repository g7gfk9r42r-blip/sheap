#!/usr/bin/env python3
"""Run cached pipeline with resume support"""

import argparse
import json
import sys
from pathlib import Path

from src.pipeline.cached_pipeline import CachedPipeline

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--supermarket", required=True)
    parser.add_argument("--week-key", required=True)
    parser.add_argument("--pdf-path", type=Path)
    parser.add_argument("--raw-list-path", type=Path)
    parser.add_argument("--out-dir", type=Path, default=Path("out"))
    parser.add_argument("--max-loops", type=int, default=10)
    
    args = parser.parse_args()
    
    pipeline = CachedPipeline(
        supermarket=args.supermarket,
        week_key=args.week_key,
        out_dir=args.out_dir,
        pdf_path=args.pdf_path,
        raw_list_path=args.raw_list_path,
        max_loops=args.max_loops
    )
    
    result = pipeline.run()
    
    # Output ONLY JSON
    print(json.dumps(result, indent=2))
    
    sys.exit(0 if result.get("status") == "OK" else 1)

