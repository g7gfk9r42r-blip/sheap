#!/usr/bin/env python3
"""
Stable Diffusion Image Generator
Nutzt Automatic1111 WebUI API
"""

import requests
import base64
import time
from pathlib import Path
from typing import Optional, Tuple


class StableDiffusionImageClient:
    """Client für Stable Diffusion (Automatic1111) Image Generation API"""
    
    def __init__(self, api_url: str = "http://127.0.0.1:7860"):
        self.api_url = api_url.rstrip('/')
        self.txt2img_url = f"{self.api_url}/sdapi/v1/txt2img"
        self.timeout = 300  # 5 Minuten für SD
    
    def check_connection(self) -> Tuple[bool, Optional[str]]:
        """Prüft ob SD erreichbar ist"""
        try:
            response = requests.get(f"{self.api_url}/sdapi/v1/progress", timeout=5)
            if response.status_code == 200:
                return True, None
            return False, f"HTTP {response.status_code}"
        except requests.exceptions.ConnectionError:
            return False, "Connection refused (SD nicht erreichbar)"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"
    
    def generate_prompt(self, recipe: dict) -> Tuple[str, str]:
        """Generiert Prompt und Negative Prompt für das Rezept"""
        title = recipe.get('title') or recipe.get('name') or 'Gericht'
        
        # Extrahiere Top 3 Zutaten
        ingredients = []
        ingredients_list = recipe.get('ingredients', []) or []
        
        if isinstance(ingredients_list, list):
            for ing in ingredients_list[:3]:
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('title') or str(ing)
                else:
                    name = str(ing)
                if name and name.strip():
                    ingredients.append(name.strip())
        
        # Prompt
        prompt_parts = ["ultra realistic food photography", "overhead", "natural light", 
                       "sharp focus", "appetizing plating"]
        prompt_parts.append(f"dish: {title}")
        
        if ingredients:
            ingredients_text = ", ".join(ingredients[:3])
            prompt_parts.append(f"ingredients: {ingredients_text}")
        
        prompt = ", ".join(prompt_parts)
        
        # Negative Prompt
        negative_prompt = "text, watermark, logo, packaging, labels, blurry, lowres, deformed"
        
        return prompt, negative_prompt
    
    def generate_image(self, recipe: dict, output_path: Path, overwrite: bool = False) -> Tuple[bool, Optional[str]]:
        """
        Generiert ein Bild für ein Rezept via Stable Diffusion.
        Returns: (success, error_message)
        """
        # Prüfe ob Bild bereits existiert
        if output_path.exists() and not overwrite:
            return True, None  # Skip
        
        # Erstelle Ordner falls nicht vorhanden
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Generiere Prompt
        prompt, negative_prompt = self.generate_prompt(recipe)
        
        # Request Payload
        payload = {
            "prompt": prompt,
            "negative_prompt": negative_prompt,
            "steps": 28,
            "cfg_scale": 7,
            "sampler_name": "DPM++ 2M Karras",
            "width": 768,
            "height": 768,
        }
        
        try:
            # Prüfe Connection
            is_connected, error_msg = self.check_connection()
            if not is_connected:
                return False, f"SD nicht erreichbar: {error_msg}"
            
            # POST Request
            response = requests.post(
                self.txt2img_url,
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code != 200:
                return False, f"SD API error: HTTP {response.status_code} - {response.text[:200]}"
            
            result = response.json()
            
            if 'images' not in result or not result['images']:
                return False, "No image data in SD response"
            
            # Base64 decode und speichere
            image_data = base64.b64decode(result['images'][0])
            
            with open(output_path, 'wb') as f:
                f.write(image_data)
            
            return True, None
        
        except requests.exceptions.Timeout:
            return False, "Request timeout (SD zu langsam)"
        except requests.exceptions.ConnectionError:
            return False, "Connection refused (SD nicht erreichbar)"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"

