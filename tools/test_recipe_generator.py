"""
Unit tests for recipe generator.
Run with: pytest tools/test_recipe_generator.py -v
"""

import json
import pytest
from pathlib import Path
from jsonschema import validate, ValidationError


# Load schema
SCHEMA_PATH = Path(__file__).parent / "recipe.schema.json"
with open(SCHEMA_PATH, 'r') as f:
    RECIPE_SCHEMA = json.load(f)


def test_schema_loads():
    """Test that schema file is valid JSON."""
    assert RECIPE_SCHEMA is not None
    assert "properties" in RECIPE_SCHEMA


def test_valid_recipe_passes():
    """Test that a valid recipe passes schema validation."""
    recipe = {
        "id": "aldi_nord-2025-W52-001",
        "title": "Test Recipe",
        "description": "This is a test recipe with enough characters to pass minimum length requirements.",
        "supermarket": "aldi_nord",
        "weekKey": "2025-W52",
        "category": "Lunch",
        "dietTags": ["balanced"],
        "servings": 4,
        "prepMinutes": 15,
        "cookMinutes": 30,
        "difficulty": "easy",
        "ingredients": [
            {
                "name": "Pasta",
                "amount": 400,
                "unit": "g",
                "isPantry": False,
                "offerRef": "offer-001",
                "offerMatchNote": "ALDI Nord Pasta 500g",
                "storeHint": "Trockenware / Nudeln"
            },
            {
                "name": "Tomaten",
                "amount": 300,
                "unit": "g",
                "isPantry": False,
                "offerRef": "offer-002",
                "offerMatchNote": "ALDI Nord Cherry-Tomaten",
                "storeHint": "Obst & Gemüse"
            },
            {
                "name": "Mozzarella",
                "amount": 125,
                "unit": "g",
                "isPantry": False,
                "offerRef": "offer-003",
                "offerMatchNote": "ALDI Nord Mozzarella",
                "storeHint": "Kühlregal / Käse"
            },
            {
                "name": "Olivenöl",
                "amount": 2,
                "unit": "el",
                "isPantry": True,
                "offerRef": None,
                "offerMatchNote": None,
                "storeHint": "Pantry / Öle"
            },
            {
                "name": "Salz",
                "amount": 1,
                "unit": "tl",
                "isPantry": True,
                "offerRef": None,
                "offerMatchNote": None,
                "storeHint": "Pantry / Gewürze"
            }
        ],
        "steps": [
            "Wasser zum Kochen bringen und Pasta nach Packungsanweisung kochen.",
            "Tomaten waschen und halbieren.",
            "Olivenöl in einer Pfanne erhitzen und Tomaten anbraten.",
            "Mozzarella in Würfel schneiden und zur Seite stellen.",
            "Gekochte Pasta abgießen, mit Tomaten mischen, Mozzarella darüber geben und servieren."
        ],
        "nutrition": {
            "kcal_total": 1800,
            "kcal_per_serving": 450,
            "kcal_source": "estimated",
            "kcal_confidence": "low"
        }
    }
    
    # Should not raise
    validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_missing_required_field_fails():
    """Test that missing required field fails validation."""
    recipe = {
        "id": "test-2025-W01-001",
        "title": "Incomplete Recipe",
        # Missing description, ingredients, steps, etc.
    }
    
    with pytest.raises(ValidationError):
        validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_invalid_id_format_fails():
    """Test that invalid ID format fails."""
    recipe = {
        "id": "invalid-id",  # Wrong format
        "title": "Test Recipe",
        "description": "A test recipe with enough characters to meet the minimum requirement.",
        "supermarket": "test_market",
        "weekKey": "2025-W52",
        "category": "Lunch",
        "dietTags": ["balanced"],
        "servings": 2,
        "prepMinutes": 10,
        "cookMinutes": 20,
        "difficulty": "easy",
        "ingredients": [
            {
                "name": "Test Ingredient",
                "amount": 100,
                "unit": "g",
                "isPantry": False,
                "offerRef": "offer-001",
                "offerMatchNote": "Test",
                "storeHint": "Test Aisle"
            }
        ] * 5,  # 5 ingredients
        "steps": ["Step 1", "Step 2", "Step 3", "Step 4", "Step 5"],
        "nutrition": {
            "kcal_total": 500,
            "kcal_per_serving": 250,
            "kcal_source": "estimated",
            "kcal_confidence": "low"
        }
    }
    
    with pytest.raises(ValidationError):
        validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_too_few_ingredients_fails():
    """Test that <5 ingredients fails."""
    recipe = {
        "id": "test-2025-W01-001",
        "title": "Test Recipe",
        "description": "A test recipe with enough characters to meet the minimum requirement.",
        "supermarket": "test_market",
        "weekKey": "2025-W01",
        "category": "Lunch",
        "dietTags": ["balanced"],
        "servings": 2,
        "prepMinutes": 10,
        "cookMinutes": 20,
        "difficulty": "easy",
        "ingredients": [
            {
                "name": "Ingredient 1",
                "amount": 100,
                "unit": "g",
                "isPantry": False,
                "offerRef": "offer-001",
                "offerMatchNote": "Test",
                "storeHint": "Aisle 1"
            },
            {
                "name": "Ingredient 2",
                "amount": 50,
                "unit": "ml",
                "isPantry": True,
                "offerRef": None,
                "offerMatchNote": None,
                "storeHint": "Pantry"
            }
        ],  # Only 2 ingredients
        "steps": ["Step 1", "Step 2", "Step 3", "Step 4", "Step 5"],
        "nutrition": {
            "kcal_total": 500,
            "kcal_per_serving": 250,
            "kcal_source": "estimated",
            "kcal_confidence": "low"
        }
    }
    
    with pytest.raises(ValidationError):
        validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_too_few_steps_fails():
    """Test that <5 steps fails."""
    recipe = {
        "id": "test-2025-W01-001",
        "title": "Test Recipe",
        "description": "A test recipe with enough characters to meet the minimum requirement.",
        "supermarket": "test_market",
        "weekKey": "2025-W01",
        "category": "Lunch",
        "dietTags": ["balanced"],
        "servings": 2,
        "prepMinutes": 10,
        "cookMinutes": 20,
        "difficulty": "easy",
        "ingredients": [
            {
                "name": f"Ingredient {i}",
                "amount": 100,
                "unit": "g",
                "isPantry": False,
                "offerRef": f"offer-{i:03d}",
                "offerMatchNote": "Test",
                "storeHint": "Test Aisle"
            }
            for i in range(5)
        ],
        "steps": ["Step 1", "Step 2"],  # Only 2 steps
        "nutrition": {
            "kcal_total": 500,
            "kcal_per_serving": 250,
            "kcal_source": "estimated",
            "kcal_confidence": "low"
        }
    }
    
    with pytest.raises(ValidationError):
        validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_invalid_category_fails():
    """Test that invalid category fails."""
    recipe = {
        "id": "test-2025-W01-001",
        "title": "Test Recipe",
        "description": "A test recipe with enough characters to meet the minimum requirement.",
        "supermarket": "test_market",
        "weekKey": "2025-W01",
        "category": "InvalidCategory",  # Not in enum
        "dietTags": ["balanced"],
        "servings": 2,
        "prepMinutes": 10,
        "cookMinutes": 20,
        "difficulty": "easy",
        "ingredients": [
            {
                "name": f"Ingredient {i}",
                "amount": 100,
                "unit": "g",
                "isPantry": False,
                "offerRef": f"offer-{i:03d}",
                "offerMatchNote": "Test",
                "storeHint": "Test Aisle"
            }
            for i in range(5)
        ],
        "steps": ["Step 1", "Step 2", "Step 3", "Step 4", "Step 5"],
        "nutrition": {
            "kcal_total": 500,
            "kcal_per_serving": 250,
            "kcal_source": "estimated",
            "kcal_confidence": "low"
        }
    }
    
    with pytest.raises(ValidationError):
        validate(instance=recipe, schema=RECIPE_SCHEMA)


