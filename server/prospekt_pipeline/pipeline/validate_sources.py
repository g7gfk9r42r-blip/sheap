"""Source validation utilities before processing."""
from __future__ import annotations

from pathlib import Path
from typing import Tuple

from ..utils.logger import get_logger

LOGGER = get_logger("pipeline.validate")


class SourceValidator:
    """Validates availability and quality of HTML/PDF sources."""

    MIN_PDF_BYTES = 1024

    def validate(self, folder: Path) -> Tuple[bool, bool]:
        html_ok = self._check_html(folder / "raw.html")
        pdf_ok = self._check_pdf(folder / "raw.pdf")
        return html_ok, pdf_ok

    def _check_html(self, path: Path) -> bool:
        if not path.exists():
            LOGGER.warning("raw.html missing at %s", path)
            return False
        try:
            content = path.read_text(encoding="utf-8")
            if not content.strip():
                LOGGER.warning("raw.html empty at %s", path)
                return False
            LOGGER.info("raw.html validated (%d bytes)", len(content))
            return True
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("Failed to read html %s: %s", path, exc)
            return False

    def _check_pdf(self, path: Path) -> bool:
        if not path.exists():
            LOGGER.warning("raw.pdf missing at %s", path)
            return False
        try:
            size = path.stat().st_size
            if size < self.MIN_PDF_BYTES:
                LOGGER.warning("raw.pdf suspiciously small (%d bytes)", size)
                return False
            LOGGER.info("raw.pdf validated (%d bytes)", size)
            return True
        except Exception as exc:  # noqa: BLE001
            LOGGER.error("Failed to stat pdf %s: %s", path, exc)
            return False
