# 🎨 SDXL Food Photography - Prompt Reference

## 📋 Globale Prompts (Brand-Konsistenz)

### Base-Prompt

```
professional food photography, restaurant quality, 
natural daylight from window, soft shadows, 
white ceramic plate, wooden background, 
shallow depth of field, bokeh, 
appetizing, high resolution, 
shot on Canon EOS R5 with 85mm f/1.2 lens,
food styling, minimalistic composition,
warm lighting, vibrant colors,
```

### Negative Prompt

```
cartoon, illustration, drawing, painting, digital art,
AI generated, fake, synthetic, unrealistic,
blurry, low quality, low resolution,
hands, fingers, people, text, packaging,
logo, watermark, signature,
overexposed, underexposed, grainy,
plastic, artificial, fake food,
```

---

## 🎯 Rezept-spezifische Prompt-Generierung

### Template-Struktur

```
[GLOBAL_BASE_PROMPT]
[REZEPT_TITEL], [HAUPTZUTATEN]
[STIL-ERKENNUNG], [OBERFLÄCHE]
professional food photography, appetizing, high quality
```

### Stil-Erkennung (Automatisch)

**Bowl / Salat:**
```
bowl, colorful, fresh ingredients, mixed salad
white ceramic bowl, rustic wooden table
```

**Pasta:**
```
pasta dish, elegant plating, garnished with herbs
white ceramic plate, marble countertop
```

**Wok / Pfanne:**
```
wok dish, steaming hot, vibrant colors, aromatic
black cast iron pan, dark wooden surface
```

**Pizza:**
```
wood-fired pizza, melted cheese, golden crust
wooden pizza peel, stone oven background
```

**Sandwich / Wrap:**
```
artisan sandwich, fresh bread, layered ingredients
wooden cutting board, natural lighting
```

**Dessert:**
```
artisan dessert, elegant plating, refined presentation
white ceramic plate, marble surface
```

**Default:**
```
elegant plating, restaurant quality presentation
white ceramic plate, wooden background
```

---

## 📝 Beispiel-Prompts

### Beispiel 1: Skyr-Beeren-Crunch-Bowl

**Positive Prompt:**
```
professional food photography, restaurant quality, 
natural daylight from window, soft shadows, 
white ceramic plate, wooden background, 
shallow depth of field, bokeh, 
appetizing, high resolution, 
shot on Canon EOS R5 with 85mm f/1.2 lens,
food styling, minimalistic composition,
warm lighting, vibrant colors,
Skyr-Beeren-Crunch-Bowl, Vanille, Heidelbeeren, Kiwis
bowl, colorful, fresh ingredients, mixed salad
white ceramic bowl, rustic wooden table
professional food photography, appetizing, high quality
```

**Negative Prompt:**
```
cartoon, illustration, drawing, painting, digital art,
AI generated, fake, synthetic, unrealistic,
blurry, low quality, low resolution,
hands, fingers, people, text, packaging,
logo, watermark, signature,
overexposed, underexposed, grainy,
plastic, artificial, fake food,
```

### Beispiel 2: Wok-Hähnchen mit Kaiserschoten

**Positive Prompt:**
```
[GLOBAL_BASE_PROMPT]
Wok-Hähnchen mit Kaiserschoten & Orangen-Glaze, Hähnchen-Innenbrustfilets, Kaiserschoten, Orangen
wok dish, steaming hot, vibrant colors, aromatic
black cast iron pan, dark wooden surface
professional food photography, appetizing, high quality
```

### Beispiel 3: Pizza Margherita

**Positive Prompt:**
```
[GLOBAL_BASE_PROMPT]
Pizza Margherita, Mozzarella, Tomaten, Basilikum
wood-fired pizza, melted cheese, golden crust
wooden pizza peel, stone oven background
professional food photography, appetizing, high quality
```

---

## 🔧 Parameter-Einstellungen

### SDXL Base + Refiner

```python
SAMPLER = "DPM++ 2M Karras"
STEPS = 30
CFG_SCALE = 7.0
REFINER_STRENGTH = 0.3
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048  # oder 4096x4096
```

### SSD-1B (Ohne Refiner)

```python
SAMPLER = "DPM++ 2M Karras"
STEPS = 25
CFG_SCALE = 7.0
REFINER_STRENGTH = None
BASE_SIZE = 1024x1024
FINAL_SIZE = 2048x2048
```

---

## ✅ Qualitäts-Checkliste

Vor Produktions-Start für jedes generierte Bild prüfen:

- ✅ **Konsistenz:** Einheitlicher Food-Look?
- ✅ **Qualität:** Keine AI-Artefakte?
- ✅ **Licht:** Natürliches Tageslicht?
- ✅ **Komposition:** Professionelles Plating?
- ✅ **Details:** Scharfe Texturen?
- ✅ **Appetit:** Sieht appetitlich aus?

---

**Erstellt:** 2025-01-05  
**Version:** 1.0.0

