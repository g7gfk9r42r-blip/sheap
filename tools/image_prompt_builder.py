#!/usr/bin/env python3
"""
Verbesserte Bildgenerator-Prompts für Rezept-Bilder
- Optimierte Prompts für Food Photography
- Unterstützt verschiedene Modelle (Flux, SDXL)
- Kategorien-spezifische Style-Hinweise
"""

from typing import List, Dict, Optional


class ImagePromptBuilder:
    """Baut optimierte Prompts für Rezept-Bilder"""
    
    # Style-Mapping für Kategorien
    CATEGORY_STYLES = {
        "high protein": "muscular, protein-rich, fitness, gym-ready",
        "low carb": "clean, fresh, minimal carbs, keto-friendly",
        "vegetarian": "fresh vegetables, plant-based, colorful, vibrant",
        "vegan": "plant-based, colorful, vibrant, natural",
        "gluten-free": "clean, fresh, healthy, allergy-friendly",
        "quick": "fast, simple, minimal preparation",
        "budget": "home-style, comforting, affordable",
        "gourmet": "restaurant-quality, sophisticated, elegant",
        "comfort food": "homey, warm, comforting, nostalgic",
    }
    
    @staticmethod
    def build_prompt(
        title: str,
        main_ingredients: List[str],
        categories: Optional[List[str]] = None,
        style_hint: Optional[str] = None,
    ) -> str:
        """
        Baut optimierten Prompt für Rezept-Bilder.
        
        Args:
            title: Rezept-Titel
            main_ingredients: Top 3-5 Hauptzutaten
            categories: Liste von Kategorien (für Style-Hinweise)
            style_hint: Optionaler Style-Hinweis (z.B. "gourmet", "quick")
        
        Returns:
            Optimierter Prompt-String
        """
        # Basis-Prompt (immer gleich)
        prompt_parts = [
            "ultra realistic professional food photography",
            "high quality, sharp focus, 8k resolution",
            "appetizing, mouth-watering presentation",
            "natural lighting, soft shadows, studio quality",
            "modern food styling, restaurant-quality plating",
        ]
        
        # Haupt-Gericht
        prompt_parts.append(f"dish: {title}")
        
        # Zutaten (Top 3)
        if main_ingredients:
            ingredients_str = ", ".join(main_ingredients[:3])
            prompt_parts.append(f"ingredients visible: {ingredients_str}")
        
        # Kategorie-basierte Style-Hinweise
        category_styles = []
        if categories:
            for cat in categories:
                cat_lower = cat.lower()
                for key, style in ImagePromptBuilder.CATEGORY_STYLES.items():
                    if key in cat_lower:
                        category_styles.append(style)
        
        if category_styles:
            prompt_parts.append(f"style: {', '.join(category_styles[:2])}")
        
        # Optionaler Style-Hint
        if style_hint:
            prompt_parts.append(f"mood: {style_hint}")
        
        # Perspektive & Komposition
        prompt_parts.extend([
            "overhead or 45-degree angle view",
            "centered composition, rule of thirds",
            "neutral background, clean presentation",
            "shallow depth of field, bokeh background",
        ])
        
        # Finale Qualitäts-Hinweise
        prompt_parts.extend([
            "Instagram-worthy, social media ready",
            "magazine cover quality",
            "professional commercial photography",
        ])
        
        return ", ".join(prompt_parts)
    
    @staticmethod
    def build_negative_prompt() -> str:
        """
        Standard Negative Prompt für alle Rezept-Bilder.
        """
        return (
            "text, watermark, logo, packaging, labels, "
            "blurry, lowres, deformed, ugly, bad anatomy, "
            "hands, people, writing, letters, numbers, "
            "plastic wrap, containers, boxes, "
            "unappetizing, burnt, overcooked, "
            "artificial colors, oversaturated, "
            "bad lighting, harsh shadows, "
            "cluttered, messy, unprofessional"
        )
    
    @staticmethod
    def build_model_specific_prompt(
        model: str,
        title: str,
        main_ingredients: List[str],
        categories: Optional[List[str]] = None,
    ) -> tuple[str, str]:
        """
        Baut Model-spezifischen Prompt.
        
        Args:
            model: Model-Name (flux-schnell, flux-dev, sdxl)
            title: Rezept-Titel
            main_ingredients: Hauptzutaten
            categories: Kategorien
        
        Returns:
            (prompt, negative_prompt) Tuple
        """
        base_prompt = ImagePromptBuilder.build_prompt(
            title=title,
            main_ingredients=main_ingredients,
            categories=categories,
        )
        
        negative_prompt = ImagePromptBuilder.build_negative_prompt()
        
        # Model-spezifische Anpassungen
        if "flux" in model.lower():
            # Flux-Modelle: Weniger Technik-Jargon, mehr Beschreibung
            # Prompt ist bereits optimal
            pass
        elif "sdxl" in model.lower():
            # SDXL: Präzisere Beschreibungen helfen
            # Prompt ist bereits optimal
            pass
        
        return base_prompt, negative_prompt


# Beispiel-Verwendung:
if __name__ == "__main__":
    builder = ImagePromptBuilder()
    
    # Beispiel 1: High Protein Gericht
    prompt1, negative1 = builder.build_model_specific_prompt(
        model="flux-schnell",
        title="Hähnchen-Minutensteaks mit Avocado-Tomaten-Salsa",
        main_ingredients=["Hähnchen", "Avocado", "Tomaten"],
        categories=["High Protein", "Low Carb"],
    )
    
    print("=== PROMPT ===")
    print(prompt1)
    print("\n=== NEGATIVE PROMPT ===")
    print(negative1)
    
    # Beispiel 2: Vegetarisches Gericht
    prompt2, negative2 = builder.build_model_specific_prompt(
        model="flux-dev",
        title="Cremige Pilz-Pasta",
        main_ingredients=["Pilze", "Sahne", "Pasta"],
        categories=["Vegetarian", "Quick"],
    )
    
    print("\n\n=== PROMPT 2 ===")
    print(prompt2)
    print("\n=== NEGATIVE PROMPT 2 ===")
    print(negative2)

