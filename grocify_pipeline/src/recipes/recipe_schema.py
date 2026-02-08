"""Recipe data schema"""
from typing import Dict, Any


RECIPE_JSON_SCHEMA = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "required": ["id", "title", "description", "supermarket", "servings", "ingredients", "steps", "nutrition"],
    "properties": {
        "id": {"type": "string"},
        "title": {"type": "string", "maxLength": 80},
        "description": {"type": "string", "maxLength": 200},
        "supermarket": {"type": "string"},
        "servings": {"type": "integer", "minimum": 1, "maximum": 8},
        "time_total_min": {"type": "integer", "minimum": 1},
        "difficulty": {"type": "string", "enum": ["easy", "medium", "hard"]},
        "tags": {"type": "array", "items": {"type": "string"}},
        "ingredients": {
            "type": "array",
            "minItems": 3,
            "items": {
                "type": "object",
                "required": ["name", "amount", "unit"],
                "properties": {
                    "name": {"type": "string"},
                    "amount": {"type": "number"},
                    "unit": {"type": "string"},
                    "offerRefs": {"type": "array"},
                    "nutrition": {"type": ["object", "null"]}
                }
            }
        },
        "steps": {
            "type": "array",
            "minItems": 3,
            "items": {"type": "string"}
        },
        "nutrition": {
            "type": "object",
            "required": ["kcal_total", "kcal_per_serving", "kcal_source"],
            "properties": {
                "kcal_total": {"type": "number"},
                "kcal_per_serving": {"type": "number"},
                "protein_g": {"type": "number"},
                "fat_g": {"type": "number"},
                "carbs_g": {"type": "number"},
                "kcal_source": {"type": "string", "enum": ["calculated", "missing"]},
                "kcal_confidence": {"type": "string", "enum": ["high", "medium", "low"]},
                "coverage": {"type": "object"}
            }
        },
        "image": {"type": "object"}
    }
}

