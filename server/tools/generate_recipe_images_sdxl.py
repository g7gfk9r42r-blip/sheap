#!/usr/bin/env python3
"""
🎨 SDXL Food Photography Pipeline für Rezept-App
=================================================

Vollständig automatisierte Bildgenerierung mit Stable Diffusion XL
- Einheitlicher Food-Look (Brand-Konsistenz)
- Deterministisch (Seed = recipe.id)
- Batch-Generierung für Skalierung
- Production-ready

Autor: Grocify Recipe Image Pipeline
Datum: 2025-01-05
"""

import json
import os
import re
import hashlib
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import argparse
from datetime import datetime

# ⸻ KONFIGURATION ⸻

# Modell-Empfehlung: SDXL Base + Refiner für maximale Qualität
SDXL_MODEL_ID = "stabilityai/stable-diffusion-xl-base-1.0"
SDXL_REFINER_ID = "stabilityai/stable-diffusion-xl-refiner-1.0"

# Alternative: Schnellere, kleinere Modelle (wenn RTX 4070/4090 verfügbar)
# SDXL_MODEL_ID = "segmind/SSD-1B"  # 50% schneller, ~90% Qualität
# SDXL_REFINER_ID = None  # Kein Refiner nötig bei SSD-1B

# VAE-Empfehlung: sdxl-vae-fp16-fix für bessere Farben
SDXL_VAE = "madebyollin/sdxl-vae-fp16-fix"

# Sampler-Empfehlung: DPM++ 2M Karras (beste Balance Qualität/Geschwindigkeit)
SAMPLER = "DPM++ 2M Karras"
STEPS = 40  # SDXL: 35-50 Steps für PERFEKTE Qualität (Food Photography, nicht als AI erkennbar)
CFG_SCALE = 7.0  # Food: 7.0-7.5 für beste Balance zwischen Detail und Natürlichkeit

# Upscaler-Empfehlung: RealESRGAN_x4plus oder 4x-UltraSharp
UPSCALER = "RealESRGAN_x4plus"  # Für 1024x1024 → 2048x2048 oder 4096x4096
UPSCALE_STEPS = 25  # Upscaling-Schritte

# Output-Dimensionen
BASE_WIDTH = 1024
BASE_HEIGHT = 1024
FINAL_WIDTH = 2048  # Optional: 4096 für Apple Review
FINAL_HEIGHT = 2048

# ⸻ GLOBAL PROMPTS (Brand-Konsistenz) ⸻

# Base-Prompt: Einheitlicher Food-Look für alle Rezepte (PERFEKT, konsistent, nicht als AI erkennbar)
GLOBAL_BASE_PROMPT = """
photorealistic food photography, authentic real food, not AI generated, not digital art,
overhead top-down view, 90-degree angle, perfectly centered,
natural daylight from window, soft diffused lighting, subtle natural shadows,
same wooden table background, rustic wooden surface, natural wood grain texture,
white ceramic plate, minimalistic composition, no unnecessary elements,
only the main dish, no side dishes or extra food items,
appetizing, vibrant natural colors, realistic food texture, authentic appearance,
shot on professional camera, high resolution, sharp focus, natural depth of field,
warm natural tones, perfectly lit, restaurant quality presentation,
"""

# Negative Prompt: Vermeidet AI-Look, Beilagen, und unrealistische Elemente (SEHR STRENG)
GLOBAL_NEGATIVE_PROMPT = """
cartoon, illustration, drawing, painting, digital art, rendered, 3D model, CGI,
AI generated, fake, synthetic, unrealistic, artificial, computer graphics,
oversaturated, overexposed, underexposed, harsh shadows, dramatic lighting,
blurry, low quality, low resolution, pixelated, grainy, noise,
hands, fingers, people, human, person, face, body parts,
text, packaging, label, brand logo, watermark, signature, letters, words,
plastic, artificial, fake food, inedible, fake texture,
perfect symmetry, too clean, sterile, commercial photography, stock photo, advertisement,
studio lighting, flash, artificial light, colored lights,
side dishes, extra food, garnish, decorative elements, unnecessary items,
multiple plates, different backgrounds, different angles, different perspectives,
different lighting, inconsistent style, different wood texture, different table,
out of focus, bokeh background, blurred background, busy background,
warm lighting, cold lighting, dramatic shadows, multiple light sources,
"""

