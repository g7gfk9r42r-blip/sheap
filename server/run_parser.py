"""CLI entry point for the universal prospekt parser."""
from __future__ import annotations

import argparse
from pathlib import Path

from prospekt_pipeline.pipeline.process_prospekt import ProspektProcessor
from prospekt_pipeline.utils.logger import setup_logger


def iter_prospekt_folders(base: Path):
    for supermarket in base.iterdir():
        if not supermarket.is_dir():
            continue
        for city in supermarket.iterdir():
            if city.is_dir():
                yield city


def main() -> None:
    parser = argparse.ArgumentParser(description="Process supermarket prospekt folders")
    parser.add_argument(
        "--base",
        default="server/media/prospekte",
        help="Base directory containing supermarket folders",
    )
    parser.add_argument(
        "--folder",
        help="Process a single folder instead of scanning all",
    )
    parser.add_argument("--log-level", default="INFO", help="Logging level")
    args = parser.parse_args()

    setup_logger(level=getattr(__import__('logging'), args.log_level.upper(), __import__('logging').INFO))
    processor = ProspektProcessor()

    if args.folder:
        processor.process(Path(args.folder))
        return

    base_path = Path(args.base)
    for folder in iter_prospekt_folders(base_path):
        try:
            processor.process(folder)
        except Exception as exc:  # noqa: BLE001
            print(f"Failed to process {folder}: {exc}")


if __name__ == "__main__":
    main()
