"""File I/O utilities"""
import json
from pathlib import Path
from typing import Any, Dict, List


def ensure_dir(path: Path) -> Path:
    """Ensure directory exists"""
    path.mkdir(parents=True, exist_ok=True)
    return path


def read_json(filepath: Path) -> Any:
    """Read JSON file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


def write_json(filepath: Path, data: Any, pretty: bool = True) -> None:
    """Write JSON file with UTF-8 encoding"""
    ensure_dir(filepath.parent)
    with open(filepath, 'w', encoding='utf-8') as f:
        if pretty:
            json.dump(data, f, ensure_ascii=False, indent=2)
        else:
            json.dump(data, f, ensure_ascii=False)


def read_text(filepath: Path) -> str:
    """Read text file"""
    with open(filepath, 'r', encoding='utf-8') as f:
        return f.read()


def write_text(filepath: Path, text: str) -> None:
    """Write text file"""
    ensure_dir(filepath.parent)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(text)