# ⸻ PROMPT-TEMPLATE (Rezept-spezifisch) ⸻

def generate_food_prompt(recipe: Dict) -> Tuple[str, str]:
    """
    Generiert finales Prompt-Template für ein Rezept
    
    Args:
        recipe: Rezept-Dict mit title, ingredients, categories, etc.
    
    Returns:
        Tuple von (positive_prompt, negative_prompt)
    """
    title = recipe.get('title', '').strip()
    
    # Extrahiere Hauptzutaten (erste 3-5)
    ingredients_list = recipe.get('ingredients', [])
    main_ingredients = []
    
    for ing in ingredients_list[:5]:  # Maximal 5 Hauptzutaten
        if isinstance(ing, dict):
            name = ing.get('name', '')
        else:
            name = str(ing)
        
        # Bereinige Zutaten-Name (entferne Marken, Mengen)
        clean_name = re.sub(r'^\w+\s+', '', name)  # Marke entfernen
        clean_name = re.sub(r'\s+\d+[gml]?\s*$', '', clean_name)  # Menge entfernen
        clean_name = clean_name.strip()
        
        if clean_name and len(clean_name) > 2:
            main_ingredients.append(clean_name)
    
    ingredients_text = ", ".join(main_ingredients[:4])
    
    # Bestimme Zubereitungsart basierend auf Title/Categories
    categories = recipe.get('categories', [])
    tags = recipe.get('tags', [])
    all_text = f"{title} {' '.join(categories)} {' '.join(tags)}".lower()
    
    # Detaillierte Stil-Erkennung mit spezifischen Food-Photography-Keywords
    if any(word in all_text for word in ['bowl', 'salat', 'salad', 'skyr', 'yogurt', 'joghurt']):
        style = "fresh colorful bowl, mixed ingredients, vibrant colors, natural arrangement"
        surface = "white ceramic bowl, rustic wooden table, natural grain texture"
        food_keywords = "fresh berries, colorful vegetables, creamy dressing, natural arrangement"
    elif any(word in all_text for word in ['pasta', 'nudel', 'spaghetti', 'penne', 'tortellini']):
        style = "steaming pasta dish, creamy sauce, fresh herbs on top, aromatic"
        surface = "white ceramic plate, marble countertop, subtle reflections"
        food_keywords = "al dente pasta, creamy sauce, fresh basil, parmesan cheese, steam"
    elif any(word in all_text for word in ['pfanne', 'wok', 'stir', 'curry', 'reis']):
        style = "steaming hot wok dish, vibrant aromatic colors, sizzling"
        surface = "black cast iron pan, dark wooden surface, natural lighting"
        food_keywords = "steaming hot, vibrant colors, aromatic spices, fresh vegetables"
    elif any(word in all_text for word in ['pizza', 'fladen', 'flatbread']):
        style = "wood-fired pizza, melted cheese, golden bubbly crust, charred edges"
        surface = "wooden pizza peel, rustic wooden board, stone oven background"
        food_keywords = "melted mozzarella, charred crust, fresh basil, golden cheese, bubbly"
    elif any(word in all_text for word in ['sandwich', 'wrap', 'burger']):
        style = "artisan sandwich, fresh bread, layered ingredients, visible layers"
        surface = "wooden cutting board, natural wood grain, side lighting"
        food_keywords = "fresh bread, layered ingredients, melted cheese, crisp lettuce"
    elif any(word in all_text for word in ['dessert', 'kuchen', 'cake', 'torte', 'süß']):
        style = "artisan dessert, elegant plating, refined presentation, delicate"
        surface = "white ceramic plate, marble surface, soft lighting"
        food_keywords = "delicate presentation, refined plating, elegant garnish"
    elif any(word in all_text for word in ['hähnchen', 'huhn', 'chicken', 'pute', 'puten']):
        style = "tender cooked chicken, golden brown, juicy, well-seasoned"
        surface = "white ceramic plate, wooden background, natural lighting"
        food_keywords = "golden brown, juicy, tender, well-seasoned, natural herbs"
    else:
        # Default: Klassisches Plating mit realistischen Details
        style = "authentic home-cooked meal, natural plating, appetizing arrangement"
        surface = "white ceramic plate, wooden background, natural grain texture"
        food_keywords = "fresh ingredients, natural colors, appetizing arrangement"
    
    # Finale Prompt-Zusammenstellung (konkreter, realistischer)
    positive_prompt = f"{GLOBAL_BASE_PROMPT.strip()}\n" \
                     f"{title}, featuring {ingredients_text}\n" \
                     f"{style}, {surface}\n" \
                     f"{food_keywords}, authentic real food, natural imperfections, photorealistic"
    
    negative_prompt = GLOBAL_NEGATIVE_PROMPT.strip()
    
    return positive_prompt, negative_prompt

