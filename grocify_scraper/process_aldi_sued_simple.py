#!/usr/bin/env python3
"""
Einfache Pipeline für ALDI SÜD
1. GPT Vision extrahiert alle Angebote aus PDF
2. Rezepte werden aus Angeboten generiert
3. Output: aldi_sued_offer.json und aldi_sued_recipes.json
"""

import sys
import json
import os
from pathlib import Path
from datetime import datetime

sys.path.insert(0, str(Path(__file__).parent))

from src.extract.gpt_vision_extractor import GPTVisionExtractor
from src.extract.pdf_extractor import PDFExtractor
from src.normalize.normalizer import Normalizer
from src.generate.recipe_generator import RecipeGenerator

def get_week_key():
    """Get current week key"""
    now = datetime.now()
    year, week, _ = now.isocalendar()
    return f"{year}-W{week:02d}"

def extract_offers_from_pdf(pdf_path: Path, supermarket: str, week_key: str):
    """Extrahiere alle Angebote aus PDF mit GPT Vision"""
    print("🔍 Extrahiere Angebote mit GPT Vision...")
    print()
    
    # Prüfe API Key
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise ValueError("❌ OPENAI_API_KEY nicht gesetzt! Bitte setze die Umgebungsvariable.")
    
    # GPT Vision Extraktion
    vision_extractor = GPTVisionExtractor(supermarket)
    
    if not vision_extractor.client:
        raise ValueError("❌ GPT Vision Client konnte nicht initialisiert werden. Prüfe OPENAI_API_KEY.")
    
    print("🔄 GPT Vision Extraktion läuft...")
    print("   (Dies kann einige Minuten dauern je nach PDF-Größe)")
    print()
    
    try:
        offers_raw, page_stats = vision_extractor.extract(pdf_path, week_key, max_passes=2)
        
        if not offers_raw:
            print("⚠️  GPT Vision hat keine Angebote gefunden!")
            print("🔄 Versuche Fallback zu traditioneller Extraktion...")
            pdf_extractor = PDFExtractor(supermarket)
            offers_raw = pdf_extractor.extract(pdf_path, week_key)
            print(f"✅ {len(offers_raw)} Angebote mit traditioneller Methode extrahiert")
        else:
            print(f"✅ {len(offers_raw)} Angebote mit GPT Vision extrahiert")
        
        return offers_raw
        
    except Exception as e:
        print(f"⚠️  GPT Vision Fehler: {e}")
        print("🔄 Versuche Fallback zu traditioneller PDF-Extraktion...")
        pdf_extractor = PDFExtractor(supermarket)
        offers_raw = pdf_extractor.extract(pdf_path, week_key)
        print(f"✅ {len(offers_raw)} Angebote mit traditioneller Methode extrahiert")
        return offers_raw

def normalize_offers(offers_raw, supermarket: str, week_key: str):
    """Normalisiere Angebote"""
    print()
    print("🔧 Normalisiere Angebote...")
    
    normalizer = Normalizer(supermarket, week_key)
    offers_normalized = normalizer.normalize(offers_raw)
    
    print(f"✅ {len(offers_normalized)} Angebote normalisiert")
    return offers_normalized

def generate_recipes(offers, supermarket: str, week_key: str, count: int = 80):
    """Generiere Rezepte aus Angeboten"""
    print()
    print(f"🍽️  Generiere {count} Rezepte...")
    
    if not offers:
        print("⚠️  Keine Angebote vorhanden, kann keine Rezepte generieren")
        return []
    
    generator = RecipeGenerator(supermarket, week_key)
    recipes = generator.generate(offers, count=count)
    
    print(f"✅ {len(recipes)} Rezepte generiert")
    return recipes

