#!/usr/bin/env python3
"""
OpenAI Image API Client
"""

import os
import time
import requests
from pathlib import Path
from typing import Optional, Tuple


class OpenAIImageClient:
    """Client für OpenAI Image Generation API"""
    
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv('OPENAI_API_KEY')
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
        
        self.base_url = "https://api.openai.com/v1/images/generations"
        self.max_retries = 3
        self.base_delay = 1.0  # Sekunden
    
    def generate_prompt(self, recipe: dict) -> str:
        """Generiert einen Prompt für das Rezept-Bild"""
        title = recipe.get('title', 'Gericht')
        
        # Extrahiere Zutaten
        ingredients = []
        
        # Prüfe verschiedene mögliche Felder
        ingredients_list = recipe.get('ingredients', []) or []
        if isinstance(ingredients_list, list):
            for ing in ingredients_list[:8]:  # Max 8 Zutaten
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('title') or str(ing)
                else:
                    name = str(ing)
                if name and name.strip():
                    ingredients.append(name.strip())
        
        # Falls keine Ingredients gefunden, nutze title
        if not ingredients:
            # Versuche aus title zu extrahieren
            title_words = title.split()
            ingredients = title_words[:5]
        
        ingredients_text = ', '.join(ingredients[:8])
        
        # Prompt zusammenstellen
        prompt = (
            f"Fotorealistisches Food-Foto von {title}"
        )
        
        if ingredients_text:
            prompt += f" mit {ingredients_text}"
        
        prompt += (
            ". Top-down oder 45-Grad-Perspektive, natürliches Tageslicht, "
            "appetitliche Darstellung, neutraler Hintergrund, "
            "hohe Qualität, ohne Text, ohne Logos, ohne Verpackungen, "
            "professionelle Food-Fotografie."
        )
        
        return prompt
    
    def generate_image(self, recipe: dict, output_path: Path, overwrite: bool = False) -> Tuple[bool, Optional[str]]:
        """
        Generiert ein Bild für ein Rezept.
        Returns: (success, error_message)
        """
        # Prüfe ob Bild bereits existiert
        if output_path.exists() and not overwrite:
            return True, None  # Skip
        
        # Erstelle Ordner falls nicht vorhanden
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Generiere Prompt
        prompt = self.generate_prompt(recipe)
        
        # Request mit Retry-Logik
        for attempt in range(self.max_retries):
            try:
                headers = {
                    'Authorization': f'Bearer {self.api_key}',
                    'Content-Type': 'application/json',
                }
                
                payload = {
                    'model': 'dall-e-3',
                    'prompt': prompt,
                    'n': 1,
                    'size': '1024x1024',
                    'quality': 'standard',
                    'response_format': 'url',
                }
                
                response = requests.post(
                    self.base_url,
                    headers=headers,
                    json=payload,
                    timeout=60
                )
                
                if response.status_code == 200:
                    data = response.json()
                    
                    if 'data' in data and len(data['data']) > 0:
                        image_url = data['data'][0]['url']
                        
                        # Lade Bild herunter
                        img_response = requests.get(image_url, timeout=30)
                        if img_response.status_code == 200:
                            # Speichere als PNG
                            output_path.parent.mkdir(parents=True, exist_ok=True)
                            with open(output_path, 'wb') as f:
                                f.write(img_response.content)
                            
                            return True, None
                        else:
                            error_msg = f"Failed to download image: HTTP {img_response.status_code}"
                            if attempt < self.max_retries - 1:
                                continue
                            return False, error_msg
                    else:
                        error_msg = "No image data in response"
                        if attempt < self.max_retries - 1:
                            continue
                        return False, error_msg
                
                elif response.status_code == 429:
                    # Rate limit - exponential backoff
                    delay = self.base_delay * (2 ** attempt)
                    if attempt < self.max_retries - 1:
                        time.sleep(delay)
                        continue
                    return False, "Rate limit exceeded after retries"
                
                else:
                    error_msg = f"API error: HTTP {response.status_code}"
                    try:
                        error_data = response.json()
                        if 'error' in error_data:
                            error_msg += f" - {error_data['error'].get('message', '')}"
                    except:
                        pass
                    
                    if attempt < self.max_retries - 1:
                        delay = self.base_delay * (2 ** attempt)
                        time.sleep(delay)
                        continue
                    return False, error_msg
            
            except requests.exceptions.Timeout:
                error_msg = "Request timeout"
                if attempt < self.max_retries - 1:
                    delay = self.base_delay * (2 ** attempt)
                    time.sleep(delay)
                    continue
                return False, error_msg
            
            except Exception as e:
                error_msg = f"Unexpected error: {str(e)}"
                if attempt < self.max_retries - 1:
                    delay = self.base_delay * (2 ** attempt)
                    time.sleep(delay)
                    continue
                return False, error_msg
        
        return False, "Max retries exceeded"

