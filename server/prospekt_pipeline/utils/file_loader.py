"""Utilities for locating and loading prospekt files."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .logger import get_logger

LOGGER = get_logger("utils.file_loader")


@dataclass
class ProspektFiles:
    html: Path
    pdf: Path
    json: Path  # Existing JSON file (e.g., edeka_berlin.json)
    output: Path

    def ensure_output_parent(self) -> None:
        self.output.parent.mkdir(parents=True, exist_ok=True)


def discover_files(folder: Path) -> ProspektFiles:
    html = folder / "raw.html"
    pdf = folder / "raw.pdf"
    output = folder / "offers.json"
    
    # Find existing JSON files (e.g., edeka_berlin.json, rewe.json)
    json_file = None
    json_patterns = [
        folder.name + ".json",  # e.g., "edeka berlin.json"
        folder.name.replace(" ", "_") + ".json",  # e.g., "edeka_berlin.json"
        "*.json",  # Any JSON file
    ]
    
    for pattern in json_patterns:
        matches = list(folder.glob(pattern))
        # Exclude offers.json (that's our output)
        matches = [m for m in matches if m.name != "offers.json"]
        if matches:
            json_file = matches[0]
            LOGGER.info("Found existing JSON file: %s", json_file.name)
            break
    
    if not json_file:
        # Fallback: search for any JSON file (except offers.json)
        all_json = [f for f in folder.glob("*.json") if f.name != "offers.json"]
        if all_json:
            json_file = all_json[0]
            LOGGER.info("Found existing JSON file: %s", json_file.name)
    
    # Create dummy path if no JSON found
    if not json_file:
        json_file = folder / "nonexistent.json"
    
    return ProspektFiles(html=html, pdf=pdf, json=json_file, output=output)


def load_text(path: Path) -> Optional[str]:
    try:
        data = path.read_text(encoding="utf-8")
        LOGGER.info("Loaded text %s (%d bytes)", path, len(data))
        return data
    except FileNotFoundError:
        LOGGER.warning("Text file missing: %s", path)
    except Exception as exc:  # noqa: BLE001
        LOGGER.error("Failed reading %s: %s", path, exc)
    return None


def load_binary(path: Path) -> Optional[bytes]:
    try:
        data = path.read_bytes()
        LOGGER.info("Loaded binary %s (%d bytes)", path, len(data))
        return data
    except FileNotFoundError:
        LOGGER.warning("Binary file missing: %s", path)
    except Exception as exc:  # noqa: BLE001
        LOGGER.error("Failed reading %s: %s", path, exc)
    return None
