"""File writing utilities"""

from pathlib import Path
from typing import List, Dict, Any
import json
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


def write_json(data: Any, output_path: Path, pretty: bool = True) -> bool:
    """
    Write data to JSON file.
    
    Args:
        data: Data to write
        output_path: Output file path
        pretty: Pretty print JSON
        
    Returns:
        True if successful, False otherwise
    """
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Validate data is JSON-serializable
        try:
            json.dumps(data, ensure_ascii=False)
        except (TypeError, ValueError) as e:
            logger.error(f"Data is not JSON-serializable: {e}")
            return False
        
        # Write to temporary file first, then rename (atomic write)
        temp_path = output_path.with_suffix('.tmp')
        try:
            with open(temp_path, 'w', encoding='utf-8') as f:
                if pretty:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                else:
                    json.dump(data, f, ensure_ascii=False)
            
            # Atomic rename
            temp_path.replace(output_path)
            logger.info(f"Wrote JSON to {output_path}")
            return True
        except Exception as e:
            # Clean up temp file on error
            if temp_path.exists():
                temp_path.unlink()
            raise
        
    except Exception as e:
        logger.error(f"Failed to write JSON to {output_path}: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        return False


def write_offers(offers: List[Dict[str, Any]], supermarket: str, week_key: str, output_dir: Path) -> Path:
    """
    Write offers to JSON file.
    
    Args:
        offers: List of offer dictionaries
        supermarket: Supermarket name
        week_key: Week key
        output_dir: Output directory
        
    Returns:
        Path to written file
    """
    output_path = output_dir / f"offers_{supermarket}_{week_key}.json"
    write_json(offers, output_path)
    return output_path


def write_recipes(recipes: List[Dict[str, Any]], supermarket: str, week_key: str, output_dir: Path) -> Path:
    """
    Write recipes to JSON file.
    
    Args:
        recipes: List of recipe dictionaries
        supermarket: Supermarket name
        week_key: Week key
        output_dir: Output directory
        
    Returns:
        Path to written file
    """
    output_path = output_dir / f"recipes_{supermarket}_{week_key}.json"
    write_json(recipes, output_path)
    return output_path


def write_validation_report(
    report: Dict[str, Any],
    supermarket: str,
    week_key: str,
    reports_dir: Path
) -> Path:
    """Write validation report"""
    output_path = reports_dir / f"validation_{supermarket}_{week_key}.json"
    report["generated_at"] = datetime.now().isoformat()
    write_json(report, output_path)
    return output_path


def write_flagged_offers(
    flagged: List[Dict[str, Any]],
    supermarket: str,
    week_key: str,
    reports_dir: Path
) -> Path:
    """Write flagged offers report"""
    output_path = reports_dir / f"flagged_{supermarket}_{week_key}.json"
    write_json(flagged, output_path)
    return output_path


def write_summary(
    summary: Dict[str, Any],
    supermarket: str,
    week_key: str,
    reports_dir: Path
) -> Path:
    """Write summary report"""
    output_path = reports_dir / f"summary_{supermarket}_{week_key}.json"
    summary["generated_at"] = datetime.now().isoformat()
    write_json(summary, output_path)
    return output_path
