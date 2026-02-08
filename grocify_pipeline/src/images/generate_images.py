"""Recipe image generation with OpenAI"""
import requests
import os
from pathlib import Path
from typing import List, Dict
from PIL import Image
from io import BytesIO
from ..utils.io import read_json, write_json
from ..utils.retry import retry_on_failure
from ..utils.logging import Logger


class ImageGenerator:
    """Generate recipe images using OpenAI"""
    
    def __init__(self, api_key: str, model: str, logger: Logger):
        self.api_key = api_key
        self.model = model
        self.logger = logger
        self.base_url = "https://api.openai.com/v1/images/generations"
    
    def build_image_prompt(self, recipe: Dict) -> str:
        """Build image generation prompt"""
        title = recipe.get("title", "")
        description = recipe.get("description", "")
        
        ingredients = ", ".join([ing['name'] for ing in recipe.get("ingredients", [])[:5]])
        
        prompt = f"Professional food photography: {title}. {description}. "
        prompt += f"Main ingredients: {ingredients}. "
        prompt += "Clean plating, natural lighting, appetizing presentation, high quality, 4k."
        
        return prompt[:1000]  # OpenAI has prompt limits
    
    @retry_on_failure(max_retries=2, delay=2.0)
    def generate_image(self, recipe: Dict, output_path: Path) -> bool:
        """Generate image for recipe"""
        
        prompt = self.build_image_prompt(recipe)
        
        try:
            response = requests.post(
                self.base_url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "n": 1,
                    "size": "1024x1024",
                    "quality": "standard"
                },
                timeout=60
            )
            response.raise_for_status()
            
            data = response.json()
            image_url = data['data'][0]['url']
            
            # Download image
            img_response = requests.get(image_url, timeout=30)
            img_response.raise_for_status()
            
            # Convert to WebP
            image = Image.open(BytesIO(img_response.content))
            output_path.parent.mkdir(parents=True, exist_ok=True)
            image.save(output_path, 'WEBP', quality=85)
            
            self.logger.info(f"Generated image: {output_path.name}")
            return True
        
        except Exception as e:
            self.logger.error(f"Image generation failed for {recipe['id']}: {e}")
            return False
    
    def generate_images_for_recipes(
        self,
        recipes_file: Path,
        output_dir: Path,
        supermarket: str,
        weekkey: str
    ) -> Dict:
        """Generate images for all recipes"""
        
        recipes = read_json(recipes_file)
        self.logger.info(f"Generating images for {len(recipes)} recipes")
        
        manifest = {}
        success_count = 0
        
        for recipe in recipes:
            recipe_id = recipe['id']
            output_path = output_dir / f"{recipe_id}.webp"
            
            if self.generate_image(recipe, output_path):
                manifest[recipe_id] = {
                    "localPath": str(output_path.relative_to(Path.cwd())),
                    "recipe_title": recipe['title']
                }
                success_count += 1
            else:
                manifest[recipe_id] = {
                    "localPath": None,
                    "error": "generation_failed"
                }
        
        # Save manifest
        manifest_file = output_dir / f"images_manifest_{weekkey}.json"
        write_json(manifest_file, manifest)
        
        self.logger.info(f"Generated {success_count}/{len(recipes)} images")
        
        return {
            "total": len(recipes),
            "success": success_count,
            "failed": len(recipes) - success_count
        }

