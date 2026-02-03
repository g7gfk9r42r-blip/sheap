# Test-Prompts für Rezept-Bilder

Hier sind einige Test-Prompts, die du direkt mit der OpenAI Images API testen kannst.

## Beispiel 1: Kartoffelgratin (wie im User-Request)

```
Ultra realistic food photography of potato gratin with onions and melted cheese. Visible ingredients: potatoes, onions, melted golden cheese, creamy baked texture. served in a ceramic baking dish. 45-degree angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look.
```

## Beispiel 2: Salat (Top-Down)

```
Ultra realistic food photography of broccoli crunch salad with peanuts. Visible ingredients: broccoli, peanuts, field salad. served in a bowl. top-down angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look.
```

## Beispiel 3: Pasta (45° Angle)

```
Ultra realistic food photography of pasta with chicken and cherry tomatoes. Visible ingredients: pasta, chicken, cherry tomatoes, grated cheese. served on a white plate. 45-degree angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look.
```

## Beispiel 4: Pizza (Top-Down)

```
Ultra realistic food photography of pizza with toppings. Visible ingredients: pizza dough, cheese, vegetables, meat. served on a wooden board. top-down angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look.
```

## Testen mit dem Test-Script

```bash
python3 server/tools/test_image_prompt.py
```

Das Script verwendet den Kartoffelgratin-Prompt und zeigt dir die generierte Bild-URL.

## Testen mit cURL

```bash
curl https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "dall-e-3",
    "prompt": "Ultra realistic food photography of potato gratin with onions and melted cheese. Visible ingredients: potatoes, onions, melted golden cheese, creamy baked texture. served in a ceramic baking dish. 45-degree angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look.",
    "size": "1024x1024",
    "quality": "standard",
    "n": 1
  }'
```

## Testen mit Python (interaktiv)

```python
from openai import OpenAI
import os

client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY'))

prompt = """Ultra realistic food photography of potato gratin with onions and melted cheese. Visible ingredients: potatoes, onions, melted golden cheese, creamy baked texture. served in a ceramic baking dish. 45-degree angle, natural daylight, soft shadows, shallow depth of field, clean neutral background, no text, no logos, no packaging, no watermark, professional food styling, appetizing look."""

response = client.images.generate(
    model="dall-e-3",
    prompt=prompt,
    size="1024x1024",
    quality="standard",
    n=1,
)

print(response.data[0].url)
```

## Wichtige Prompt-Elemente

- **Gericht-Name**: Klar beschrieben, ohne Marken
- **Sichtbare Zutaten**: Hauptzutaten aufgelistet
- **Servierart**: "served in a bowl" / "served on a white plate" / "served in a ceramic baking dish"
- **Kamerawinkel**: "45-degree angle" oder "top-down angle"
- **Beleuchtung**: "natural daylight, soft shadows"
- **Fokus**: "shallow depth of field"
- **Hintergrund**: "clean neutral background"
- **Ausschlüsse**: "no text, no logos, no packaging, no watermark"
- **Stil**: "professional food styling, appetizing look"