# ⸻ SEED-GENERIERUNG (Deterministisch) ⸻

def generate_seed(recipe_id: str) -> int:
    """
    Generiert deterministischen Seed aus Recipe-ID
    
    Args:
        recipe_id: Rezept-ID (z.B. "R001", "nahkauf-1")
    
    Returns:
        Integer Seed (0-2^31-1)
    """
    # Hash Recipe-ID zu Integer
    hash_obj = hashlib.md5(recipe_id.encode())
    hash_int = int(hash_obj.hexdigest(), 16)
    
    # Begrenze auf 32-bit Integer Range
    seed = hash_int % (2**31)
    
    return seed

# ⸻ BILDGENERIERUNG (SDXL) ⸻

def generate_image_sdxl(
    prompt: str,
    negative_prompt: str,
    seed: int,
    width: int = BASE_WIDTH,
    height: int = BASE_HEIGHT,
    steps: int = STEPS,
    cfg_scale: float = CFG_SCALE,
    sampler: str = SAMPLER,
    use_refiner: bool = True,
    refiner_strength: float = 0.3,
) -> Optional[bytes]:
    """
    Generiert Bild mit SDXL (via Diffusers oder Replicate HTTP API)
    
    Args:
        prompt: Positive Prompt
        negative_prompt: Negative Prompt
        seed: Deterministic Seed
        width: Bildbreite
        height: Bildhöhe
        steps: Sampling Steps
        cfg_scale: CFG Scale
        sampler: Sampler Name
        use_refiner: Ob SDXL Refiner verwendet werden soll
        refiner_strength: Refiner Strength (0.0-1.0)
    
    Returns:
        Bild als Bytes (PNG) oder None bei Fehler
    """
    try:
        # Option 1: Diffusers (Lokal mit GPU)
        try:
            from diffusers import DiffusionPipeline, AutoencoderKL
            import torch
            
            device = "cuda" if torch.cuda.is_available() else "cpu"
            
            print(f"  🎨 Generiere mit Diffusers (Device: {device})...")
            
            # Lade Base Pipeline
            pipe = DiffusionPipeline.from_pretrained(
                SDXL_MODEL_ID,
                torch_dtype=torch.float16 if device == "cuda" else torch.float32,
                use_safetensors=True,
            )
            pipe = pipe.to(device)
            
            # Lade VAE (optional, für bessere Farben)
            try:
                vae = AutoencoderKL.from_pretrained(
                    SDXL_VAE,
                    torch_dtype=torch.float16 if device == "cuda" else torch.float32,
                )
                pipe.vae = vae.to(device)
            except:
                print(f"  ⚠️ VAE {SDXL_VAE} nicht geladen, verwende Standard")
            
            # Generiere Bild
            generator = torch.Generator(device=device).manual_seed(seed)
            
            result = pipe(
                prompt=prompt,
                negative_prompt=negative_prompt,
                width=width,
                height=height,
                num_inference_steps=steps,
                guidance_scale=cfg_scale,
                generator=generator,
            )
            
            image = result.images[0]
            
            # Refiner (optional)
            if use_refiner and SDXL_REFINER_ID:
                print(f"  ✨ Wende Refiner an...")
                refiner = DiffusionPipeline.from_pretrained(
                    SDXL_REFINER_ID,
                    torch_dtype=torch.float16 if device == "cuda" else torch.float32,
                    use_safetensors=True,
                )
                refiner = refiner.to(device)
                
                image = refiner(
                    prompt=prompt,
                    image=image,
                    num_inference_steps=steps,
                    strength=refiner_strength,
                    guidance_scale=cfg_scale,
                    generator=generator,
                ).images[0]
            
            # Konvertiere zu Bytes
            from io import BytesIO
            buffer = BytesIO()
            image.save(buffer, format='PNG')
            return buffer.getvalue()
            
        except ImportError:
            # Option 2: Replicate HTTP API (Cloud, kostengünstig, Python 3.14 kompatibel)
            print(f"  🌐 Generiere mit Replicate HTTP API...")
            
            try:
                import requests
                import os
                import time
                
                api_token = os.getenv('REPLICATE_API_TOKEN')
                if not api_token:
                    raise ValueError("REPLICATE_API_TOKEN nicht gesetzt")
                
                # Replicate HTTP API Endpoints
                API_URL = "https://api.replicate.com/v1/predictions"
                MODEL_VERSION = "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b"
                
                # Erstelle Prediction
                headers = {
                    "Authorization": f"Token {api_token}",
                    "Content-Type": "application/json",
                }
                
                payload = {
                    "version": MODEL_VERSION,
                    "input": {
                        "prompt": prompt,
                        "negative_prompt": negative_prompt,
                        "width": width,
                        "height": height,
                        "num_inference_steps": steps,
                        "guidance_scale": cfg_scale,
                        "seed": seed,
                    }
                }
                
                print(f"  📤 Erstelle Prediction...")
                
                # Retry-Logic für Rate-Limits (429) mit exponentiellen Backoff
                max_retries = 10
                base_delay = 10  # Basis-Delay in Sekunden
                
                for retry in range(max_retries):
                    response = requests.post(API_URL, headers=headers, json=payload, timeout=30)
                    
                    if response.status_code == 201:
                        break  # Erfolg
                    elif response.status_code == 429:
                        # Rate-Limit: Warte und retry
                        if retry < max_retries - 1:
                            try:
                                error_data = response.json()
                                detail = error_data.get('detail', '')
                                
                                # Extrahiere Reset-Zeit aus Fehlermeldung (z.B. "resets in ~4s")
                                reset_match = re.search(r'resets in ~(\d+)s', detail)
                                if reset_match:
                                    wait_time = int(reset_match.group(1)) + 3  # +3 Sekunden Puffer
                                else:
                                    # Exponential backoff: 10s, 15s, 22s, 30s, ...
                                    wait_time = base_delay + (retry * 5)
                                
                                print(f"  ⏸️  Rate Limit (429). Warte {wait_time}s... (Retry {retry + 1}/{max_retries})")
                                time.sleep(wait_time)
                                continue
                            except Exception as parse_err:
                                # Fallback: Exponential backoff
                                wait_time = base_delay + (retry * 5)
                                print(f"  ⏸️  Rate Limit (429). Warte {wait_time}s... (Retry {retry + 1}/{max_retries})")
                                time.sleep(wait_time)
                                continue
                        else:
                            # Letzter Versuch fehlgeschlagen
                            error_msg = response.json().get('detail', response.text)
                            raise Exception(f"Rate Limit nach {max_retries} Versuchen: {error_msg}")
                    else:
                        # Anderer Fehler
                        error_msg = response.json().get('detail', response.text)
                        raise Exception(f"API Fehler ({response.status_code}): {error_msg}")
                
                # Prüfe ob erfolgreich
                if response.status_code != 201:
                    error_msg = response.json().get('detail', response.text)
                    raise Exception(f"API Fehler nach {max_retries} Versuchen ({response.status_code}): {error_msg}")
                
                prediction = response.json()
                prediction_id = prediction['id']
                prediction_url = f"{API_URL}/{prediction_id}"
                
                print(f"  ⏳ Warte auf Generierung (ID: {prediction_id})...")
                
                # Poll für Completion
                max_attempts = 120  # 10 Minuten Timeout
                attempt = 0
                
                while attempt < max_attempts:
                    response = requests.get(prediction_url, headers=headers, timeout=30)
                    
                    if response.status_code != 200:
                        raise Exception(f"Status Check Fehler ({response.status_code}): {response.text}")
                    
                    prediction = response.json()
                    status = prediction.get('status', 'unknown')
                    
                    if status == 'succeeded':
                        output_url = prediction.get('output')
                        if not output_url:
                            raise Exception("Keine Output-URL erhalten")
                        
                        # Download Bild
                        if isinstance(output_url, list) and len(output_url) > 0:
                            output_url = output_url[0]
                        
                        print(f"  📥 Lade Bild von: {output_url}")
                        image_response = requests.get(output_url, timeout=60)
                        
                        if image_response.status_code == 200:
                            return image_response.content
                        else:
                            raise Exception(f"Bild-Download Fehler ({image_response.status_code})")
                    
                    elif status == 'failed':
                        error = prediction.get('error', 'Unbekannter Fehler')
                        raise Exception(f"Generierung fehlgeschlagen: {error}")
                    
                    elif status in ['starting', 'processing']:
                        # Warte 2 Sekunden vor nächstem Check
                        time.sleep(2)
                        attempt += 1
                    else:
                        raise Exception(f"Unbekannter Status: {status}")
                
                raise Exception(f"Timeout nach {max_attempts * 2} Sekunden")
                
            except Exception as e:
                print(f"  ❌ Replicate API Fehler: {e}")
                import traceback
                traceback.print_exc()
                return None
        
    except Exception as e:
        print(f"  ❌ Fehler bei Bildgenerierung: {e}")
        import traceback
        traceback.print_exc()
        return None

