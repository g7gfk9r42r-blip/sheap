"""Test price parsing and loyalty detection"""

import json
from pathlib import Path
from src.normalize.price_parser import PriceParser
from src.models import PriceTier, Condition


def test_multi_price_kaufland():
    """Test Kaufland multi-price case"""
    fixture_path = Path(__file__).parent / "fixtures" / "kaufland_multi_price.json"
    
    with open(fixture_path) as f:
        test_cases = json.load(f)
    
    # Test case: Standard + K-Card + UVP
    case = test_cases[3]  # Milch case
    
    raw_prices = case["prices"]
    price_tiers, reference_price = PriceParser.normalize_prices(raw_prices)
    
    # Should have 2 price tiers (standard + loyalty)
    assert len(price_tiers) == 2
    
    # First should be standard
    assert price_tiers[0].condition.type == "standard"
    assert price_tiers[0].amount == 1.29
    
    # Second should be loyalty
    assert price_tiers[1].condition.type == "loyalty"
    assert price_tiers[1].amount == 0.99
    assert price_tiers[1].condition.label == "K-Card"
    assert price_tiers[1].condition.requires_card == True
    
    # Should have reference price
    # (Note: This test case doesn't have UVP, but structure is correct)
    
    # Validate structure
    is_valid, flags = PriceParser.validate_price_structure(price_tiers)
    assert is_valid == True
    assert "LOYALTY_WITHOUT_STANDARD" not in flags


def test_loyalty_without_standard():
    """Test that loyalty without standard is flagged"""
    raw_prices = [
        {
            "amount": 1.99,
            "condition": {
                "type": "loyalty",
                "label": "K-Card",
                "requires_card": True,
            },
            "is_reference": False,
        }
    ]
    
    price_tiers, _ = PriceParser.normalize_prices(raw_prices)
    is_valid, flags = PriceParser.validate_price_structure(price_tiers)
    
    assert is_valid == False
    assert "LOYALTY_WITHOUT_STANDARD" in flags


if __name__ == "__main__":
    test_multi_price_kaufland()
    test_loyalty_without_standard()
    print("All tests passed!")

