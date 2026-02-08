"""Retry utilities"""
import time
from typing import Callable, Any, Optional
from functools import wraps


def retry_on_failure(
    max_retries: int = 2,
    delay: float = 1.0,
    backoff: float = 2.0,
    exceptions: tuple = (Exception,)
):
    """Decorator for retrying functions on failure"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            last_exception = None
            current_delay = delay
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_retries:
                        time.sleep(current_delay)
                        current_delay *= backoff
                    else:
                        raise last_exception
            
            raise last_exception
        return wrapper
    return decorator


class RetryContext:
    """Context for tracking retries"""
    
    def __init__(self, max_retries: int = 2):
        self.max_retries = max_retries
        self.attempts = 0
        self.errors = []
    
    def should_retry(self) -> bool:
        return self.attempts < self.max_retries
    
    def record_attempt(self, error: Optional[Exception] = None):
        self.attempts += 1
        if error:
            self.errors.append(str(error))
    
    def get_summary(self) -> dict:
        return {
            "total_attempts": self.attempts,
            "max_retries": self.max_retries,
            "errors": self.errors
        }