# ⸻ UPSCALING ⸻

def upscale_image(image_bytes: bytes, target_width: int = FINAL_WIDTH, target_height: int = FINAL_HEIGHT) -> Optional[bytes]:
    """
    Upscaled Bild mit RealESRGAN
    
    Args:
        image_bytes: Original-Bild als Bytes
        target_width: Ziel-Breite
        target_height: Ziel-Höhe
    
    Returns:
        Upscaled Bild als Bytes oder None bei Fehler
    """
    try:
        from PIL import Image
        from io import BytesIO
        
        # Lade Bild
        image = Image.open(BytesIO(image_bytes))
        
        # Option 1: RealESRGAN (lokal)
        try:
            from realesrgan import RealESRGANer
            import torch
            
            device = "cuda" if torch.cuda.is_available() else "cpu"
            upsampler = RealESRGANer(
                scale=4,
                model_path=None,  # Lädt automatisch
                model=RealESRGANer.get_model('RealESRGAN_x4plus'),
                tile=0,
                tile_pad=10,
                pre_pad=0,
                half=device == "cuda",
            )
            
            # Upscale
            output, _ = upsampler.enhance(image, outscale=4)
            upscaled = Image.fromarray(output)
            
            # Resize auf exakte Dimensionen
            if upscaled.size != (target_width, target_height):
                upscaled = upscaled.resize((target_width, target_height), Image.LANCZOS)
            
            buffer = BytesIO()
            upscaled.save(buffer, format='PNG')
            return buffer.getvalue()
            
        except ImportError:
            # Option 2: Lanczos Upscaling (Fallback)
            print(f"  📈 Upscale mit Lanczos (Fallback)...")
            upscaled = image.resize((target_width, target_height), Image.LANCZOS)
            buffer = BytesIO()
            upscaled.save(buffer, format='PNG')
            return buffer.getvalue()
            
    except Exception as e:
        print(f"  ❌ Upscaling-Fehler: {e}")
        return None

