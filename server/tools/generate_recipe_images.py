#!/usr/bin/env python3
"""
Generate recipe images using Stable Diffusion (Replicate API)

Usage:
    python generate_recipe_images.py --retailer ALDI_SÜD --limit 10
    python generate_recipe_images.py --retailer all --limit 5
    python generate_recipe_images.py --retailer all  # Generate all

Requirements:
    pip install replicate requests python-dotenv
"""

import os
import sys
import json
import argparse
import time
from pathlib import Path
from typing import Dict, List, Optional
import requests
from dotenv import load_dotenv

# Replicate API endpoints
REPLICATE_API_URL = "https://api.replicate.com/v1/predictions"

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

# Paths (relative to server directory)
SERVER_DIR = Path(__file__).parent.parent
PROJECT_ROOT = SERVER_DIR.parent

# Load environment variables from project root
env_path = PROJECT_ROOT / ".env"
load_dotenv(dotenv_path=env_path)

# Replicate API (use environment variable)
REPLICATE_API_TOKEN = os.getenv("REPLICATE_API_TOKEN")
if not REPLICATE_API_TOKEN:
    print("❌ Error: REPLICATE_API_TOKEN not found in .env file")
    print("   Get your token from: https://replicate.com/account/api-tokens")
    sys.exit(1)

# Paths (relative to server directory)
BASE_DIR = SERVER_DIR
RECIPES_DIR = BASE_DIR / "media" / "prospekte"
IMAGES_DIR = BASE_DIR / "media" / "recipe_images"

# Ensure images directory exists
IMAGES_DIR.mkdir(parents=True, exist_ok=True)

# Retailer mapping
RETAILER_MAPPING = {
    "ALDI SÜD": "aldi_sued",
    "ALDI NORD": "aldi_nord",
    "REWE": "rewe",
    "LIDL": "lidl",
    "KAUFLAND": "kaufland",
    "NETTO": "netto",
    "PENNY": "penny",
    "NORMA": "norma",
    "NAHKAUF": "nahkauf",
    "TEGUT": "tegut",
    "BIOMARKT": "biomarkt",
}


