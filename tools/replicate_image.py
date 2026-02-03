#!/usr/bin/env python3
"""
Replicate API Image Generator
Generiert Bilder via Replicate API
WICHTIG: Replicate API erwartet "version" (Hash), NICHT "model"!
"""

import os
import requests
import time
from pathlib import Path
from typing import Optional, Tuple, Dict


class ReplicateImageClient:
    """Client für Replicate Image Generation API"""
    
    def __init__(self, api_token: Optional[str] = None, model: str = "black-forest-labs/flux-schnell"):
        """
        Args:
            api_token: Replicate API Token (oder aus ENV REPLICATE_API_TOKEN)
            model: Model-Slug im Format "owner/name" (z.B. "black-forest-labs/flux-schnell")
        """
        self.api_token = api_token or os.getenv('REPLICATE_API_TOKEN')
        if not self.api_token:
            raise ValueError("REPLICATE_API_TOKEN environment variable is required")
        
        self.base_url = "https://api.replicate.com/v1"
        self.model_slug = model  # z.B. "black-forest-labs/flux-schnell" - wird zu version_hash aufgelöst
        self.timeout = 300  # 5 Minuten
        self.max_retries_rate_limit = 10  # Max 10 Versuche bei Rate Limit
        self.max_retries_other = 3  # Max 3 Versuche bei anderen Fehlern
        self.base_delay = 2.0  # Sekunden
        self.max_backoff_delay = 120.0  # Max 120 Sekunden Backoff (erhöht)
        self.debug = os.getenv('DEBUG_IMAGES') == '1'
        
        # Version Cache: model_slug -> version_hash
        self._version_cache: Dict[str, str] = {}
    
    def _resolve_model_to_version(self) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Löst Model-Slug zu Version-Hash auf.
        Returns: (success, version_hash, error_message)
        """
        # Prüfe Cache
        if self.model_slug in self._version_cache:
            return True, self._version_cache[self.model_slug], None
        
        try:
            # Parse owner/name
            if '/' not in self.model_slug:
                return False, None, f"Invalid model slug format: {self.model_slug} (expected 'owner/name')"
            
            owner, name = self.model_slug.split('/', 1)
            
            # GET /v1/models/{owner}/{name}
            headers = {'Authorization': f'Token {self.api_token}'}
            url = f"{self.base_url}/models/{owner}/{name}"
            
            if self.debug:
                print(f"[DEBUG] Resolving model: GET {url}")
            
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 404:
                return False, None, f"Model not found: {self.model_slug}"
            elif response.status_code != 200:
                error_data = response.json() if response.content else {}
                error_msg = error_data.get('detail', f'HTTP {response.status_code}')
                return False, None, f"Failed to resolve model: {error_msg}"
            
            model_data = response.json()
            
            # Extrahiere latest_version.id
            latest_version = model_data.get('latest_version')
            if not latest_version:
                return False, None, f"No latest_version found for {self.model_slug}"
            
            version_hash = latest_version.get('id')
            if not version_hash:
                return False, None, f"No version id found in latest_version for {self.model_slug}"
            
            # Cache speichern
            self._version_cache[self.model_slug] = version_hash
            
            if self.debug:
                print(f"[DEBUG] Resolved {self.model_slug} -> version {version_hash}")
            
            return True, version_hash, None
            
        except requests.exceptions.RequestException as e:
            return False, None, f"Network error resolving model: {str(e)}"
        except Exception as e:
            return False, None, f"Unexpected error resolving model: {str(e)}"
    
    def check_connection(self) -> Tuple[bool, Optional[str]]:
        """Prüft ob Replicate API erreichbar ist"""
        try:
            headers = {'Authorization': f'Token {self.api_token}'}
            response = requests.get(
                f"{self.base_url}/models",
                headers=headers,
                timeout=10
            )
            if response.status_code == 200:
                return True, None
            elif response.status_code == 401:
                return False, "Invalid API token"
            return False, f"HTTP {response.status_code}"
        except requests.exceptions.ConnectionError:
            return False, "Connection refused (Replicate API nicht erreichbar)"
        except Exception as e:
            return False, f"Unexpected error: {str(e)}"
    
    def generate_prompt(self, recipe: dict) -> Tuple[str, str]:
        """
        Generiert optimierten Prompt und Negative Prompt für das Rezept.
        Nutzt verbesserte Prompt-Strategie für bessere Bildqualität.
        Berücksichtigt ALLE Zutaten: Angebotszutaten, Extra-Zutaten, Basiszutaten.
        """
        title = recipe.get('title') or recipe.get('name') or 'Gericht'
        
        # Sammle ALLE Zutaten (nicht nur die ersten 3!)
        all_ingredient_names = []
        
        # 1. Angebotszutaten (mehrere mögliche Formate)
        # Format A: offer_ingredients / ingredients_offers (separates Feld)
        offer_ingredients = recipe.get('offer_ingredients', []) or recipe.get('ingredients_offers', []) or []
        if isinstance(offer_ingredients, list):
            for ing in offer_ingredients:
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('exact_name') or ing.get('title') or ''
                else:
                    name = str(ing)
                if name and name.strip():
                    all_ingredient_names.append(name.strip())
        
        # Format B: ingredients mit from_offer: true (kombiniertes Feld)
        ingredients_list = recipe.get('ingredients', []) or []
        if isinstance(ingredients_list, list):
            for ing in ingredients_list:
                if isinstance(ing, dict):
                    # Prüfe ob from_offer vorhanden ist (kann true/false/fehlen sein)
                    from_offer = ing.get('from_offer', False)
                    if from_offer:  # Nur Angebotszutaten hier
                        name = ing.get('name') or ing.get('title') or ''
                        if name and name.strip():
                            all_ingredient_names.append(name.strip())
        
        # 2. Extra-Zutaten (extra_ingredients - nicht im Angebot)
        extra_ingredients = recipe.get('extra_ingredients', []) or recipe.get('extraIngredients', []) or []
        if isinstance(extra_ingredients, list):
            for ing in extra_ingredients:
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('title') or ''
                else:
                    name = str(ing)
                if name and name.strip():
                    all_ingredient_names.append(name.strip())
        
        # 3. Basiszutaten (basic_ingredients / basis ingredients - Salz, Pfeffer, Öl, etc.)
        basic_ingredients = recipe.get('basic_ingredients', []) or recipe.get('basis_ingredients', []) or []
        if isinstance(basic_ingredients, list):
            for ing in basic_ingredients:
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('title') or ''
                else:
                    name = str(ing)
                if name and name.strip():
                    all_ingredient_names.append(name.strip())
        
        # 4. Fallback: Alle ingredients (wenn keine separaten Felder vorhanden)
        # Nur wenn noch keine Zutaten gefunden wurden
        if not all_ingredient_names and isinstance(ingredients_list, list):
            for ing in ingredients_list:
                if isinstance(ing, dict):
                    name = ing.get('name') or ing.get('title') or str(ing)
                else:
                    name = str(ing)
                if name and name.strip():
                    all_ingredient_names.append(name.strip())
        
        # Entferne Duplikate (behalte Reihenfolge)
        seen = set()
        unique_ingredients = []
        for ing in all_ingredient_names:
            ing_lower = ing.lower().strip()
            if ing_lower and ing_lower not in seen:
                seen.add(ing_lower)
                unique_ingredients.append(ing)
        
        # Für Prompt: Top 5-7 wichtigste Zutaten (mehr Details = besseres Bild)
        # Priorität: Angebotszutaten > Extra-Zutaten > Basiszutaten
        prompt_ingredients = unique_ingredients[:7] if len(unique_ingredients) > 7 else unique_ingredients
        
        # Kategorien für Style-Hinweise
        categories = recipe.get('categories', []) or []
        
        # Verbesserter Prompt (basierend auf image_prompt_builder.py)
        prompt_parts = [
            "ultra realistic professional food photography",
            "high quality, sharp focus, 8k resolution",
            "appetizing, mouth-watering presentation",
            "natural lighting, soft shadows, studio quality",
            "modern food styling, restaurant-quality plating",
            f"dish: {title}",
        ]
        
        # Zutaten zum Prompt hinzufügen (alle wichtigen Zutaten)
        if prompt_ingredients:
            ingredients_text = ", ".join(prompt_ingredients)
            prompt_parts.append(f"ingredients visible: {ingredients_text}")
            # Wenn viele Zutaten: Hinweis auf Vielfalt
            if len(unique_ingredients) > 7:
                prompt_parts.append("variety of fresh ingredients, colorful dish")
        
        # Kategorie-basierte Style-Hinweise
        category_keywords = {
            "high protein": "muscular, protein-rich, fitness",
            "low carb": "clean, fresh, minimal carbs",
            "vegetarian": "fresh vegetables, colorful, vibrant",
            "quick": "fast, simple, minimal preparation",
        }
        
        category_styles = []
        if categories:
            for cat in categories:
                cat_lower = str(cat).lower()
                for key, style in category_keywords.items():
                    if key in cat_lower:
                        category_styles.append(style)
        
        if category_styles:
            prompt_parts.append(f"style: {', '.join(category_styles[:2])}")
        
        # Perspektive & Komposition
        prompt_parts.extend([
            "overhead or 45-degree angle view",
            "centered composition, rule of thirds",
            "neutral background, clean presentation",
            "shallow depth of field, bokeh background",
            "Instagram-worthy, social media ready",
            "magazine cover quality",
        ])
        
        prompt = ", ".join(prompt_parts)
        
        # Verbesserter Negative Prompt
        negative_prompt = (
            "text, watermark, logo, packaging, labels, "
            "blurry, lowres, deformed, ugly, bad anatomy, "
            "hands, people, writing, letters, numbers, "
            "plastic wrap, containers, boxes, "
            "unappetizing, burnt, overcooked, "
            "artificial colors, oversaturated, "
            "bad lighting, harsh shadows, "
            "cluttered, messy, unprofessional"
        )
        
        return prompt, negative_prompt
    
    def _calculate_backoff(self, attempt: int, base: Optional[float] = None) -> float:
        """
        Berechnet exponential backoff delay, capped at max_backoff_delay.
        Für Rate Limits: Startet mit längeren Delays.
        """
        if base is None:
            base = self.base_delay
        delay = min(base * (2 ** attempt), self.max_backoff_delay)
        return delay
    
    def _get_retry_after(self, response: requests.Response) -> Optional[float]:
        """Extrahiert Retry-After Header oder aus Error-Message (falls vorhanden)"""
        # Prüfe Retry-After Header
        retry_after = response.headers.get('Retry-After')
        if retry_after:
            try:
                seconds = float(retry_after)
                return max(seconds, 5.0)  # Mindestens 5 Sekunden
            except ValueError:
                pass
        
        # Prüfe Error-Message für "resets in ~Xs"
        try:
            error_data = response.json() if response.content else {}
            error_detail = str(error_data.get('detail', ''))
            # Suche nach "resets in ~30s" Pattern
            import re
            match = re.search(r'resets in ~?(\d+)s?', error_detail, re.IGNORECASE)
            if match:
                seconds = float(match.group(1))
                return max(seconds, 5.0)
        except:
            pass
        
        return None
    
    def generate_image(self, recipe: dict, output_path: Path, overwrite: bool = False, throttle_ms: int = 0) -> Tuple[bool, Optional[str]]:
        """
        Generiert ein Bild für ein Rezept via Replicate API.
        Returns: (success, error_message)
        """
        # Prüfe ob Bild bereits existiert
        if output_path.exists() and not overwrite:
            return True, None  # Skip
        
        # Erstelle Ordner falls nicht vorhanden
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Löse Model zu Version auf
        success, version_hash, error_msg = self._resolve_model_to_version()
        if not success:
            return False, f"Failed to resolve model version: {error_msg}"
        
        # Generiere Prompt
        prompt, negative_prompt = self.generate_prompt(recipe)
        
        if self.debug:
            print(f"[DEBUG] resolved_version={version_hash} model={self.model_slug} prompt_len={len(prompt)} steps=30")
        
        # Rate-Limit-Tracking
        rate_limit_retries = 0
        other_retries = 0
        
        while True:
            # Prüfe Retry-Limits
            if rate_limit_retries >= self.max_retries_rate_limit:
                return False, f"Rate limit exceeded after {self.max_retries_rate_limit} retries"
            if other_retries >= self.max_retries_other:
                return False, f"Max retries ({self.max_retries_other}) exceeded"
            
            # Prüfe Connection (nur beim ersten Versuch)
            if rate_limit_retries == 0 and other_retries == 0:
                is_connected, error_msg = self.check_connection()
                if not is_connected:
                    return False, f"Replicate API nicht erreichbar: {error_msg}"
            
            try:
                # Backoff bei Retries
                total_attempts = rate_limit_retries + other_retries
                
                if total_attempts > 0:
                    # Retry: Bei Rate Limit Retries längeres Backoff
                    if rate_limit_retries > 0:
                        delay = self._calculate_backoff(rate_limit_retries - 1, base=5.0)  # Start mit 5s bei Rate Limit
                    else:
                        delay = self._calculate_backoff(total_attempts - 1)
                    if self.debug:
                        print(f"[DEBUG] Retry attempt {total_attempts}, waiting {delay:.1f}s")
                    time.sleep(delay)
                
                # Erstelle Prediction
                headers = {
                    'Authorization': f'Token {self.api_token}',
                    'Content-Type': 'application/json',
                }
                
                # WICHTIG: Replicate API erwartet "version" (Hash), NICHT "model"!
                payload = {
                    'version': version_hash,
                    'input': {
                        'prompt': prompt,
                        'num_outputs': 1,
                        'aspect_ratio': '1:1',
                        'output_format': 'png',
                        'output_quality': 90,
                    }
                }
                
                if self.debug:
                    print(f"[DEBUG] POST /v1/predictions with version={version_hash}")
                
                # POST Request: Create Prediction
                response = requests.post(
                    f"{self.base_url}/predictions",
                    headers=headers,
                    json=payload,
                    timeout=30
                )
                
                if self.debug:
                    print(f"[DEBUG] Response status={response.status_code}")
                    if response.status_code not in [200, 201]:
                        try:
                            error_body = response.json()
                            error_detail = error_body.get('detail', 'No detail')
                            # Gekürzte Error-Ausgabe (max 200 Zeichen)
                            error_preview = str(error_detail)[:200]
                            print(f"[DEBUG] Error body: {error_preview}")
                        except:
                            print(f"[DEBUG] Error body: <non-JSON>")
                
                # Rate Limit Handling (429 oder "throttled"/"rate limit" im Text)
                is_rate_limit = False
                if response.status_code == 429:
                    is_rate_limit = True
                elif response.status_code not in [200, 201]:
                    error_data = response.json() if response.content else {}
                    error_msg_text = str(error_data.get('detail', '')).lower()
                    if 'throttled' in error_msg_text or 'rate limit' in error_msg_text:
                        is_rate_limit = True
                
                if is_rate_limit:
                    rate_limit_retries += 1
                    error_data = response.json() if response.content else {}
                    error_msg = error_data.get('detail', 'Rate limit exceeded')
                    
                    # Prüfe Retry-After Header
                    retry_after = self._get_retry_after(response)
                    if retry_after and self.debug:
                        print(f"[DEBUG] Rate limit: {error_msg}, Retry-After: {retry_after}s")
                    
                    if self.debug:
                        print(f"[DEBUG] Rate limit: {error_msg}, retry {rate_limit_retries}/{self.max_retries_rate_limit}")
                        if retry_after:
                            print(f"[DEBUG] Waiting {retry_after}s (from Retry-After header)")
                    
                    # Verwende Retry-After falls vorhanden, sonst Backoff
                    if retry_after:
                        time.sleep(retry_after)
                    # Backoff wird in der nächsten Iteration angewendet
                    
                    continue  # Retry mit Backoff
                
                # Andere HTTP-Fehler
                if response.status_code not in [200, 201]:
                    other_retries += 1
                    error_data = response.json() if response.content else {}
                    error_msg = error_data.get('detail', f'HTTP {response.status_code}')
                    if self.debug:
                        print(f"[DEBUG] HTTP error {response.status_code}: {error_msg}")
                    
                    if other_retries < self.max_retries_other:
                        continue  # Retry
                    return False, f"Replicate API error: {error_msg}"
                
                prediction = response.json()
                prediction_id = prediction.get('id')
                if not prediction_id:
                    other_retries += 1
                    if other_retries < self.max_retries_other:
                        continue
                    return False, "No prediction ID in response"
                
                # Poll for result
                max_wait = 300  # 5 Minuten
                wait_time = 0
                poll_interval = 2
                
                if self.debug:
                    print(f"[DEBUG] Polling prediction {prediction_id}")
                
                while wait_time < max_wait:
                    time.sleep(poll_interval)
                    wait_time += poll_interval
                    
                    status_response = requests.get(
                        f"{self.base_url}/predictions/{prediction_id}",
                        headers=headers,
                        timeout=10
                    )
                    
                    if status_response.status_code != 200:
                        error_data = status_response.json() if status_response.content else {}
                        error_msg = error_data.get('detail', f'HTTP {status_response.status_code}')
                        if self.debug:
                            print(f"[DEBUG] Status check failed: {error_msg}")
                        other_retries += 1
                        if other_retries < self.max_retries_other:
                            break  # Retry outer loop
                        return False, f"Failed to check prediction status: HTTP {status_response.status_code}"
                    
                    status_data = status_response.json()
                    status = status_data.get('status')
                    
                    if status == 'succeeded':
                        # Bild herunterladen
                        output = status_data.get('output')
                        if not output:
                            other_retries += 1
                            if other_retries < self.max_retries_other:
                                break  # Retry
                            return False, "No output in prediction result"
                        
                        # Output kann URL oder Liste von URLs sein
                        image_url = None
                        if isinstance(output, str):
                            image_url = output
                        elif isinstance(output, list) and len(output) > 0:
                            image_url = output[0]
                        
                        if not image_url:
                            other_retries += 1
                            if other_retries < self.max_retries_other:
                                break  # Retry
                            return False, "No image URL in prediction output"
                        
                        if self.debug:
                            print(f"[DEBUG] Downloading image from {image_url}")
                        
                        # Download Image
                        img_response = requests.get(image_url, timeout=60)
                        if img_response.status_code != 200:
                            other_retries += 1
                            if other_retries < self.max_retries_other:
                                break  # Retry
                            return False, f"Failed to download image: HTTP {img_response.status_code}"
                        
                        # Speichere als PNG
                        output_path.parent.mkdir(parents=True, exist_ok=True)
                        with open(output_path, 'wb') as f:
                            f.write(img_response.content)
                        
                        if self.debug:
                            print(f"[DEBUG] Image saved to {output_path}")
                        
                        # Throttle wird beim nächsten Request (proaktiv) angewendet
                        # Kein zusätzliches Throttling hier nötig
                        return True, None
                    
                    elif status == 'failed':
                        error = status_data.get('error', 'Unknown error')
                        if self.debug:
                            print(f"[DEBUG] Prediction failed: {error}")
                        other_retries += 1
                        if other_retries < self.max_retries_other:
                            break  # Retry
                        return False, f"Prediction failed: {error}"
                    
                    elif status in ['starting', 'processing']:
                        continue  # Weiter warten
                    else:
                        if self.debug:
                            print(f"[DEBUG] Unknown prediction status: {status}")
                        other_retries += 1
                        if other_retries < self.max_retries_other:
                            break  # Retry
                        return False, f"Unknown prediction status: {status}"
                
                # Timeout - retry
                if self.debug:
                    print(f"[DEBUG] Prediction timeout after {max_wait}s")
                other_retries += 1
                if other_retries < self.max_retries_other:
                    continue  # Retry
                return False, "Prediction timeout (5 minutes)"
            
            except requests.exceptions.Timeout:
                if self.debug:
                    print(f"[DEBUG] Request timeout")
                other_retries += 1
                if other_retries < self.max_retries_other:
                    continue
                return False, "Request timeout"
            except requests.exceptions.ConnectionError:
                if self.debug:
                    print(f"[DEBUG] Connection error")
                other_retries += 1
                if other_retries < self.max_retries_other:
                    delay = self._calculate_backoff(other_retries - 1)
                    time.sleep(delay)
                    continue
                return False, "Connection refused (Replicate API nicht erreichbar)"
            except Exception as e:
                if self.debug:
                    print(f"[DEBUG] Unexpected error: {str(e)}")
                other_retries += 1
                if other_retries < self.max_retries_other:
                    continue
                return False, f"Unexpected error: {str(e)}"
        
        return False, "Max retries exceeded"