# ⸻ HAUPT-PIPELINE ⸻

@dataclass
class RecipeImageConfig:
    """Konfiguration für Rezept-Bildgenerierung"""
    retailer: str
    output_dir: Path
    recipes_json: Path
    width: int = BASE_WIDTH
    height: int = BASE_HEIGHT
    final_width: int = FINAL_WIDTH
    final_height: int = FINAL_HEIGHT
    use_refiner: bool = True
    upscale: bool = True
    skip_existing: bool = True
    limit: Optional[int] = None

def process_retailer_recipes(config: RecipeImageConfig) -> Dict[str, any]:
    """
    Verarbeitet alle Rezepte für einen Supermarkt
    
    Args:
        config: RecipeImageConfig
    
    Returns:
        Statistik-Dict
    """
    print(f"\n{'='*60}")
    print(f"🛒 Verarbeite Rezepte für: {config.retailer.upper()}")
    print(f"{'='*60}")
    
    # Lade Rezepte
    if not config.recipes_json.exists():
        print(f"❌ Datei nicht gefunden: {config.recipes_json}")
        return {"error": "file_not_found"}
    
    with open(config.recipes_json, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    if not isinstance(recipes, list):
        print(f"❌ Ungültiges JSON-Format (erwarte Array)")
        return {"error": "invalid_format"}
    
    print(f"📚 {len(recipes)} Rezepte geladen")
    
    # Erstelle Output-Verzeichnis
    config.output_dir.mkdir(parents=True, exist_ok=True)
    
    # Statistiken
    stats = {
        "total": len(recipes),
        "processed": 0,
        "skipped": 0,
        "failed": 0,
        "recipes": [],
    }
    
    # Verarbeite Rezepte
    recipes_to_process = recipes[:config.limit] if config.limit else recipes
    
    for idx, recipe in enumerate(recipes_to_process, 1):
        recipe_id = recipe.get('id', f'unknown-{idx}')
        recipe_title = recipe.get('title', 'Unknown Recipe')
        
        print(f"\n[{idx}/{len(recipes_to_process)}] {recipe_id}: {recipe_title}")
        
        # Rate-Limit-Schutz: Warte zwischen Requests (für kostenlose Accounts: 6/Minute = max 10s/Request)
        # Mit Puffer: 11 Sekunden = sicher unter Limit
        if idx > 1:  # Nicht vor dem ersten Request
            wait_time = 11  # 11 Sekunden = sicher unter 6/Minute Limit
            print(f"  ⏸️  Rate-Limit-Schutz: Warte {wait_time}s vor nächstem Request...")
            time.sleep(wait_time)
        
        # Output-Pfad
        output_filename = f"{recipe_id}.webp"
        output_path = config.output_dir / output_filename
        
        # Skip wenn bereits vorhanden
        if config.skip_existing and output_path.exists():
            print(f"  ⏭️  Übersprungen (bereits vorhanden)")
            stats["skipped"] += 1
            continue
        
        # Generiere Prompts
        positive_prompt, negative_prompt = generate_food_prompt(recipe)
        
        # Generiere Seed
        seed = generate_seed(recipe_id)
        
        print(f"  🌱 Seed: {seed}")
        print(f"  📝 Prompt: {positive_prompt[:100]}...")
        
        # Generiere Bild
        image_bytes = generate_image_sdxl(
            prompt=positive_prompt,
            negative_prompt=negative_prompt,
            seed=seed,
            width=config.width,
            height=config.height,
            use_refiner=config.use_refiner,
        )
        
        if not image_bytes:
            print(f"  ❌ Bildgenerierung fehlgeschlagen")
            stats["failed"] += 1
            continue
        
        # Upscale (optional)
        if config.upscale:
            print(f"  📈 Upscaling auf {config.final_width}x{config.final_height}...")
            image_bytes = upscale_image(image_bytes, config.final_width, config.final_height)
            
            if not image_bytes:
                print(f"  ⚠️ Upscaling fehlgeschlagen, verwende Original")
        
        # Speichere als WebP
        try:
            from PIL import Image
            from io import BytesIO
            
            image = Image.open(BytesIO(image_bytes))
            
            # Konvertiere zu RGB falls RGBA
            if image.mode == 'RGBA':
                # Weißer Hintergrund für Transparenz
                background = Image.new('RGB', image.size, (255, 255, 255))
                background.paste(image, mask=image.split()[3])
                image = background
            elif image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Speichere als WebP (hohe Qualität, kleine Dateigröße)
            image.save(output_path, 'WEBP', quality=92, method=6)
            
            file_size = output_path.stat().st_size / 1024  # KB
            print(f"  ✅ Gespeichert: {output_path} ({file_size:.1f} KB)")
            
            stats["processed"] += 1
            stats["recipes"].append({
                "id": recipe_id,
                "title": recipe_title,
                "image_path": str(output_path.relative_to(config.output_dir.parent.parent)),
            })
            
        except Exception as e:
            print(f"  ❌ Speichern fehlgeschlagen: {e}")
            stats["failed"] += 1
    
    return stats

# ⸻ CLI ⸻

def main():
    parser = argparse.ArgumentParser(
        description="SDXL Food Photography Pipeline für Rezept-App"
    )
    parser.add_argument(
        '--retailer',
        type=str,
        required=True,
        help='Supermarkt (z.B. aldi_nord, kaufland, nahkauf)',
    )
    parser.add_argument(
        '--recipes-json',
        type=Path,
        help='Pfad zu recipes JSON (optional, Default: assets/recipes/recipes_{retailer}.json)',
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output-Verzeichnis (optional, Default: server/media/recipe_images/{retailer}/)',
    )
    parser.add_argument(
        '--limit',
        type=int,
        help='Maximale Anzahl Rezepte (optional, für Tests)',
    )
    parser.add_argument(
        '--skip-existing',
        action='store_true',
        default=False,
        help='Überspringe bereits vorhandene Bilder',
    )
    parser.add_argument(
        '--no-skip-existing',
        action='store_true',
        help='Überschreibe vorhandene Bilder (Force-Modus)',
    )
    parser.add_argument(
        '--no-refiner',
        action='store_true',
        help='Verwende keinen SDXL Refiner (schneller, etwas niedrigere Qualität)',
    )
    parser.add_argument(
        '--no-upscale',
        action='store_true',
        help='Verwende kein Upscaling (schneller)',
    )
    parser.add_argument(
        '--width',
        type=int,
        default=BASE_WIDTH,
        help=f'Bildbreite (Default: {BASE_WIDTH})',
    )
    parser.add_argument(
        '--height',
        type=int,
        default=BASE_HEIGHT,
        help=f'Bildhöhe (Default: {BASE_HEIGHT})',
    )
    parser.add_argument(
        '--final-width',
        type=int,
        default=FINAL_WIDTH,
        help=f'Finale Bildbreite nach Upscaling (Default: {FINAL_WIDTH})',
    )
    parser.add_argument(
        '--final-height',
        type=int,
        default=FINAL_HEIGHT,
        help=f'Finale Bildhöhe nach Upscaling (Default: {FINAL_HEIGHT})',
    )
    
    args = parser.parse_args()
    
    # Projekt-Root finden
    script_dir = Path(__file__).parent
    project_root = script_dir.parent.parent
    
    # Default-Pfade
    if not args.recipes_json:
        args.recipes_json = project_root / "assets" / "recipes" / f"recipes_{args.retailer}.json"
    
    if not args.output_dir:
        args.output_dir = project_root / "server" / "media" / "recipe_images" / args.retailer
    
    # Konfiguration
    # Handle skip_existing (--no-skip-existing überschreibt --skip-existing)
    skip_existing = args.skip_existing and not args.no_skip_existing
    
    config = RecipeImageConfig(
        retailer=args.retailer,
        output_dir=args.output_dir,
        recipes_json=args.recipes_json,
        width=args.width,
        height=args.height,
        final_width=args.final_width,
        final_height=args.final_height,
        use_refiner=not args.no_refiner,
        upscale=not args.no_upscale,
        skip_existing=skip_existing,
        limit=args.limit,
    )
    
    # Verarbeite Rezepte
    stats = process_retailer_recipes(config)
    
    # Zusammenfassung
    print(f"\n{'='*60}")
    print(f"✅ VERARBEITUNG ABGESCHLOSSEN")
    print(f"{'='*60}")
    print(f"📊 Statistiken:")
    print(f"   Gesamt: {stats.get('total', 0)}")
    print(f"   Verarbeitet: {stats.get('processed', 0)}")
    print(f"   Übersprungen: {stats.get('skipped', 0)}")
    print(f"   Fehlgeschlagen: {stats.get('failed', 0)}")
    print(f"{'='*60}\n")
    
    # Speichere Statistik
    stats_file = config.output_dir / f"_stats_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(stats_file, 'w', encoding='utf-8') as f:
        json.dump(stats, f, indent=2, ensure_ascii=False)
    
    print(f"📄 Statistik gespeichert: {stats_file}")

if __name__ == "__main__":
    main()

