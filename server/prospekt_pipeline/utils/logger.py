"""Logging utilities with custom FALLBACK level."""
from __future__ import annotations

import logging
import sys
from typing import Optional

FALLBACK_LEVEL = 25
logging.addLevelName(FALLBACK_LEVEL, "FALLBACK")


def fallback(self: logging.Logger, message: str, *args, **kwargs) -> None:
    if self.isEnabledFor(FALLBACK_LEVEL):
        self._log(FALLBACK_LEVEL, message, args, **kwargs)


logging.Logger.fallback = fallback  # type: ignore[arg-type]


def setup_logger(name: str = "prospekt_pipeline", level=logging.INFO) -> logging.Logger:
    """Configure and return a logger with console handler."""
    logger = logging.getLogger(name)
    if logger.handlers:
        return logger

    # LEVEL → robust (string ODER integer)
    if isinstance(level, int):
        log_level = level
    else:
        log_level = getattr(logging, str(level).upper(), logging.INFO)

    logger.setLevel(log_level)

    handler = logging.StreamHandler(sys.stdout)
    
    # Color codes for better readability
    class ColoredFormatter(logging.Formatter):
        COLORS = {
            'DEBUG': '\033[36m',      # Cyan
            'INFO': '\033[32m',       # Green
            'WARNING': '\033[33m',    # Yellow
            'ERROR': '\033[31m',      # Red
            'CRITICAL': '\033[35m',   # Magenta
            'FALLBACK': '\033[34m',   # Blue
        }
        RESET = '\033[0m'
        
        def format(self, record):
            # Add prefix based on logger name
            prefix = ""
            if "html" in record.name.lower():
                prefix = "[HTML] "
            elif "pdf" in record.name.lower():
                prefix = "[PDF] "
            elif "ocr" in record.name.lower():
                prefix = "[OCR] "
            elif "fallback" in record.name.lower():
                prefix = "[FALLBACK] "
            elif "merge" in record.name.lower():
                prefix = "[MERGE] "
            elif "normalize" in record.name.lower():
                prefix = "[NORMALIZE] "
            
            # Add color
            levelname = record.levelname
            color = self.COLORS.get(levelname, '')
            record.levelname = f"{color}{levelname}{self.RESET}"
            record.msg = f"{prefix}{record.msg}"
            
            return super().format(record)
    
    formatter = ColoredFormatter(
        "%(asctime)s | %(levelname)s | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)
    logger.propagate = False
    logger.debug("Logger initialized with level %s", logging.getLevelName(log_level))
    return logger


def get_logger(child: Optional[str] = None) -> logging.Logger:
    """Return child logger under the pipeline root."""
    base = logging.getLogger("prospekt_pipeline")
    if not base.handlers:
        setup_logger()
    return base.getChild(child) if child else base
