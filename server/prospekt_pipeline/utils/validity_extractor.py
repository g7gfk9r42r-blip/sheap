"""Extract validity date ranges from PDF/HTML text."""
from __future__ import annotations

import re
from datetime import datetime, timedelta
from typing import Optional, Tuple

from .logger import get_logger

LOGGER = get_logger("utils.validity")

# German date patterns
DATE_PATTERNS = [
    # "Mo. 24.11. – Sa. 29.11."
    re.compile(r'(?:Mo|Di|Mi|Do|Fr|Sa|So)\.?\s*(\d{1,2})\.(\d{1,2})\.?\s*[–-]\s*(?:Mo|Di|Mi|Do|Fr|Sa|So)\.?\s*(\d{1,2})\.(\d{1,2})\.?', re.IGNORECASE),
    # "24.11. - 29.11.2025"
    re.compile(r'(\d{1,2})\.(\d{1,2})\.\s*[–-]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})?', re.IGNORECASE),
    # "24.11.2025 bis 29.11.2025"
    re.compile(r'(\d{1,2})\.(\d{1,2})\.(\d{4})?\s+bis\s+(\d{1,2})\.(\d{1,2})\.(\d{4})?', re.IGNORECASE),
    # "gültig vom 24.11. bis 29.11."
    re.compile(r'gültig\s+(?:vom|ab)\s+(\d{1,2})\.(\d{1,2})\.\s+bis\s+(\d{1,2})\.(\d{1,2})\.', re.IGNORECASE),
    # "24.11. - 29.11."
    re.compile(r'(\d{1,2})\.(\d{1,2})\.\s*[–-]\s*(\d{1,2})\.(\d{1,2})\.', re.IGNORECASE),
]


def extract_validity_range(text: str, reference_date: Optional[datetime] = None) -> Tuple[Optional[str], Optional[str]]:
    """Extract validity date range from text.
    
    Returns:
        Tuple of (valid_from, valid_to) as ISO date strings, or (None, None)
    """
    if not text:
        return None, None
    
    if reference_date is None:
        reference_date = datetime.now()
    
    current_year = reference_date.year
    
    for pattern in DATE_PATTERNS:
        match = pattern.search(text)
        if match:
            groups = match.groups()
            
            try:
                if len(groups) >= 4:
                    # Extract day and month
                    day1 = int(groups[0])
                    month1 = int(groups[1])
                    
                    # Determine year
                    if len(groups) >= 5 and groups[4]:
                        year = int(groups[4])
                    elif len(groups) >= 3 and groups[2] and len(groups[2]) == 4:
                        year = int(groups[2])
                    else:
                        # Assume current year, or next year if month is in the past
                        year = current_year
                        if month1 < reference_date.month or (month1 == reference_date.month and day1 < reference_date.day):
                            year += 1
                    
                    # Second date
                    if len(groups) >= 5:
                        day2 = int(groups[2]) if len(groups) >= 3 else int(groups[0])
                        month2 = int(groups[3]) if len(groups) >= 4 else int(groups[1])
                    else:
                        day2 = int(groups[2])
                        month2 = int(groups[3])
                    
                    # Validate dates
                    try:
                        valid_from = datetime(year, month1, day1)
                        valid_to = datetime(year, month2, day2)
                        
                        # Ensure valid_to is after valid_from
                        if valid_to < valid_from:
                            # Assume next month/year
                            if month2 < month1:
                                valid_to = datetime(year + 1, month2, day2)
                            else:
                                valid_to = datetime(year, month2, day2)
                        
                        LOGGER.info("[VALIDITY] Extracted range: %s to %s", valid_from.date(), valid_to.date())
                        return valid_from.strftime("%Y-%m-%d"), valid_to.strftime("%Y-%m-%d")
                    except ValueError:
                        continue
            except (ValueError, IndexError, TypeError):
                continue
    
    # Fallback: Try to find single date and assume 7-day validity
    single_date_pattern = re.compile(r'(\d{1,2})\.(\d{1,2})\.(\d{4})?', re.IGNORECASE)
    match = single_date_pattern.search(text)
    if match:
        try:
            day = int(match.group(1))
            month = int(match.group(2))
            year = int(match.group(3)) if match.group(3) else current_year
            
            valid_from = datetime(year, month, day)
            valid_to = valid_from + timedelta(days=6)  # Assume 7-day validity
            
            LOGGER.info("[VALIDITY] Extracted single date, assuming 7-day validity: %s to %s", valid_from.date(), valid_to.date())
            return valid_from.strftime("%Y-%m-%d"), valid_to.strftime("%Y-%m-%d")
        except (ValueError, IndexError):
            pass
    
    LOGGER.warning("[VALIDITY] Could not extract validity range from text")
    return None, None