def load_recipes(retailer_dir: Path) -> List[Dict]:
    """Load recipes from JSON file"""
    recipe_files = [
        retailer_dir / "_recipes.json",
        retailer_dir / f"{retailer_dir.name}_recipes.json",
        retailer_dir / f"{retailer_dir.name}.json",
    ]
    
    for recipe_file in recipe_files:
        if recipe_file.exists():
            try:
                with open(recipe_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    # Handle both array and object with recipes key
                    if isinstance(data, list):
                        return data
                    elif isinstance(data, dict) and "recipes" in data:
                        return data["recipes"]
                    return []
            except Exception as e:
                print(f"⚠️  Error loading {recipe_file}: {e}")
                continue
    
    return []


def generate_prompt(recipe: Dict) -> str:
    """Generate a high-quality Stable Diffusion prompt for recipe images"""
    title = recipe.get("title") or recipe.get("name", "")
    
    # Extract main ingredients (first 3-4)
    ingredients = recipe.get("ingredients", [])
    ingredient_names = []
    if isinstance(ingredients, list) and len(ingredients) > 0:
        for ing in ingredients[:4]:
            if isinstance(ing, dict):
                # Extract name from dict (could be 'name', 'product', etc.)
                name = ing.get("name") or ing.get("product") or ""
                if name:
                    # Remove brand prefix if present (e.g., "Milbona — Skyr" -> "Skyr")
                    name = name.split("—")[-1].strip() if "—" in name else name
                    # Clean up product names
                    name = name.replace("Nature's Best", "").strip()
                    if name:
                        ingredient_names.append(name)
            elif isinstance(ing, str):
                ingredient_names.append(ing)
    
    # Determine food category and style from title
    title_lower = title.lower()
    dish_type = "delicious meal"
    style_keywords = []
    
    # Check more specific types first (before generic "bowl")
    if any(word in title_lower for word in ["skyr", "yogurt", "joghurt"]):
        dish_type = "creamy yogurt bowl"
        style_keywords = ["fresh berries", "granola", "honey drizzle"]
    elif any(word in title_lower for word in ["smoothie", "shake"]):
        dish_type = "fresh smoothie"
        style_keywords = ["vibrant colors", "fresh fruit"]
    elif any(word in title_lower for word in ["pasta", "nudel", "spaghetti"]):
        dish_type = "pasta dish"
        style_keywords = ["creamy sauce", "fresh herbs", "parmesan"]
    elif any(word in title_lower for word in ["salat", "salad"]):
        dish_type = "fresh salad bowl" if "bowl" in title_lower else "fresh salad"
        style_keywords = ["vibrant colors", "crisp vegetables", "fresh greens"]
    elif any(word in title_lower for word in ["burger", "hamburger"]):
        dish_type = "juicy burger"
        style_keywords = ["melting cheese", "crisp lettuce", "toasted bun"]
    elif any(word in title_lower for word in ["pizza"]):
        dish_type = "wood-fired pizza"
        style_keywords = ["melted cheese", "fresh toppings", "crispy crust"]
    elif any(word in title_lower for word in ["curry"]):
        dish_type = "aromatic curry"
        style_keywords = ["rich sauce", "tender meat", "steaming"]
    elif any(word in title_lower for word in ["suppe", "soup"]):
        dish_type = "hearty soup"
        style_keywords = ["steaming hot", "fresh herbs", "broth"]
    elif any(word in title_lower for word in ["reis", "rice"]):
        dish_type = "fluffy rice dish"
        style_keywords = ["steaming", "aromatic"]
    
    # Build realistic food photography prompt
    prompt_parts = [
        f"Photorealistic photo of {title.lower()}",
        dish_type,
    ]
    
    # Add main ingredients if available
    if ingredient_names:
        ingredients_str = ", ".join(ingredient_names[:3])  # Max 3 for clarity
        prompt_parts.append(f"featuring {ingredients_str}")
    
    # Add style keywords
    if style_keywords:
        prompt_parts.append(", ".join(style_keywords[:2]))
    
    # Build the prompt
    prompt = ", ".join(filter(None, prompt_parts))
    
    # Add realistic photography style keywords (less "professional", more "real")
    prompt += (
        ", on white ceramic plate, natural daylight from window, "
        "overhead top view, home-cooked meal, authentic real food, "
        "shot on iPhone 14 Pro, natural shadows, slight imperfections, "
        "appetizing, high quality photo, realistic texture"
    )
    
    return prompt


def _generate_with_http_api(prompt: str) -> Optional[str]:
    """Fallback: Generate image using Replicate HTTP API directly"""
    headers = {
        "Authorization": f"Token {REPLICATE_API_TOKEN}",
        "Content-Type": "application/json",
    }
    
    data = {
        "version": "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
        "input": {
            "prompt": prompt,
            "negative_prompt": "AI generated, fake, synthetic, cartoon, illustration, digital art, computer graphics, rendered, 3D, unrealistic, perfect lighting, studio lighting, over-styled, commercial photography, stock photo, blurry, low quality, distorted, text, watermark, logo",
            "width": 1024,
            "height": 1024,
            "num_outputs": 1,
            "guidance_scale": 7.5,
            "num_inference_steps": 25,
        }
    }
    
    # Create prediction
    response = requests.post(REPLICATE_API_URL, json=data, headers=headers, timeout=30)
    if response.status_code != 201:
        raise Exception(f"API error: {response.status_code} - {response.text[:200]}")
    
    prediction = response.json()
    prediction_id = prediction["id"]
    
    # Poll for completion
    get_url = f"{REPLICATE_API_URL}/{prediction_id}"
    max_wait = 300  # 5 minutes
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        response = requests.get(get_url, headers=headers, timeout=30)
        if response.status_code != 200:
            raise Exception(f"API error: {response.status_code}")
        
        prediction = response.json()
        status = prediction.get("status")
        
        if status == "succeeded":
            output = prediction.get("output")
            if output:
                return output[0] if isinstance(output, list) else output
        elif status in ["failed", "canceled"]:
            error = prediction.get("error", "Unknown error")
            raise Exception(f"Prediction {status}: {error}")
        
        time.sleep(2)
    
    raise Exception("Timeout waiting for prediction")


def generate_image_with_replicate(prompt: str, output_path: Path) -> Optional[str]:
    """Generate image using Replicate API (SDXL model) - using direct HTTP requests"""
    try:
        # Use HTTP API directly (more reliable with Python 3.14)
        print(f"   🎨 Generating image...")
        image_url = _generate_with_http_api(prompt)
        
        if not image_url:
            return None
        
        # Download image
        response = requests.get(image_url, timeout=30)
        response.raise_for_status()
        
        # Save image
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "wb") as f:
            f.write(response.content)
        
        print(f"   ✅ Image saved: {output_path.name}")
        return str(output_path.relative_to(BASE_DIR))
        
    except Exception as e:
        print(f"   ❌ Error generating image: {e}")
        return None


