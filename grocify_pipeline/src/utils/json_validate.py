"""JSON validation utilities"""
import json
from typing import Any, Dict, Optional
from jsonschema import validate, ValidationError, Draft7Validator


def is_valid_json(text: str) -> bool:
    """Check if text is valid JSON"""
    try:
        json.loads(text)
        return True
    except (json.JSONDecodeError, ValueError):
        return False


def validate_against_schema(data: Any, schema: Dict) -> tuple[bool, Optional[str]]:
    """
    Validate data against JSON schema
    Returns (is_valid, error_message)
    """
    try:
        validate(instance=data, schema=schema)
        return True, None
    except ValidationError as e:
        return False, str(e)


def get_validation_errors(data: Any, schema: Dict) -> list:
    """Get all validation errors"""
    validator = Draft7Validator(schema)
    errors = list(validator.iter_errors(data))
    return [str(e) for e in errors]

