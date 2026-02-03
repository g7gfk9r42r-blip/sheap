#!/usr/bin/env python3
"""
Verbesserte Replicate Image Generation
- Optimierte Prompts (nutzt image_prompt_builder)
- Bessere Model-Unterstützung
- Konsistente Bildgrößen (1:1, 768x768)
- Verbesserte Error-Handling
"""

import os
import sys
import time
import requests
from pathlib import Path
from typing import Tuple, Optional, Dict

# Import verbesserte Prompt-Builder
sys.path.insert(0, str(Path(__file__).parent))
try:
    from image_prompt_builder import ImagePromptBuilder
except ImportError:
    # Fallback: Einfache Prompt-Generierung
    ImagePromptBuilder = None


class ImprovedReplicateImageClient:
    """
    Verbesserte Replicate Image Client mit optimierten Prompts.
    """
    
    def __init__(
        self,
        model: str = "black-forest-labs/flux-schnell",
        api_token: Optional[str] = None,
        debug: bool = False,
    ):
        self.model = model
        self.api_token = api_token or os.getenv("REPLICATE_API_TOKEN")
        if not self.api_token:
            raise ValueError("REPLICATE_API_TOKEN environment variable required")
        
        self.base_url = "https://api.replicate.com/v1"
        self.debug = debug
        self._version_cache: Dict[str, str] = {}
        
        # Model-Einstellungen
        self.model_settings = {
            "black-forest-labs/flux-schnell": {
                "width": 768,
                "height": 768,
                "num_outputs": 1,
                "guidance_scale": 3.5,
                "num_inference_steps": 28,
            },
            "black-forest-labs/flux-dev": {
                "width": 768,
                "height": 768,
                "num_outputs": 1,
                "guidance_scale": 3.5,
                "num_inference_steps": 50,
            },
            "stability-ai/sdxl": {
                "width": 1024,
                "height": 1024,
                "num_outputs": 1,
                "guidance_scale": 7.5,
                "num_inference_steps": 30,
            },
        }
    
    def _resolve_model_version(self, model_slug: str) -> str:
        """Resolved Model-Version (mit Caching)"""
        if model_slug in self._version_cache:
            return self._version_cache[model_slug]
        
        owner, name = model_slug.split("/", 1)
        response = requests.get(
            f"{self.base_url}/models/{owner}/{name}",
            headers={"Authorization": f"Token {self.api_token}"},
        )
        
        if response.status_code != 200:
            raise ValueError(f"Model {model_slug} nicht gefunden: {response.status_code}")
        
        data = response.json()
        version_id = data.get("latest_version", {}).get("id")
        if not version_id:
            raise ValueError(f"Keine Version für {model_slug} gefunden")
        
        self._version_cache[model_slug] = version_id
        return version_id
    
    def generate_prompt(self, recipe: Dict) -> Tuple[str, str]:
        """
        Generiert optimierten Prompt (nutzt ImagePromptBuilder wenn verfügbar).
        """
        if ImagePromptBuilder:
            # Nutze verbesserte Prompt-Builder
            title = recipe.get('title') or recipe.get('name') or 'Gericht'
            
            # Extrahiere Hauptzutaten
            ingredients = []
            offer_ingredients = recipe.get('offer_ingredients', []) or []
            if offer_ingredients:
                for ing in offer_ingredients[:3]:
                    if isinstance(ing, dict):
                        name = ing.get('name') or ing.get('exact_name') or ''
                        if name:
                            ingredients.append(name)
            
            categories = recipe.get('categories', []) or []
            
            prompt, negative = ImagePromptBuilder.build_model_specific_prompt(
                model=self.model,
                title=title,
                main_ingredients=ingredients,
                categories=categories,
            )
            return prompt, negative
        else:
            # Fallback: Einfache Prompt-Generierung
            title = recipe.get('title') or recipe.get('name') or 'Gericht'
            prompt = f"ultra realistic food photography, high quality, {title}"
            negative = "text, logo, watermark, packaging"
            return prompt, negative
    
    def generate_image(
        self,
        recipe: Dict,
        output_path: Path,
        overwrite: bool = False,
    ) -> Tuple[bool, Optional[str]]:
        """
        Generiert Bild für Rezept.
        
        Returns:
            (success: bool, error_message: Optional[str])
        """
        if output_path.exists() and not overwrite:
            return True, None
        
        try:
            # Prompt generieren
            prompt, negative_prompt = self.generate_prompt(recipe)
            
            # Model-Settings
            settings = self.model_settings.get(self.model, {
                "width": 768,
                "height": 768,
                "num_outputs": 1,
                "guidance_scale": 3.5,
                "num_inference_steps": 28,
            })
            
            # Version resolven
            version_id = self._resolve_model_version(self.model)
            
            # Payload für Replicate API
            payload = {
                "version": version_id,
                "input": {
                    "prompt": prompt,
                    "negative_prompt": negative_prompt,
                    **settings,
                },
            }
            
            if self.debug:
                print(f"[DEBUG] Prompt: {prompt[:100]}...")
                print(f"[DEBUG] Model: {self.model}, Version: {version_id}")
            
            # Prediction erstellen
            headers = {
                "Authorization": f"Token {self.api_token}",
                "Content-Type": "application/json",
            }
            
            response = requests.post(
                f"{self.base_url}/predictions",
                headers=headers,
                json=payload,
                timeout=30,
            )
            
            if response.status_code not in [200, 201]:
                error_msg = response.text
                if self.debug:
                    print(f"[DEBUG] Error: {error_msg}")
                return False, f"API Error {response.status_code}: {error_msg[:200]}"
            
            prediction = response.json()
            prediction_id = prediction.get("id")
            
            if not prediction_id:
                return False, "Keine prediction_id in Response"
            
            # Warte auf Completion
            image_url = self._wait_for_prediction(prediction_id, headers)
            
            if not image_url:
                return False, "Prediction failed oder timeout"
            
            # Bild herunterladen
            self._download_image(image_url, output_path)
            
            return True, None
            
        except Exception as e:
            error_msg = str(e)
            if self.debug:
                print(f"[DEBUG] Exception: {error_msg}")
            return False, error_msg
    
    def _wait_for_prediction(
        self,
        prediction_id: str,
        headers: Dict,
        max_wait: int = 300,
    ) -> Optional[str]:
        """Wartet auf Prediction-Completion"""
        start_time = time.time()
        
        while time.time() - start_time < max_wait:
            response = requests.get(
                f"{self.base_url}/predictions/{prediction_id}",
                headers=headers,
                timeout=10,
            )
            
            if response.status_code != 200:
                return None
            
            prediction = response.json()
            status = prediction.get("status")
            
            if status == "succeeded":
                output = prediction.get("output")
                if isinstance(output, list) and output:
                    return output[0]
                elif isinstance(output, str):
                    return output
                return None
            
            if status in ["failed", "canceled"]:
                return None
            
            # Warte 2 Sekunden
            time.sleep(2)
        
        return None
    
    def _download_image(self, url: str, output_path: Path) -> None:
        """Lädt Bild herunter und speichert es"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        
        with open(output_path, 'wb') as f:
            f.write(response.content)


# Beispiel-Verwendung
if __name__ == "__main__":
    client = ImprovedReplicateImageClient(
        model="black-forest-labs/flux-schnell",
        debug=True,
    )
    
    recipe = {
        "title": "Hähnchen-Minutensteaks mit Avocado-Tomaten-Salsa",
        "categories": ["High Protein", "Low Carb"],
        "offer_ingredients": [
            {"name": "Hähnchen-Minutenschnitzel"},
            {"name": "Avocados"},
            {"name": "Tomaten"},
        ],
    }
    
    prompt, negative = client.generate_prompt(recipe)
    print("=== PROMPT ===")
    print(prompt)
    print("\n=== NEGATIVE PROMPT ===")
    print(negative)

