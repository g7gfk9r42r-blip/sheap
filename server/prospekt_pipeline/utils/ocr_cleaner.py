"""Utility helpers for cleaning OCR text artifacts."""
from __future__ import annotations

import re
from typing import Iterable

from .logger import get_logger

LOGGER = get_logger("utils.ocr_cleaner")

NOISE_CHARS = re.compile(r"[§\?\|¦]\s*")
SPACED_LETTERS = re.compile(r"(\b(?:[A-Za-z]\s+){3,}[A-Za-z]\b)")
DECIMAL_FIX = re.compile(r"(\d)[\.,](\d{2})")
EURO_FIX = re.compile(r"(\d[\d\.,]*)\s*(?:EUR|EURO|€)")
KG_L_PATTERN = re.compile(r"(\d+[\.,]\d+)\s*(?:kg|l|L)")


def clean_line(line: str) -> str:
    """Clean a single OCR line."""
    original = line
    line = NOISE_CHARS.sub("", line)
    line = _fix_spaced_letters(line)
    line = line.replace("€", " €").replace("$", " €")
    line = DECIMAL_FIX.sub(r"\1,\2", line)
    line = EURO_FIX.sub(r"\1 €", line)
    line = line.replace("  ", " ")
    if line != original:
        LOGGER.debug("OCR cleaned '%s' -> '%s'", original, line)
    return line.strip()


def _fix_spaced_letters(text: str) -> str:
    def _join(match: re.Match[str]) -> str:
        return match.group(0).replace(" ", "")

    return SPACED_LETTERS.sub(_join, text)


def normalize_lines(lines: Iterable[str]) -> list[str]:
    return [clean_line(line) for line in lines if line.strip()]
