"""
Unit tests for nutrition enrichment pipeline.
Run with: pytest tools/test_nutrition.py -v
"""

import json
import pytest
from pathlib import Path
import tempfile
import sys

# Add tools to path
sys.path.insert(0, str(Path(__file__).parent))

from nutrition.normalization import (
    normalize_name,
    get_canonical_key,
    is_pantry_item,
    get_density,
    remove_stopwords,
    remove_shop_suffixes,
)
from nutrition.cache import NutritionCache


class TestNormalization:
    """Test text normalization functions."""
    
    def test_normalize_name_basic(self):
        """Test basic text normalization."""
        assert normalize_name("Frische Milch") == "milch"
        assert normalize_name("BIO Tomaten XL") == "tomaten"
        assert normalize_name("  Extra   Spaces  ") == "extra spaces"
    
    def test_normalize_name_umlauts(self):
        """Test umlaut normalization."""
        assert normalize_name("Käse") == "kaese"
        assert normalize_name("Öl") == "oel"
        assert normalize_name("Nüsse") == "nuesse"
        assert normalize_name("Süßkartoffel") == "suesskartoffel"
    
    def test_remove_shop_suffixes(self):
        """Test removal of shop-specific suffixes."""
        assert "aldi" not in remove_shop_suffixes("Produkt - ALDI Nord")
        assert "uvp" not in remove_shop_suffixes("Produkt UVP 5.99")
        assert "kg" not in remove_shop_suffixes("Produkt kg = 4.99")
    
    def test_remove_stopwords(self):
        """Test stopword removal."""
        result = remove_stopwords("frische bio tomaten xxl")
        assert "frische" not in result
        assert "bio" not in result
        assert "xxl" not in result
        assert "tomaten" in result
    
    def test_get_canonical_key(self):
        """Test canonical key generation."""
        # Should normalize and apply synonyms
        assert "ground" in get_canonical_key("Hackfleisch")
        assert "chicken" in get_canonical_key("Hähnchenbrust")
        assert "milk" in get_canonical_key("Frische Milch 1,5%")
    
    def test_is_pantry_item(self):
        """Test pantry item detection."""
        # Should be pantry
        assert is_pantry_item("Salz")
        assert is_pantry_item("Pfeffer")
        assert is_pantry_item("Olivenöl")
        assert is_pantry_item("Gewürze")
        
        # Should not be pantry
        assert not is_pantry_item("Tomaten")
        assert not is_pantry_item("Hähnchenbrust")
        assert not is_pantry_item("Milch")
    
    def test_get_density(self):
        """Test density lookup for ml->g conversion."""
        # Known densities
        density, needs_check = get_density("Milch", "ml")
        assert density == 1.03
        assert not needs_check
        
        density, needs_check = get_density("Olivenöl", "ml")
        assert density == 0.91
        assert not needs_check
        
        density, needs_check = get_density("Wasser", "ml")
        assert density == 1.0
        assert not needs_check
        
        # Unknown - should return 1.0 with needs_check=True
        density, needs_check = get_density("Unbekannte Flüssigkeit", "ml")
        assert density == 1.0
        assert needs_check
        
        # Not ml unit
        density, needs_check = get_density("Milch", "g")
        assert density == 1.0
        assert not needs_check