def process_recipe(recipe: Dict, retailer: str, index: int, total: int) -> bool:
    """Process a single recipe: generate image and update JSON"""
    recipe_id = recipe.get("id") or f"recipe_{index}"
    title = recipe.get("title") or recipe.get("name", "Unknown")
    
    print(f"\n[{index+1}/{total}] {title}")
    
    # Skip if image already exists
    existing_image = recipe.get("heroImageUrl") or recipe.get("image_path")
    if existing_image and "recipe_images" in existing_image:
        print(f"   ⏭️  Image already exists, skipping")
        return True
    
    # Generate prompt
    prompt = generate_prompt(recipe)
    print(f"   📝 Prompt: {prompt[:80]}...")
    
    # Create output path
    retailer_images_dir = IMAGES_DIR / retailer.lower().replace(" ", "_")
    retailer_images_dir.mkdir(parents=True, exist_ok=True)
    
    image_filename = f"{recipe_id}.webp"
    image_path = retailer_images_dir / image_filename
    
    # Generate image
    relative_path = generate_image_with_replicate(prompt, image_path)
    if not relative_path:
        return False
    
    # Update recipe with image path (will be converted to URL by app)
    recipe["heroImageUrl"] = f"server/media/{relative_path}"
    
    return True


def save_recipes(recipes: List[Dict], retailer_dir: Path):
    """Save updated recipes back to JSON file"""
    recipe_files = [
        retailer_dir / "_recipes.json",
        retailer_dir / f"{retailer_dir.name}_recipes.json",
        retailer_dir / f"{retailer_dir.name}.json",
    ]
    
    for recipe_file in recipe_files:
        if recipe_file.exists():
            try:
                # Read original structure
                with open(recipe_file, "r", encoding="utf-8") as f:
                    original_data = json.load(f)
                
                # Update structure
                if isinstance(original_data, list):
                    updated_data = recipes
                elif isinstance(original_data, dict):
                    updated_data = original_data.copy()
                    updated_data["recipes"] = recipes
                else:
                    updated_data = recipes
                
                # Save with backup
                backup_file = recipe_file.with_suffix(".json.bak")
                if recipe_file.exists() and not backup_file.exists():
                    import shutil
                    shutil.copy2(recipe_file, backup_file)
                
                with open(recipe_file, "w", encoding="utf-8") as f:
                    json.dump(updated_data, f, ensure_ascii=False, indent=2)
                
                print(f"   💾 Saved: {recipe_file.name}")
                return True
            except Exception as e:
                print(f"   ❌ Error saving {recipe_file}: {e}")
                continue
    
    return False


def main():
    parser = argparse.ArgumentParser(description="Generate recipe images using Stable Diffusion")
    parser.add_argument("--retailer", required=True, help="Retailer name or 'all'")
    parser.add_argument("--limit", type=int, help="Limit number of recipes to process")
    parser.add_argument("--test", action="store_true", help="Test mode (only first 3 recipes)")
    args = parser.parse_args()
    
    # Get retailer directories
    if args.retailer.lower() == "all":
        retailer_dirs = [d for d in RECIPES_DIR.iterdir() if d.is_dir()]
    else:
        retailer_key = args.retailer.upper().replace("_", " ").replace("-", " ")
        retailer_dir_name = RETAILER_MAPPING.get(retailer_key) or args.retailer.lower()
        retailer_dirs = [RECIPES_DIR / retailer_dir_name]
    
    total_generated = 0
    total_failed = 0
    
    for retailer_dir in retailer_dirs:
        if not retailer_dir.exists():
            print(f"⚠️  Skipping {retailer_dir.name} (directory not found)")
            continue
        
        print(f"\n{'='*60}")
        print(f"Processing: {retailer_dir.name.upper()}")
        print(f"{'='*60}")
        
        # Load recipes
        recipes = load_recipes(retailer_dir)
        if not recipes:
            print(f"⚠️  No recipes found in {retailer_dir.name}")
            continue
        
        # Limit recipes
        limit = 3 if args.test else (args.limit or len(recipes))
        recipes_to_process = recipes[:limit]
        
        print(f"📋 Found {len(recipes)} recipes, processing {len(recipes_to_process)}")
        
        # Process each recipe
        for i, recipe in enumerate(recipes_to_process):
            success = process_recipe(recipe, retailer_dir.name, i, len(recipes_to_process))
            if success:
                total_generated += 1
            else:
                total_failed += 1
            
            # Rate limiting (be nice to API)
            if i < len(recipes_to_process) - 1:
                time.sleep(1)
        
        # Save updated recipes
        save_recipes(recipes, retailer_dir)
    
    print(f"\n{'='*60}")
    print(f"✅ Complete!")
    print(f"   Generated: {total_generated}")
    print(f"   Failed: {total_failed}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
