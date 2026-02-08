"""Week key utilities"""
import datetime


def get_current_weekkey() -> str:
    """Get current ISO week in format YYYY-Www"""
    today = datetime.date.today()
    iso_year, iso_week, _ = today.isocalendar()
    return f"{iso_year}-W{iso_week:02d}"


def validate_weekkey(weekkey: str) -> bool:
    """Validate weekkey format YYYY-Www"""
    if not weekkey:
        return False
    parts = weekkey.split('-W')
    if len(parts) != 2:
        return False
    try:
        year = int(parts[0])
        week = int(parts[1])
        return 2020 <= year <= 2030 and 1 <= week <= 53
    except (ValueError, IndexError):
        return False

