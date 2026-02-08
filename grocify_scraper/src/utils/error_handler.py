"""Robust error handling"""

import logging
import traceback
from typing import Any, Callable, Optional
from functools import wraps

logger = logging.getLogger(__name__)


def safe_execute(func: Callable, *args, **kwargs) -> tuple[bool, Any, Optional[str]]:
    """
    Safely execute a function and return (success, result, error_message).
    
    Returns:
        Tuple of (success: bool, result: Any, error: Optional[str])
    """
    try:
        result = func(*args, **kwargs)
        return True, result, None
    except Exception as e:
        error_msg = f"{type(e).__name__}: {str(e)}\n{traceback.format_exc()}"
        logger.error(f"Error in {func.__name__}: {error_msg}")
        return False, None, error_msg


def retry_on_error(max_retries: int = 3, delay: float = 1.0):
    """Decorator to retry function on error"""
    def decorator(func: Callable):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_error = None
            for attempt in range(1, max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_error = e
                    if attempt < max_retries:
                        logger.warning(f"Attempt {attempt} failed for {func.__name__}, retrying...")
                        import time
                        time.sleep(delay * attempt)  # Exponential backoff
                    else:
                        logger.error(f"All {max_retries} attempts failed for {func.__name__}")
            raise last_error
        return wrapper
    return decorator


def validate_not_none(value: Any, name: str) -> None:
    """Validate that value is not None"""
    if value is None:
        raise ValueError(f"{name} must not be None")


def validate_positive(value: float, name: str) -> None:
    """Validate that value is positive"""
    if value <= 0:
        raise ValueError(f"{name} must be positive, got {value}")


def safe_parse_float(value: Any, default: float = 0.0) -> float:
    """Safely parse float"""
    try:
        if isinstance(value, (int, float)):
            return float(value)
        if isinstance(value, str):
            # Remove currency symbols and whitespace
            cleaned = value.replace('€', '').replace('$', '').strip()
            # Replace comma with dot
            cleaned = cleaned.replace(',', '.')
            return float(cleaned)
        return default
    except (ValueError, TypeError):
        return default


def safe_parse_int(value: Any, default: int = 0) -> int:
    """Safely parse int"""
    try:
        if isinstance(value, (int, float)):
            return int(value)
        if isinstance(value, str):
            return int(float(value.replace(',', '.')))
        return default
    except (ValueError, TypeError):
        return default

