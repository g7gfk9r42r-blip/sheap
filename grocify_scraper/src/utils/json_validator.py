"""JSON validation utilities"""

import json
from pathlib import Path
from typing import Dict, Any, List
import logging

logger = logging.getLogger(__name__)


def validate_json_file(file_path: Path) -> tuple[bool, str]:
    """
    Validate JSON file.
    
    Returns:
        Tuple of (is_valid, error_message)
    """
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            json.load(f)
        return True, ""
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, f"Error reading file: {e}"


def validate_offer_schema(offer: Dict[str, Any]) -> tuple[bool, List[str]]:
    """Validate offer schema"""
    errors = []
    
    # Required fields
    required = ["id", "supermarket", "weekKey", "title", "priceTiers"]
    for field in required:
        if field not in offer:
            errors.append(f"Missing required field: {field}")
    
    # Validate priceTiers
    if "priceTiers" in offer:
        price_tiers = offer["priceTiers"]
        if not isinstance(price_tiers, list):
            errors.append("priceTiers must be a list")
        else:
            for i, tier in enumerate(price_tiers):
                if not isinstance(tier, dict):
                    errors.append(f"priceTiers[{i}] must be a dict")
                    continue
                
                if "amount" not in tier:
                    errors.append(f"priceTiers[{i}] missing amount")
                
                if "condition" not in tier:
                    errors.append(f"priceTiers[{i}] missing condition")
                elif isinstance(tier.get("condition"), dict):
                    cond = tier["condition"]
                    if "type" not in cond:
                        errors.append(f"priceTiers[{i}].condition missing type")
    
    # Check loyalty rules
    if "priceTiers" in offer and isinstance(offer["priceTiers"], list):
        has_standard = any(
            tier.get("condition", {}).get("type") == "standard"
            for tier in offer["priceTiers"]
        )
        has_loyalty = any(
            tier.get("condition", {}).get("type") == "loyalty"
            for tier in offer["priceTiers"]
        )
        
        if has_loyalty and not has_standard:
            errors.append("LOYALTY_WITHOUT_STANDARD")
        
        # Check no loyalty marked as standard
        for tier in offer["priceTiers"]:
            cond = tier.get("condition", {})
            if cond.get("type") == "loyalty" and cond.get("type") == "standard":
                errors.append("LOYALTY_MARKED_AS_STANDARD")
    
    return len(errors) == 0, errors


def validate_recipe_schema(recipe: Dict[str, Any]) -> tuple[bool, List[str]]:
    """Validate recipe schema"""
    errors = []
    
    # Required fields
    required = ["id", "supermarket", "weekKey", "title", "heroImageUrl", "ingredients", "nutrition"]
    for field in required:
        if field not in recipe:
            errors.append(f"Missing required field: {field}")
    
    # Validate heroImageUrl is not empty
    if "heroImageUrl" in recipe and not recipe["heroImageUrl"]:
        errors.append("heroImageUrl must not be empty")
    
    # Validate nutrition has kcal and protein
    if "nutrition" in recipe:
        nutrition = recipe["nutrition"]
        if not isinstance(nutrition, dict):
            errors.append("nutrition must be a dict")
        else:
            if "kcal" not in nutrition:
                errors.append("nutrition missing kcal")
            elif nutrition["kcal"] and not isinstance(nutrition["kcal"], dict):
                errors.append("nutrition.kcal must be a dict with min/max")
            
            if "protein_g" not in nutrition:
                errors.append("nutrition missing protein_g")
            elif nutrition["protein_g"] and not isinstance(nutrition["protein_g"], dict):
                errors.append("nutrition.protein_g must be a dict with min/max")
    
    return len(errors) == 0, errors


def validate_all_outputs(output_dir: Path, week_key: str) -> Dict[str, Any]:
    """Validate all output files"""
    results = {
        "valid": True,
        "offers": {},
        "recipes": {},
        "errors": [],
    }
    
    # Validate offers
    offers_dir = output_dir / "offers"
    if offers_dir.exists():
        for offer_file in offers_dir.glob(f"offers_*_{week_key}.json"):
            supermarket = offer_file.stem.replace(f"offers_", "").replace(f"_{week_key}", "")
            
            # Check JSON validity
            is_valid, error = validate_json_file(offer_file)
            if not is_valid:
                results["valid"] = False
                results["errors"].append(f"{offer_file.name}: {error}")
                continue
            
            # Check schema
            with open(offer_file, 'r', encoding='utf-8') as f:
                offers = json.load(f)
            
            if not isinstance(offers, list):
                results["valid"] = False
                results["errors"].append(f"{offer_file.name}: Must be a list")
                continue
            
            offer_errors = []
            for i, offer in enumerate(offers):
                is_valid_offer, errors = validate_offer_schema(offer)
                if not is_valid_offer:
                    offer_errors.extend([f"Offer[{i}]: {e}" for e in errors])
            
            results["offers"][supermarket] = {
                "count": len(offers),
                "valid": len(offer_errors) == 0,
                "errors": offer_errors,
            }
            
            if offer_errors:
                results["valid"] = False
    
    # Validate recipes
    recipes_dir = output_dir / "recipes"
    if recipes_dir.exists():
        for recipe_file in recipes_dir.glob(f"recipes_*_{week_key}.json"):
            supermarket = recipe_file.stem.replace(f"recipes_", "").replace(f"_{week_key}", "")
            
            # Check JSON validity
            is_valid, error = validate_json_file(recipe_file)
            if not is_valid:
                results["valid"] = False
                results["errors"].append(f"{recipe_file.name}: {error}")
                continue
            
            # Check schema
            with open(recipe_file, 'r', encoding='utf-8') as f:
                recipes = json.load(f)
            
            if not isinstance(recipes, list):
                results["valid"] = False
                results["errors"].append(f"{recipe_file.name}: Must be a list")
                continue
            
            recipe_errors = []
            for i, recipe in enumerate(recipes):
                is_valid_recipe, errors = validate_recipe_schema(recipe)
                if not is_valid_recipe:
                    recipe_errors.extend([f"Recipe[{i}]: {e}" for e in errors])
            
            results["recipes"][supermarket] = {
                "count": len(recipes),
                "valid": len(recipe_errors) == 0,
                "errors": recipe_errors,
            }
            
            if recipe_errors:
                results["valid"] = False
    
    return results

