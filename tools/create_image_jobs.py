#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from typing import List, Dict, Any


def extract_main_ingredients(ingredients: List[Any]) -> List[str]:
    """Extrahiere Hauptzutaten (ohne Gewürze, Öl, etc.)"""
    skip_words = {'salz', 'pfeffer', 'öl', 'butter', 'wasser', 'salz', 'pfeffer', 'zucker', 
                  'knoblauch', 'zwiebel', 'paprika', 'chili', 'curry', 'kümmel', 'oregano',
                  'basilikum', 'thymian', 'rosmarin', 'petersilie', 'dill', 'schnittlauch'}
    
    main_ingredients = []
    for ing in ingredients:
        if isinstance(ing, dict):
            name = ing.get('name', '').lower().strip()
        elif isinstance(ing, str):
            name = ing.lower().strip()
        else:
            continue
        
        # Überspringe Gewürze und Basis-Zutaten
        if any(skip in name for skip in skip_words):
            continue
        
        if name and len(name) > 2:
            main_ingredients.append(name)
    
    return main_ingredients[:3]  # Max 3 Hauptzutaten


def clean_recipe_title(title: str) -> str:
    """Entferne generische Wörter aus Titel"""
    generic_words = ['einfach', 'einfache', 'einfacher', 'einfaches',
                     'klassisch', 'klassische', 'klassischer', 'klassisches',
                     'schnell', 'schnelle', 'schneller', 'schnelles',
                     'gedämpft', 'gedämpfte', 'gedämpfter', 'gedämpftes']
    
    words = title.lower().split()
    cleaned = [w for w in words if w not in generic_words]
    
    if not cleaned:
        return title
    
    # Erste Buchstabe groß
    result = ' '.join(cleaned)
    return result[0].upper() + result[1:] if result else title


def create_image_prompt(title: str, ingredients: List[str]) -> str:
    """Erstelle präzisen Bild-Prompt (max 2 Sätze)"""
    title_clean = clean_recipe_title(title)
    
    # Erster Satz: Hauptgericht
    if ingredients:
        ingredients_text = ", ".join(ingredients[:3])  # Max 3 Zutaten
        first_sentence = f"Photorealistic food photography of {title_clean} featuring {ingredients_text}"
    else:
        first_sentence = f"Photorealistic food photography of {title_clean}"
    
    # Zweiter Satz: Stil und Präsentation
    second_sentence = "Freshly plated on neutral kitchen surface, natural daylight, top-down or 45-degree angle, shallow depth of field, appetizing presentation, no people, no text, no labels"
    
    prompt = f"{first_sentence}. {second_sentence}"
    
    return prompt


def create_image_jobs(recipes_file: Path) -> List[Dict[str, Any]]:
    """Erstelle Bild-Generierungs-Jobs aus Rezepten"""
    with open(recipes_file, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    jobs = []
    
    for recipe in recipes:
        recipe_id = recipe.get('id', '')
        title = recipe.get('title') or recipe.get('shortTitle', '')
        
        if not recipe_id or not title:
            continue
        
        # Extrahiere Zutaten
        ingredients_raw = recipe.get('ingredients', [])
        main_ingredients = extract_main_ingredients(ingredients_raw)
        
        # Erstelle Prompt
        prompt = create_image_prompt(title, main_ingredients)
        
        job = {
            "recipeId": recipe_id,
            "prompt": prompt,
            "aspectRatio": "1:1",
            "style": "photorealistic",
            "lighting": "natural daylight",
            "camera": "top-down or 45-degree",
            "background": "neutral kitchen surface"
        }
        
        jobs.append(job)
    
    return jobs


def main():
    recipes_dir = Path("assets/recipes")
    output_dir = Path("assets/image_jobs")
    output_dir.mkdir(exist_ok=True)
    
    all_jobs = []
    
    for recipe_file in sorted(recipes_dir.glob("recipes_*.json")):
        jobs = create_image_jobs(recipe_file)
        all_jobs.extend(jobs)
        
        # Speichere auch pro Datei
        output_file = output_dir / f"{recipe_file.stem}_image_jobs.json"
        output_data = {"imageJobs": jobs}
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, indent=2, ensure_ascii=False)
    
    # Speichere alle Jobs zusammen
    all_output_file = output_dir / "all_image_jobs.json"
    all_output_data = {"imageJobs": all_jobs}
    
    with open(all_output_file, 'w', encoding='utf-8') as f:
        json.dump(all_output_data, f, indent=2, ensure_ascii=False)
    
    # Ausgabe für direkten Gebrauch
    print(json.dumps(all_output_data, indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()

