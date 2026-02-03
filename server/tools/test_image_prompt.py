#!/usr/bin/env python3
"""
Test-Script für einzelne Image-Prompts

Testet einen Prompt mit OpenAI Images API und zeigt das generierte Bild.
"""

import os
import sys
from pathlib import Path

# Load .env file manually if available
def load_env_file(env_path: Path):
    """Lädt .env Datei manuell"""
    if not env_path.exists():
        return
    
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip().strip('"').strip("'")
                    if key not in os.environ:
                        os.environ[key] = value
    except Exception:
        pass

# Load .env
env_path = Path(__file__).parent.parent / '.env'
if env_path.exists():
    load_env_file(env_path)
else:
    load_env_file(Path('.env'))

try:
    from openai import OpenAI
except ImportError:
    print("❌ openai package nicht installiert")
    print("   Installiere mit: pip install openai")
    sys.exit(1)

# Prüfe API Key
api_key = os.environ.get('OPENAI_API_KEY')
if not api_key:
    print("❌ OPENAI_API_KEY nicht gesetzt")
    sys.exit(1)

client = OpenAI(api_key=api_key)

# Beispiel-Prompt für Kartoffelgratin (wie im User-Request)
test_prompt = """Ultra realistic food photography of potato gratin with onions and melted cheese. Visible ingredients: potatoes, onions, melted golden cheese, creamy baked texture. served in a ceramic baking dish. 45-degree angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look."""

print("="*70)
print("🖼️  TEST: Image Prompt Generator")
print("="*70)
print()
print(f"📝 Prompt:")
print(f"{test_prompt}")
print()
print("🔄 Generiere Bild...")
print()

try:
    response = client.images.generate(
        model="dall-e-3",
        prompt=test_prompt,
        size="1024x1024",
        quality="standard",
        n=1,
    )
    
    image_url = response.data[0].url
    
    print("✅ Bild generiert!")
    print()
    print(f"🔗 URL: {image_url}")
    print()
    print("💡 Öffne die URL im Browser, um das Bild zu sehen.")
    print()
    print("="*70)
    
except Exception as e:
    print(f"❌ Fehler: {e}")
    sys.exit(1)
