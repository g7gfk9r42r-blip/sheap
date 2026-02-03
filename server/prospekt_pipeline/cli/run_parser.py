"""CLI entry point for the universal prospekt parser."""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

from ..pipeline.process_prospekt import ProspektProcessor
from ..utils.logger import setup_logger


def iter_prospekt_folders(base: Path):
    """Iterate over all supermarket/city folder pairs."""
    for supermarket in base.iterdir():
        if not supermarket.is_dir() or supermarket.name.startswith("."):
            continue
        for city in supermarket.iterdir():
            if city.is_dir() and not city.name.startswith("."):
                yield city


def main() -> None:
    parser = argparse.ArgumentParser(description="Process supermarket prospekt folders")
    parser.add_argument(
        "--base",
        type=Path,
        default=Path("media/prospekte"),
        help="Base directory containing supermarket folders",
    )
    parser.add_argument(
        "--folder",
        type=Path,
        help="Process a single folder instead of scanning all",
    )
    parser.add_argument("--log-level", default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"], help="Logging level")
    args = parser.parse_args()

    log_level = getattr(logging, args.log_level.upper())
    setup_logger(level=log_level)
    processor = ProspektProcessor()

    if args.folder:
        if not args.folder.exists():
            print(f"Error: Folder not found: {args.folder}")
            return
        processor.process(args.folder)
        return

    base_path = Path(args.base)
    if not base_path.exists():
        print(f"Error: Base directory not found: {base_path}")
        return

    processed = 0
    failed = 0
    for folder in iter_prospekt_folders(base_path):
        try:
            processor.process(folder)
            processed += 1
        except Exception as exc:  # noqa: BLE001
            print(f"Failed to process {folder}: {exc}")
            failed += 1

    print(f"\nCompleted: {processed} processed, {failed} failed")


if __name__ == "__main__":
    main()