def offers_to_dict(offers):
    """Konvertiere Angebote zu Dicts"""
    offers_dict = []
    for offer in offers:
        if isinstance(offer, dict):
            offers_dict.append(offer)
        else:
            # Offer Object
            offers_dict.append({
                "id": getattr(offer, 'id', ''),
                "supermarket": getattr(offer, 'supermarket', 'aldi_sued'),
                "weekKey": getattr(offer, 'week_key', ''),
                "title": getattr(offer, 'title', ''),
                "brand": getattr(offer, 'brand', None),
                "brandConfidence": getattr(offer, 'brand_confidence', 'low'),
                "category": getattr(offer, 'category', None),
                "quantity": {
                    "value": getattr(offer.quantity, 'value', None) if hasattr(offer, 'quantity') else None,
                    "unit": getattr(offer.quantity, 'unit', None) if hasattr(offer, 'quantity') else None,
                } if hasattr(offer, 'quantity') else None,
                "basePrice": {
                    "amount": getattr(offer.base_price, 'amount', None) if hasattr(offer, 'base_price') else None,
                    "currency": getattr(offer.base_price, 'currency', 'EUR') if hasattr(offer, 'base_price') else 'EUR',
                } if hasattr(offer, 'base_price') else None,
                "referencePrice": {
                    "amount": getattr(offer.reference_price, 'amount', None) if hasattr(offer, 'reference_price') else None,
                    "currency": getattr(offer.reference_price, 'currency', 'EUR') if hasattr(offer, 'reference_price') else 'EUR',
                    "type": getattr(offer.reference_price, 'type', None) if hasattr(offer, 'reference_price') else None,
                } if hasattr(offer, 'reference_price') and offer.reference_price else None,
                "priceTiers": [
                    {
                        "amount": tier.amount,
                        "currency": getattr(tier, 'currency', 'EUR'),
                        "condition": {
                            "type": tier.condition.type,
                            "label": tier.condition.label,
                            "requiresCard": tier.condition.requires_card,
                            "requiresApp": tier.condition.requires_app,
                            "minQty": tier.condition.min_qty,
                            "notes": tier.condition.notes,
                        },
                    }
                    for tier in (getattr(offer, 'price_tiers', []) or [])
                ],
                "discount": {
                    "percent": offer.discount.percent,
                    "derived": offer.discount.derived,
                } if hasattr(offer, 'discount') and offer.discount else None,
                "source": {
                    "primary": getattr(offer.source, 'primary', 'pdf') if hasattr(offer, 'source') else 'pdf',
                    "pdfFile": getattr(offer.source, 'pdf_file', None) if hasattr(offer, 'source') else None,
                    "page": getattr(offer.source, 'page', None) if hasattr(offer, 'source') else None,
                } if hasattr(offer, 'source') else {"primary": "pdf"},
                "confidence": getattr(offer, 'confidence', 'medium'),
                "flags": getattr(offer, 'flags', []),
            })
    return offers_dict

def recipes_to_dict(recipes):
    """Konvertiere Rezepte zu Dicts"""
    recipes_dict = []
    for recipe in recipes:
        if isinstance(recipe, dict):
            recipes_dict.append(recipe)
        else:
            # Recipe Object
            recipes_dict.append({
                "id": recipe.id,
                "supermarket": recipe.supermarket,
                "weekKey": recipe.week_key,
                "title": recipe.title,
                "tags": getattr(recipe, 'tags', []),
                "heroImageUrl": getattr(recipe, 'hero_image_url', None),
                "images": getattr(recipe, 'images', []),
                "servings": recipe.servings,
                "timeMinutes": recipe.time_minutes,
                "difficulty": recipe.difficulty,
                "ingredients": [
                    {
                        "name": ing.name,
                        "amount": ing.amount,
                        "unit": ing.unit,
                        "fromOfferId": ing.from_offer_id,
                        "isFromOffer": ing.is_from_offer,
                        "price": ing.price,
                    }
                    for ing in recipe.ingredients
                ],
                "steps": recipe.steps,
                "nutritionRange": {
                    "kcal": {
                        "min": recipe.nutrition.kcal.min if recipe.nutrition.kcal else None,
                        "max": recipe.nutrition.kcal.max if recipe.nutrition.kcal else None,
                    },
                    "protein_g": {
                        "min": recipe.nutrition.protein_g.min if recipe.nutrition.protein_g else None,
                        "max": recipe.nutrition.protein_g.max if recipe.nutrition.protein_g else None,
                    },
                    "carbs_g": {
                        "min": recipe.nutrition.carbs_g.min if recipe.nutrition.carbs_g else None,
                        "max": recipe.nutrition.carbs_g.max if recipe.nutrition.carbs_g else None,
                    },
                    "fat_g": {
                        "min": recipe.nutrition.fat_g.min if recipe.nutrition.fat_g else None,
                        "max": recipe.nutrition.fat_g.max if recipe.nutrition.fat_g else None,
                    },
                } if hasattr(recipe, 'nutrition') else {},
                "pricing": {
                    "estimatedTotal": recipe.pricing.estimated_total if hasattr(recipe, 'pricing') else None,
                    "notes": recipe.pricing.notes if hasattr(recipe, 'pricing') else None,
                } if hasattr(recipe, 'pricing') else {},
                "warnings": getattr(recipe, 'warnings', []),
            })
    return recipes_dict

