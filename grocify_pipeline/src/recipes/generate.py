"""Recipe generation with OpenAI"""
import json
import requests
import os
from pathlib import Path
from typing import List, Dict
from .prompt_builder import build_recipe_prompt
from .json_repair import validate_and_repair
from .recipe_schema import RECIPE_JSON_SCHEMA
from ..utils.io import read_json, write_json
from ..utils.json_validate import validate_against_schema
from ..utils.retry import RetryContext
from ..utils.logging import Logger


class RecipeGenerator:
    """Generate recipes using OpenAI API"""
    
    def __init__(self, api_key: str, model: str, logger: Logger):
        self.api_key = api_key
        self.model = model
        self.logger = logger
        self.base_url = "https://api.openai.com/v1/chat/completions"
    
    def generate_batch(
        self,
        offers: List[Dict],
        batch_num: int,
        batch_size: int,
        supermarket: str,
        weekkey: str
    ) -> List[Dict]:
        """Generate one batch of recipes"""
        
        prompt = build_recipe_prompt(offers, batch_num, batch_size, supermarket, weekkey)
        
        retry_ctx = RetryContext(max_retries=2)
        
        while retry_ctx.should_retry():
            try:
                response = requests.post(
                    self.base_url,
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": [
                            {"role": "system", "content": "You are a recipe generation expert. Output ONLY valid JSON arrays."},
                            {"role": "user", "content": prompt}
                        ],
                        "temperature": 0.8,
                        "max_tokens": 4000
                    },
                    timeout=60
                )
                response.raise_for_status()
                
                content = response.json()['choices'][0]['message']['content']
                
                # Validate and repair
                success, result = validate_and_repair(content)
                if not success:
                    raise ValueError(f"Invalid JSON: {result}")
                
                recipes = result if isinstance(result, list) else [result]
                
                # Validate schema
                valid_recipes = []
                for recipe in recipes:
                    is_valid, error = validate_against_schema(recipe, RECIPE_JSON_SCHEMA)
                    if is_valid:
                        valid_recipes.append(recipe)
                    else:
                        self.logger.warning(f"Recipe validation failed: {error}")
                
                if len(valid_recipes) >= batch_size * 0.7:  # Accept if 70%+ valid
                    return valid_recipes
                else:
                    raise ValueError(f"Too few valid recipes: {len(valid_recipes)}/{batch_size}")
            
            except Exception as e:
                retry_ctx.record_attempt(e)
                if not retry_ctx.should_retry():
                    self.logger.error(f"Batch {batch_num} failed after retries: {e}")
                    return []
        
        return []
    
    def generate_recipes(
        self,
        offers_file: Path,
        output_dir: Path,
        supermarket: str,
        weekkey: str,
        total_recipes: int = 75,
        batch_size: int = 20
    ) -> Dict:
        """Generate recipes in batches"""
        
        self.logger.info(f"Generating {total_recipes} recipes for {supermarket}")
        
        offers = read_json(offers_file)
        
        all_recipes = []
        batch_num = 1
        remaining = total_recipes
        
        while remaining > 0:
            current_batch_size = min(batch_size, remaining)
            self.logger.info(f"Generating batch {batch_num} ({current_batch_size} recipes)")
            
            recipes = self.generate_batch(offers, batch_num, current_batch_size, supermarket, weekkey)
            
            if recipes:
                # Save part file
                part_file = output_dir / f"recipes_{supermarket}_{weekkey}_part{batch_num}.json"
                write_json(part_file, recipes)
                self.logger.info(f"Saved {len(recipes)} recipes to {part_file.name}")
                
                all_recipes.extend(recipes)
                remaining -= len(recipes)
                batch_num += 1
            else:
                self.logger.error(f"Batch {batch_num} returned no recipes")
                break
        
        # Save merged file
        merged_file = output_dir / f"recipes_{supermarket}_{weekkey}.json"
        write_json(merged_file, all_recipes)
        self.logger.info(f"Saved {len(all_recipes)} total recipes to {merged_file.name}")
        
        return {
            "total_generated": len(all_recipes),
            "target": total_recipes,
            "batches": batch_num - 1
        }

