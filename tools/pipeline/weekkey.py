"""Week key utilities"""
import datetime
import re
from typing import Optional


def extract_weekkey_from_text(text: str) -> Optional[str]:
    """Extract week key from prospekt text"""
    # Look for date patterns like "22.12." or "Mo. 22.12. – Sa. 27.12."
    date_pattern = r'(\d{1,2})\.(\d{1,2})\.'
    matches = re.findall(date_pattern, text[:1000])  # Check first 1000 chars
    
    if matches:
        day, month = int(matches[0][0]), int(matches[0][1])
        # Assume current or next year
        year = datetime.date.today().year
        try:
            date = datetime.date(year, month, day)
            iso_year, iso_week, _ = date.isocalendar()
            return f"{iso_year}-W{iso_week:02d}"
        except ValueError:
            pass
    
    return get_current_weekkey()


def get_current_weekkey() -> str:
    """Get current ISO week"""
    today = datetime.date.today()
    iso_year, iso_week, _ = today.isocalendar()
    return f"{iso_year}-W{iso_week:02d}"