def main():
    print("=" * 70)
    print("ALDI SÜD - EINFACHE PIPELINE")
    print("=" * 70)
    print()
    
    # PDF-Pfad finden
    if len(sys.argv) > 1:
        pdf_path = Path(sys.argv[1])
        if not pdf_path.is_absolute():
            script_dir = Path(__file__).parent
            pdf_path = (script_dir / pdf_path).resolve()
    else:
        # Suche Standard-Pfad
        script_dir = Path(__file__).parent
        pdf_path = script_dir.parent / "server" / "media" / "prospekte" / "aldi_sued" / "54bf1abc-1382-4ecb-842f-b8a626542844.pdf"
        if not pdf_path.exists():
            # Suche nach irgendeinem PDF
            search_dir = script_dir.parent / "server" / "media" / "prospekte" / "aldi_sued"
            if search_dir.exists():
                pdfs = list(search_dir.glob("*.pdf"))
                if pdfs:
                    pdf_path = pdfs[0]
    
    if not pdf_path or not pdf_path.exists():
        print(f"❌ PDF nicht gefunden!")
        print(f"   Bitte Pfad als Argument angeben:")
        print(f"   python3 process_aldi_sued_simple.py /pfad/zum/pdf.pdf")
        sys.exit(1)
    
    print(f"✅ PDF: {pdf_path}")
    print()
    
    # Week Key
    week_key = get_week_key()
    
    supermarket = "aldi_sued"
    
    try:
        # 1. Extrahiere Angebote
        offers_raw = extract_offers_from_pdf(pdf_path, supermarket, week_key)
        
        if not offers_raw:
            print("❌ Keine Angebote extrahiert!")
            sys.exit(1)
        
        # 2. Normalisiere
        offers_normalized = normalize_offers(offers_raw, supermarket, week_key)
        
        # 3. Generiere Rezepte
        recipes = generate_recipes(offers_normalized, supermarket, week_key, count=80)
        
        # 4. Konvertiere zu Dicts
        offers_dict = offers_to_dict(offers_normalized)
        recipes_dict = recipes_to_dict(recipes)
        
        # 5. Speichere JSON-Dateien im gleichen Ordner wie PDF
        pdf_dir = pdf_path.parent
        offers_file = pdf_dir / "aldi_sued_offer.json"
        recipes_file = pdf_dir / "aldi_sued_recipes.json"
        
        with open(offers_file, 'w', encoding='utf-8') as f:
            json.dump(offers_dict, f, ensure_ascii=False, indent=2)
        
        with open(recipes_file, 'w', encoding='utf-8') as f:
            json.dump(recipes_dict, f, ensure_ascii=False, indent=2)
        
        print()
        print("=" * 70)
        print("✅ ERFOLGREICH")
        print("=" * 70)
        print(f"📊 Angebote: {len(offers_dict)}")
        print(f"🍽️  Rezepte: {len(recipes_dict)}")
        print()
        print(f"📁 Dateien erstellt:")
        print(f"   {offers_file}")
        print(f"   {recipes_file}")
        print()
        print(f"💡 Die Dateien liegen jetzt im gleichen Ordner wie das PDF!")
        print()
        
    except Exception as e:
        print(f"❌ Fehler: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()