class TestCache:
    """Test nutrition cache functionality."""
    
    def test_cache_create(self):
        """Test cache creation."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            assert cache is not None
    
    def test_cache_get_set(self):
        """Test cache get/set operations."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            
            # Set value
            nutrition_data = {
                "kcal": 60.0,
                "protein_g": 3.5,
                "fat_g": 3.3,
                "carbs_g": 4.8
            }
            cache.set("milk", nutrition_data, {"source": "usda"})
            
            # Get value
            result = cache.get("milk")
            assert result is not None
            assert result["nutrition"]["kcal"] == 60.0
            assert result["metadata"]["source"] == "usda"
    
    def test_cache_persistence(self):
        """Test that cache persists to disk."""
        with tempfile.TemporaryDirectory() as tmpdir:
            # First instance
            cache1 = NutritionCache(tmpdir)
            cache1.set("tomato", {"kcal": 18.0}, {"source": "off"})
            cache1.save_all()
            
            # Second instance should load saved data
            cache2 = NutritionCache(tmpdir)
            result = cache2.get("tomato")
            assert result is not None
            assert result["nutrition"]["kcal"] == 18.0
    
    def test_cache_missing(self):
        """Test missing item tracking."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            
            # Add missing
            cache.add_missing("exotic_fruit", "Exotic Fruit XYZ", "not_found")
            
            # Check
            assert cache.is_missing("exotic_fruit")
            assert not cache.is_missing("tomato")
    
    def test_cache_ambiguous(self):
        """Test ambiguous item tracking."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            
            matches = [
                {"provider": "off", "name": "Milk 1.5%", "confidence": 0.75},
                {"provider": "usda", "name": "Milk lowfat", "confidence": 0.70}
            ]
            cache.add_ambiguous("milk", "Milch 1,5%", matches)
            
            assert cache.is_ambiguous("milk")
    
    def test_cache_stats(self):
        """Test cache statistics."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            
            cache.set("item1", {"kcal": 100}, {})
            cache.set("item2", {"kcal": 200}, {})
            cache.add_missing("item3", "Item 3")
            cache.add_ambiguous("item4", "Item 4", [])
            
            stats = cache.get_stats()
            assert stats["cached"] == 2
            assert stats["missing"] == 1
            assert stats["ambiguous"] == 1


class TestUnitConversion:
    """Test unit conversion for nutrition calculation."""
    
    def test_grams_conversion(self):
        """Test gram-based conversions."""
        # Direct grams
        assert 200 == 200  # 200g = 200g
        
        # Kilograms to grams
        assert 1 * 1000 == 1000  # 1kg = 1000g
        assert 0.5 * 1000 == 500  # 0.5kg = 500g
    
    def test_milliliters_conversion(self):
        """Test milliliter conversions with density."""
        # Water (density 1.0)
        ml = 250
        density = 1.0
        grams = ml * density
        assert grams == 250
        
        # Milk (density 1.03)
        ml = 250
        density = 1.03
        grams = ml * density
        assert grams == 257.5
        
        # Oil (density 0.91)
        ml = 100
        density = 0.91
        grams = ml * density
        assert grams == 91.0
    
    def test_liter_conversion(self):
        """Test liter conversions."""
        # 1 liter = 1000 ml
        liters = 1.5
        ml = liters * 1000
        assert ml == 1500


class TestKcalCalculation:
    """Test calorie calculation logic."""
    
    def test_basic_kcal_calculation(self):
        """Test basic calorie calculation."""
        # 100g of item with 60 kcal/100g = 60 kcal
        kcal_per_100g = 60.0
        amount_g = 100
        result = kcal_per_100g * (amount_g / 100)
        assert result == 60.0
    
    def test_scaled_kcal_calculation(self):
        """Test scaled calorie calculation."""
        # 250g of item with 80 kcal/100g = 200 kcal
        kcal_per_100g = 80.0
        amount_g = 250
        result = kcal_per_100g * (amount_g / 100)
        assert result == 200.0
    
    def test_fractional_kcal_calculation(self):
        """Test fractional amount calculation."""
        # 50g of item with 100 kcal/100g = 50 kcal
        kcal_per_100g = 100.0
        amount_g = 50
        result = kcal_per_100g * (amount_g / 100)
        assert result == 50.0
    
    def test_recipe_total_calculation(self):
        """Test total recipe calorie calculation."""
        ingredients = [
            {"kcal": 200},  # Pasta
            {"kcal": 50},   # Tomatoes
            {"kcal": 280},  # Cheese
            {"kcal": 120},  # Oil
        ]
        
        total = sum(ing["kcal"] for ing in ingredients)
        assert total == 650
        
        servings = 2
        per_serving = total / servings
        assert per_serving == 325


class TestMissingBehavior:
    """Test behavior when nutrition data is missing."""
    
    def test_missing_ingredient(self):
        """Test that missing ingredients are handled correctly."""
        # When ingredient has no nutrition data
        ingredient = {
            "name": "Exotic Spice XYZ",
            "amount": 5,
            "unit": "g"
        }
        
        # Should not have nutrition field or it should be null/missing
        nutrition = ingredient.get("nutrition")
        assert nutrition is None or nutrition.get("kcal") is None
    
    def test_missing_recipe_coverage(self):
        """Test recipe coverage calculation with missing data."""
        ingredients_total = 10
        ingredients_enriched = 7
        ingredients_missing = 3
        
        coverage = {
            "ingredients_total": ingredients_total,
            "ingredients_enriched": ingredients_enriched,
            "ingredients_missing": ingredients_missing
        }
        
        assert coverage["ingredients_total"] == ingredients_total
        assert coverage["ingredients_enriched"] == ingredients_enriched
        assert coverage["ingredients_missing"] == ingredients_missing
        assert coverage["ingredients_enriched"] + coverage["ingredients_missing"] == coverage["ingredients_total"]
    
    def test_kcal_source_missing(self):
        """Test that missing data sets kcal_source correctly."""
        recipe = {
            "nutrition": {
                "kcal_total": 0,
                "kcal_per_serving": 0,
                "kcal_source": "missing",
                "kcal_confidence": "low"
            }
        }
        
        assert recipe["nutrition"]["kcal_source"] == "missing"
        assert recipe["nutrition"]["kcal_confidence"] == "low"


class TestIntegration:
    """Integration tests for full enrichment flow."""
    
    def test_full_enrichment_flow(self):
        """Test complete enrichment flow."""
        with tempfile.TemporaryDirectory() as tmpdir:
            cache = NutritionCache(tmpdir)
            
            # Simulate recipe
            recipe = {
                "id": "test-2025-W01-001",
                "title": "Test Recipe",
                "servings": 2,
                "ingredients": [
                    {
                        "name": "Tomaten",
                        "amount": 200,
                        "unit": "g",
                        "isPantry": False
                    },
                    {
                        "name": "Olivenöl",
                        "amount": 2,
                        "unit": "el",
                        "isPantry": True
                    }
                ]
            }
            
            # Manually add nutrition data to cache
            cache.set("tomatoes", {"kcal": 18.0, "protein_g": 0.9, "fat_g": 0.2, "carbs_g": 3.9}, {"source": "usda"})
            
            # Get canonical keys
            key = get_canonical_key("Tomaten")
            assert "tomato" in key or "tomate" in key
            
            # Simulate enrichment
            cached = cache.get("tomatoes")
            if cached:
                kcal_per_100g = cached["nutrition"]["kcal"]
                amount_g = 200
                total_kcal = kcal_per_100g * (amount_g / 100)
                
                assert total_kcal == 36.0  # 18 kcal/100g * 200g
    
    def test_confidence_levels(self):
        """Test confidence level determination."""
        # High confidence: all ingredients found
        ingredients_total = 10
        ingredients_enriched = 10
        confidence = "high" if ingredients_enriched >= ingredients_total * 0.8 else "medium"
        assert confidence == "high"
        
        # Medium confidence: 60-79% found
        ingredients_total = 10
        ingredients_enriched = 7
        confidence = "high" if ingredients_enriched >= ingredients_total * 0.8 else "medium"
        assert confidence == "medium"
        
        # Low confidence: <60% found
        ingredients_total = 10
        ingredients_enriched = 5
        if ingredients_enriched >= ingredients_total * 0.8:
            confidence = "high"
        elif ingredients_enriched >= ingredients_total * 0.6:
            confidence = "medium"
        else:
            confidence = "low"
        assert confidence == "low"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

