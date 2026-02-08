"""Image generation for recipes"""

import logging
from typing import List, Dict, Any, Optional
from pathlib import Path

logger = logging.getLogger(__name__)


class ImageGenerator:
    """Generate images for recipes"""
    
    def __init__(self, supermarket: str, week_key: str):
        self.supermarket = supermarket
        self.week_key = week_key
    
    def create_image_jobs(self, recipes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Create image generation jobs for recipes.
        
        Returns:
            List of image job dicts
        """
        jobs = []
        
        for recipe in recipes:
            recipe_id = recipe.get("id") or recipe.get("recipeId", "")
            title = recipe.get("shortTitle") or recipe.get("title", "")
            ingredients = recipe.get("ingredients", [])
            
            # Extract main ingredients
            main_ingredients = [ing.get("name", "") for ing in ingredients[:5]]
            
            # Create prompt
            prompt = self._create_image_prompt(title, main_ingredients)
            
            jobs.append({
                "recipeId": recipe_id,
                "imagePrompt": prompt,
                "aspectRatio": "1:1",
                "style": "photorealistic",
                "lighting": "natural",
            })
        
        return jobs
    
    def _create_image_prompt(
        self, 
        title: str, 
        ingredients: List[str]
    ) -> str:
        """Create image generation prompt"""
        ingredient_list = ", ".join(ingredients[:3])
        
        prompt = (
            f"Photorealistic top-down food photography of {title} "
            f"with {ingredient_list}. "
            f"Natural lighting, professional food styling, "
            f"appetizing presentation, no text, 1:1 aspect ratio, "
            f"high quality, restaurant quality"
        )
        
        return prompt
    
    def generate_with_dalle(
        self, 
        prompt: str, 
        api_key: Optional[str] = None
    ) -> Optional[str]:
        """
        Generate image using DALL-E (if API key provided).
        
        Returns:
            Image URL or None
        """
        if not api_key:
            logger.debug("No DALL-E API key provided, skipping generation")
            return None
        
        try:
            from openai import OpenAI
            client = OpenAI(api_key=api_key)
            
            response = client.images.generate(
                model="dall-e-3",
                prompt=prompt,
                size="1024x1024",
                quality="standard",
                n=1,
            )
            
            image_url = response.data[0].url
            logger.info(f"Generated image: {image_url}")
            return image_url
            
        except Exception as e:
            logger.error(f"DALL-E generation failed: {e}")
            return None

