#!/usr/bin/env python3
"""
JSON Utilities: Validierung, IO, Backup
"""

import json
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime


def validate_recipe(recipe: Dict, index: Optional[int] = None) -> Tuple[bool, Optional[str], Optional[str]]:
    """
    Validiert ein Rezept-Objekt. Returns (is_valid, error_message, json_path)
    - index: Optional index im Array für JSON-Pfad (z.B. recipes[12])
    """
    prefix = f"recipes[{index}]" if index is not None else "recipe"
    
    if not isinstance(recipe, dict):
        return False, "Recipe is not a dictionary", prefix
    
    # ID muss existieren
    recipe_id = recipe.get('id')
    if not recipe_id:
        return False, "Missing required field: id", f"{prefix}.id"
    
    if not str(recipe_id).strip():
        return False, "Recipe ID is empty", f"{prefix}.id"
    
    # name oder title muss existieren
    title = recipe.get('title') or recipe.get('name')
    if not title:
        return False, "Missing required field: title or name", f"{prefix}.title|name"
    
    if not str(title).strip():
        return False, "Title/name is empty", f"{prefix}.title|name"
    
    # instructions oder steps muss existieren
    steps = recipe.get('steps') or recipe.get('instructions')
    if not steps:
        return False, "Missing required field: steps or instructions", f"{prefix}.steps|instructions"
    
    if isinstance(steps, list) and len(steps) == 0:
        return False, "Steps/instructions list is empty", f"{prefix}.steps|instructions"
    
    if isinstance(steps, str) and not steps.strip():
        return False, "Steps/instructions string is empty", f"{prefix}.steps|instructions"
    
    return True, None, None


def load_recipe_json(file_path: Path) -> Tuple[Optional[List[Dict]], Optional[str]]:
    """Lädt ein Rezept-JSON. Returns (recipes_list, error_message)"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        if isinstance(data, list):
            return data, None
        elif isinstance(data, dict) and 'recipes' in data:
            return data['recipes'], None
        else:
            return None, f"Invalid JSON structure in {file_path.name}"
    
    except json.JSONDecodeError as e:
        return None, f"JSON decode error: {e}"
    except Exception as e:
        return None, f"Error reading file: {e}"


def save_recipe_json(recipes: List[Dict], file_path: Path) -> Tuple[bool, Optional[str]]:
    """Speichert Rezepte als JSON. Returns (success, error_message)"""
    try:
        # Erstelle Ordner falls nicht vorhanden
        file_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(recipes, f, indent=2, ensure_ascii=False)
        
        return True, None
    
    except Exception as e:
        return False, f"Error writing file: {e}"


def backup_file(file_path: Path, backup_dir: Path) -> Tuple[bool, Optional[Path]]:
    """Erstellt Backup einer Datei. Returns (success, backup_path)"""
    if not file_path.exists():
        return True, None  # Kein Backup nötig
    
    try:
        # Backup-Ordner mit Timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_subdir = backup_dir / timestamp
        backup_subdir.mkdir(parents=True, exist_ok=True)
        
        backup_path = backup_subdir / file_path.name
        
        shutil.copy2(file_path, backup_path)
        
        return True, backup_path
    
    except Exception as e:
        return False, None


def update_recipe_image_path(recipe: Dict, image_path: str) -> Dict:
    """Fügt/aktualisiert image_path in einem Rezept"""
    updated = dict(recipe)
    updated['image_path'] = image_path
    return updated

