"""Test script for OpenAI API connection and Vision capabilities."""
from __future__ import annotations

import os
import base64
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("❌ openai package not installed. Run: pip install openai")
    exit(1)


def load_env():
    """Load environment variables from .env file."""
    env_path = os.path.join(os.path.dirname(__file__), "..", "..", ".env")
    env_path = os.path.abspath(env_path)
    print(f"📄 Loading .env from: {env_path}")

    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, value = line.split("=", 1)
                    os.environ[key] = value.strip()
    else:
        print("❌ .env not found!")


def encode_image(path: str) -> str | None:
    """Encode image file to base64."""
    if not os.path.exists(path):
        print(f"❌ Bild nicht gefunden: {path}")
        return None
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode("utf-8")


def main():
    """Test OpenAI API connection and Vision capabilities."""
    load_env()

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("❌ OPENAI_API_KEY fehlt.")
        return

    client = OpenAI(api_key=api_key)

    print("\n📝 Running TEXT test…")
    try:
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": "Say VISION_TEXT_OK"}],
            max_tokens=5
        )
        print("✅ TEXT:", resp.choices[0].message.content)
    except Exception as e:
        print("❌ TEXT FAILED:", e)
        return

    # --- VISION TEST MIT ECHTEM BILD ---
    print("\n👁️ Running REAL Vision Test…")

    # Testbild (du kannst jeden beliebigen Pfad nehmen!)
    test_image = "media/test.jpg"
    
    # Try multiple paths
    possible_paths = [
        Path(test_image),
        Path("server") / test_image,
        Path(".") / test_image,
    ]
    
    img_path = None
    for path in possible_paths:
        if path.exists():
            img_path = str(path)
            break

    if not img_path:
        print(f"❌ Kein Bild verfügbar. Lege ein Bild unter {test_image} ab!")
        print("   Oder ändere den Pfad in test_openai.py")
        return

    img_b64 = encode_image(img_path)
    if img_b64 is None:
        return

    try:
        resp = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": "Describe this image in one short sentence."},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}
                        },
                    ]
                }
            ],
            max_tokens=50
        )

        print("👁️ VISION OK →", resp.choices[0].message.content)

    except Exception as e:
        print("❌ Vision Failed:", e)
        import traceback
        traceback.print_exc()
        return

    print("\n🎉 ALL TESTS PASSED — Vision AI funktioniert!")


if __name__ == "__main__":
    main()
