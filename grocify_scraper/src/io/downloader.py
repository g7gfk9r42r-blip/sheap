"""PDF downloader"""

import requests
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)


def download_pdf(url: str, output_path: Path, timeout: int = 30) -> bool:
    """
    Download PDF from URL to output path.
    
    Args:
        url: PDF URL
        output_path: Where to save the PDF
        timeout: Request timeout in seconds
        
    Returns:
        True if successful, False otherwise
    """
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        logger.info(f"Downloading PDF from {url} to {output_path}")
        response = requests.get(url, timeout=timeout, stream=True)
        response.raise_for_status()
        
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        logger.info(f"Successfully downloaded PDF to {output_path}")
        return True
        
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to download PDF from {url}: {e}")
        return False
    except Exception as e:
        logger.error(f"Unexpected error downloading PDF: {e}")
        return False


def find_local_pdf(supermarket: str, week_key: str, base_dir: Path) -> Optional[Path]:
    """
    Find local PDF file for supermarket and week.
    
    Args:
        supermarket: Supermarket name
        week_key: Week key (YYYY-Www)
        base_dir: Base directory to search
        
    Returns:
        Path to PDF if found, None otherwise
    """
    # Try common patterns
    patterns = [
        f"{supermarket}_{week_key}.pdf",
        f"{supermarket}.pdf",
        f"{week_key}.pdf",
        "*.pdf",
    ]
    
    pdf_dir = base_dir / "pdf" / supermarket
    if not pdf_dir.exists():
        return None
    
    for pattern in patterns:
        matches = list(pdf_dir.glob(pattern))
        if matches:
            return matches[0]
    
    # Try any PDF in the directory
    pdfs = list(pdf_dir.glob("*.pdf"))
    if pdfs:
        return pdfs[0]
    
    return None

