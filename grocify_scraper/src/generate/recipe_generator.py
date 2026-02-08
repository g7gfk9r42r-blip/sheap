"""Recipe generator"""

import hashlib
import random
from typing import List, Dict, Any
import logging

from ..models import Recipe, Ingredient, Nutrition, Pricing
from ..enrich.nutrition_estimator import NutritionEstimator
from ..enrich.image_resolver import ImageResolver

logger = logging.getLogger(__name__)


class RecipeGenerator:
    """Generate recipes from offers"""
    
    def __init__(self, supermarket: str, week_key: str):
        self.supermarket = supermarket
        self.week_key = week_key
    
    def generate(self, offers: List[Any], count: int = 80) -> List[Recipe]:
        """
        Generate 50-100 recipes from offers.
        
        Args:
            offers: List of validated offers
            count: Target number of recipes (default 80, min 50, max 100)
            
        Returns:
            List of Recipe objects (50-100)
        """
        recipes = []
        
        # Enforce 50-100 range
        target_count = max(50, min(100, count))
        
        if not offers:
            logger.warning("No offers provided for recipe generation - skipping recipe generation")
            # Don't generate recipes if no offers available
            return []
        
        # Filter offers by confidence
        core_offers = [o for o in offers if hasattr(o, 'confidence') and o.confidence != "low" and (not hasattr(o, 'flags') or len(o.flags) == 0)]
        medium_offers = [o for o in offers if hasattr(o, 'confidence') and o.confidence == "medium"]
        low_offers = [o for o in offers if hasattr(o, 'confidence') and o.confidence == "low" or (hasattr(o, 'flags') and len(o.flags) > 0)]
        
        # Build recipe plan with variety buckets
        recipe_plan = self._build_recipe_plan(core_offers, medium_offers, low_offers, target_count)
        
        # Generate recipes according to plan
        for i, plan_item in enumerate(recipe_plan):
            try:
                recipe = self._generate_one(plan_item["offers"], low_offers, i, plan_item)
                if recipe:
                    recipes.append(recipe)
            except Exception as e:
                logger.error(f"Failed to generate recipe {i}: {e}")
                import traceback
                logger.debug(traceback.format_exc())
                continue
        
        # If we don't have enough, DO NOT fill with pantry recipes
        # Only generate recipes from actual offers
        if len(recipes) < 50 and len(offers) > 0:
            logger.warning(f"Only {len(recipes)} recipes generated from {len(offers)} offers (target: 50)")
            # Don't fill with pantry - only use actual offers
        
        # Cap at 100
        recipes = recipes[:100]
        
        logger.info(f"Generated {len(recipes)} recipes from {len(offers)} offers")
        return recipes
    
    def _generate_one(self, core_offers: List[Any], optional_offers: List[Any], index: int, plan_item: Dict[str, Any] = None) -> Optional[Recipe]:
        """Generate a single recipe"""
        # Use plan_item if provided, otherwise select randomly
        if plan_item and plan_item.get("offers"):
            selected = plan_item["offers"]
        else:
            num_ingredients = random.randint(3, 5)
            selected = random.sample(core_offers[:min(20, len(core_offers))], min(num_ingredients, len(core_offers)))
        
        if len(selected) < 1:
            return None
        
        # Generate recipe
        title = self._generate_title(selected)
        recipe_id = self._generate_id(title, index)
        
        # Use plan tags if available
        plan_tags = plan_item.get("tags", []) if plan_item else []
        plan_time = plan_item.get("time", random.randint(15, 45)) if plan_item else random.randint(15, 45)
        
        # Build ingredients
        ingredients = []
        total_standard = 0.0
        total_loyalty = 0.0
        has_loyalty = False
        
        for offer in selected:
            # Find standard and loyalty prices
            standard_price = None
            loyalty_price = None
            loyalty_label = None
            
            for tier in offer.price_tiers:
                if tier.condition.type == "standard":
                    standard_price = tier.amount
                elif tier.condition.type == "loyalty":
                    loyalty_price = tier.amount
                    loyalty_label = tier.condition.label
            
            if standard_price:
                total_standard += standard_price
            if loyalty_price:
                total_loyalty += loyalty_price
                has_loyalty = True
            
            ingredient = Ingredient(
                name=offer.title,
                amount=offer.quantity.value,
                unit=offer.quantity.unit,
                from_offer_id=offer.id,
                is_from_offer=True,
                price={
                    "standard": standard_price,
                    "loyalty": loyalty_price,
                    "condition_label": loyalty_label,
                },
            )
            ingredients.append(ingredient)
        
        # Estimate nutrition (use first offer as base)
        nutrition = NutritionEstimator.estimate(selected[0], servings=2)
        
        # Resolve images
        hero_url, images = ImageResolver.resolve(selected[0], selected)
        
        # Build pricing
        pricing = Pricing(
            estimated_total={
                "standard": round(total_standard, 2) if total_standard > 0 else None,
                "with_loyalty": round(total_loyalty, 2) if total_loyalty > 0 else None,
            },
            notes="Mit Loyalty-Karte günstiger" if has_loyalty else None,
        )
        
        # Build warnings
        warnings = []
        if has_loyalty and not total_standard:
            warnings.append("LOYALTY_REQUIRED_FOR_CHEAPEST_PRICE")
        elif has_loyalty and total_loyalty < total_standard:
            warnings.append("LOYALTY_AVAILABLE_FOR_LOWER_PRICE")
        
        # Generate steps
        steps = self._generate_steps(selected)
        
        recipe = Recipe(
            id=recipe_id,
            supermarket=self.supermarket,
            week_key=self.week_key,
            title=title,
            tags=plan_tags + self._generate_tags(selected),
            hero_image_url=hero_url,
            images=images,
            servings=random.randint(1, 4),
            time_minutes=plan_time,
            difficulty=random.choice(["easy", "medium", "medium"]),  # Bias towards easy/medium
            ingredients=ingredients,
            steps=steps,
            nutrition=nutrition,
            pricing=pricing,
            warnings=warnings,
        )
        
        return recipe
    
    def _generate_title(self, offers: List[Any]) -> str:
        """Generate recipe title from offers"""
        # Simple: use first offer + "mit" + others
        if len(offers) == 1:
            return f"{offers[0].title} Rezept"
        
        main = offers[0].title
        others = ", ".join([o.title for o in offers[1:3]])
        return f"{main} mit {others}"
    
    def _generate_id(self, title: str, index: int) -> str:
        """Generate recipe ID"""
        id_string = f"{self.supermarket}-{title}-{index}"
        return hashlib.sha256(id_string.encode()).hexdigest()[:16]
    
    def _generate_tags(self, offers: List[Any]) -> List[str]:
        """Generate recipe tags"""
        tags = []
        
        # Category-based tags
        categories = set([o.category for o in offers if o.category])
        if "meat" in categories:
            tags.append("high_protein")
        if "produce" in categories:
            tags.append("vegetables")
        
        # Random tags
        all_tags = ["quick", "family", "budget", "easy"]
        tags.extend(random.sample(all_tags, random.randint(1, 2)))
        
        return tags
    
    def _build_recipe_plan(self, core_offers: List[Any], medium_offers: List[Any], low_offers: List[Any], target: int) -> List[Dict[str, Any]]:
        """Build recipe plan with variety buckets"""
        plan = []
        
        # Variety buckets (15-25 each)
        high_protein_count = min(25, max(15, target // 4))
        vegetarian_count = min(25, max(15, target // 4))
        quick_count = min(20, max(10, target // 5))
        mealprep_count = min(20, max(10, target // 5))
        balanced_count = target - high_protein_count - vegetarian_count - quick_count - mealprep_count
        
        # Categorize offers
        meat_offers = [o for o in core_offers + medium_offers if o.category in ["meat", "poultry", "fish"]]
        veg_offers = [o for o in core_offers + medium_offers if o.category in ["produce", "vegetables", "fruits"]]
        dairy_offers = [o for o in core_offers + medium_offers if o.category in ["dairy", "cheese"]]
        carb_offers = [o for o in core_offers + medium_offers if o.category in ["pasta", "bread", "rice", "grains"]]
        
        # High-protein recipes
        for i in range(high_protein_count):
            if meat_offers:
                main = random.choice(meat_offers)
                sides = random.sample(veg_offers + carb_offers, min(2, len(veg_offers + carb_offers)))
                plan.append({
                    "type": "high_protein",
                    "offers": [main] + sides,
                    "tags": ["high-protein"],
                    "time": random.randint(20, 60),
                })
        
        # Vegetarian recipes
        for i in range(vegetarian_count):
            if veg_offers:
                main = random.choice(veg_offers)
                sides = random.sample(veg_offers + carb_offers + dairy_offers, min(2, len(veg_offers + carb_offers + dairy_offers)))
                plan.append({
                    "type": "vegetarian",
                    "offers": [main] + sides,
                    "tags": ["vegetarian"],
                    "time": random.randint(15, 45),
                })
        
        # Quick recipes
        for i in range(quick_count):
            all_offers = core_offers + medium_offers
            if all_offers:
                selected = random.sample(all_offers, min(3, len(all_offers)))
                plan.append({
                    "type": "quick",
                    "offers": selected,
                    "tags": ["quick"],
                    "time": random.randint(5, 20),
                })
        
        # Meal prep recipes
        for i in range(mealprep_count):
            all_offers = core_offers + medium_offers
            if all_offers:
                selected = random.sample(all_offers, min(4, len(all_offers)))
                plan.append({
                    "type": "mealprep",
                    "offers": selected,
                    "tags": ["mealprep"],
                    "time": random.randint(30, 90),
                })
        
        # Balanced recipes
        for i in range(balanced_count):
            all_offers = core_offers + medium_offers
            if all_offers:
                selected = random.sample(all_offers, min(3, len(all_offers)))
                plan.append({
                    "type": "balanced",
                    "offers": selected,
                    "tags": ["balanced", "budget"],
                    "time": random.randint(20, 50),
                })
        
        # Shuffle for variety
        random.shuffle(plan)
        return plan[:target]
    
    def _generate_pantry_recipes(self, count: int) -> List[Recipe]:
        """Generate recipes using pantry/common ingredients when offers are insufficient"""
        pantry_ingredients = [
            {"name": "Olivenöl", "amount": 30, "unit": "ml"},
            {"name": "Salz", "amount": 5, "unit": "g"},
            {"name": "Pfeffer", "amount": 2, "unit": "g"},
            {"name": "Zwiebel", "amount": 100, "unit": "g"},
            {"name": "Knoblauch", "amount": 10, "unit": "g"},
            {"name": "Tomaten", "amount": 200, "unit": "g"},
            {"name": "Reis", "amount": 100, "unit": "g"},
            {"name": "Nudeln", "amount": 100, "unit": "g"},
        ]
        
        recipes = []
        simple_titles = [
            "Einfache Pasta", "Schnelle Pfanne", "Einfaches Risotto",
            "Klassische Tomatensauce", "Gedämpftes Gemüse", "Einfacher Salat",
        ]
        
        for i in range(count):
            selected = random.sample(pantry_ingredients, random.randint(3, 5))
            title = random.choice(simple_titles) + f" {i+1}"
            recipe_id = self._generate_id(title, i)
            
            ingredients = []
            for ing in selected:
                ingredients.append(Ingredient(
                    name=ing["name"],
                    amount=ing["amount"],
                    unit=ing["unit"],
                    from_offer_id=None,
                    is_from_offer=False,
                    price={"standard": None, "loyalty": None, "condition_label": None},
                ))
            
            nutrition = NutritionEstimator.estimate_simple(len(selected), servings=2)
            
            recipe = Recipe(
                id=recipe_id,
                supermarket=self.supermarket,
                week_key=self.week_key,
                title=title,
                tags=["pantry", "simple"],
                hero_image_url="",
                images=[],
                servings=2,
                time_minutes=random.randint(15, 30),
                difficulty="easy",
                ingredients=ingredients,
                steps=self._generate_simple_steps(),
                nutrition=nutrition,
                pricing=Pricing(),
                warnings=["PANTRY_ONLY"],
            )
            recipes.append(recipe)
        
        return recipes
    
    def _generate_simple_steps(self) -> List[str]:
        """Generate simple cooking steps"""
        return [
            "Zutaten vorbereiten.",
            "In einer Pfanne erhitzen.",
            "Würzen und servieren.",
        ]
    
    def _generate_steps(self, offers: List[Any]) -> List[str]:
        """Generate cooking steps"""
        steps = [
            "Zutaten vorbereiten und waschen.",
            "Zutaten nach Rezept zusammenfügen.",
            "Alles gut vermischen und würzen.",
            "Nach Packungsanleitung zubereiten.",
            "Heiß servieren.",
        ]
        return steps[:random.randint(4, 6)]

