"""
🔥 Worker für eine einzelne Prospektdatei (PDF/HTML)
• AI Vision / OCR / HTML
• 2x Retry
• exception sicher
"""

from __future__ import annotations

import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from prospekt_pipeline.pipeline.process_prospekt import ProspektProcessor
from prospekt_pipeline.utils.logger import setup_logger

LOGGER = setup_logger("multiprocessing.worker")


def process_file(path: Path | str) -> Dict[str, Any]:
    """Process a single prospekt file (PDF or HTML) with retry logic.
    
    Args:
        path: Path to PDF or HTML file
        
    Returns:
        Dictionary with processing results
    """
    path = Path(path)
    
    try:
        return _try_process(path)
    except Exception as e:
        LOGGER.error("[WORKER] Fatal error processing %s: %s", path.name, e)
        return {
            "file": str(path),
            "status": "failed",
            "offers_count": 0,
            "error": str(e),
            "timestamp": datetime.now().isoformat(),
        }


def _try_process(path: Path, attempt: int = 1) -> Dict[str, Any]:
    """Try to process file with retry logic.
    
    Args:
        path: Path to file
        attempt: Current attempt number (max 3)
        
    Returns:
        Dictionary with processing results
    """
    try:
        LOGGER.info("[WORKER] Processing %s (attempt %d/3)", path.name, attempt)
        
        # Find the folder containing this file
        folder = path.parent
        
        # Use existing ProspektProcessor
        processor = ProspektProcessor()
        
        # Process the prospekt folder
        process_result = processor.process(folder)
        
        # Extract offers
        offers = process_result.get("offers", [])
        offers_count = len(offers)
        
        LOGGER.info("[WORKER] ✓ Success: %s -> %d offers", path.name, offers_count)
        
        return {
            "file": str(path),
            "status": "ok",
            "offers_count": offers_count,
            "error": None,
            "timestamp": datetime.now().isoformat(),
        }
        
    except Exception as e:
        error_msg = str(e)
        error_trace = traceback.format_exc()
        
        LOGGER.warning("[WORKER] Attempt %d/3 failed for %s: %s", attempt, path.name, error_msg)
        
        # Retry up to 3 times
        if attempt < 3:
            LOGGER.info("[WORKER] Retrying %s (attempt %d/3)...", path.name, attempt + 1)
            return _try_process(path, attempt + 1)
        
        # All retries failed
        LOGGER.error("[WORKER] ✗ Failed after 3 attempts: %s", path.name)
        
        return {
            "file": str(path),
            "status": "failed",
            "offers_count": 0,
            "error": error_msg,
            "traceback": error_trace,
            "timestamp": datetime.now().isoformat(),
        }


def process_folder(folder_path: Path | str) -> Dict[str, Any]:
    """Process an entire folder containing prospekt files.
    
    Args:
        folder_path: Path to folder containing raw.pdf, raw.html, etc.
        
    Returns:
        Dictionary with processing results
    """
    folder_path = Path(folder_path)
    
    result = {
        "folder": str(folder_path),
        "status": "error",
        "offers_count": 0,
        "error": None,
        "timestamp": None,
    }
    
    try:
        LOGGER.info("[WORKER] Processing folder: %s", folder_path.name)
        
        # Use existing ProspektProcessor
        processor = ProspektProcessor()
        
        # Process the prospekt folder
        process_result = processor.process(folder_path)
        
        # Extract offers count
        offers = process_result.get("offers", [])
        result["offers_count"] = len(offers)
        result["status"] = "ok"
        result["timestamp"] = datetime.now().isoformat()
        
        LOGGER.info("[WORKER] ✓ Success: %s -> %d offers", folder_path.name, len(offers))
        
    except Exception as exc:
        error_msg = str(exc)
        error_trace = traceback.format_exc()
        
        result["error"] = error_msg
        result["status"] = "error"
        result["timestamp"] = datetime.now().isoformat()
        
        LOGGER.error("[WORKER] ✗ Failed: %s - %s", folder_path.name, error_msg)
        LOGGER.debug("[WORKER] Traceback: %s", error_trace)
    
    return result