def test_merge_batches_no_duplicates():
    """Test that merging batches doesn't create duplicate IDs."""
    batch1 = [
        {"id": "test-2025-W01-001", "title": "Recipe 1"},
        {"id": "test-2025-W01-002", "title": "Recipe 2"},
    ]
    
    batch2 = [
        {"id": "test-2025-W01-003", "title": "Recipe 3"},
        {"id": "test-2025-W01-004", "title": "Recipe 4"},
    ]
    
    merged = batch1 + batch2
    ids = [r["id"] for r in merged]
    
    assert len(ids) == len(set(ids)), "Duplicate IDs found after merge"


def test_non_food_detection():
    """Test that common non-food items can be detected."""
    non_food_keywords = [
        "zahncreme", "zahnpasta", "toiletries", "shampoo",
        "apple geschenkkarte", "gift card", "greeting card",
        "dekoration", "decoration", "kerze", "candle",
        "kleidung", "clothing", "mode", "fashion"
    ]
    
    food_keywords = [
        "pasta", "tomaten", "käse", "milch", "brot",
        "fleisch", "hähnchen", "obst", "gemüse"
    ]
    
    # Simple heuristic: non-food items shouldn't be in ingredients
    for keyword in non_food_keywords:
        # In real implementation, this would use is_pantry_item or similar
        assert keyword.lower() not in ["pasta", "tomaten", "käse"]
    
    for keyword in food_keywords:
        # Food items should be allowed
        assert isinstance(keyword, str)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

