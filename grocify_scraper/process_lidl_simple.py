#!/usr/bin/env python3
"""
LIDL - EINFACHE PIPELINE
Extrahiert nur Angebote aus PDF, keine Rezepte.
"""

import sys
from pathlib import Path
import logging
from datetime import datetime

# Add parent directory to path
BASE_DIR = Path(__file__).parent
sys.path.insert(0, str(BASE_DIR))

from src.extract.gpt_vision_extractor import GPTVisionExtractor
from src.extract.pdf_extractor import PDFExtractor
from src.normalize.normalizer import Normalizer

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(levelname)s: %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    print("=" * 70)
    print("LIDL - EINFACHE PIPELINE")
    print("=" * 70)
    
    # PDF path
    pdf_path = Path("../server/media/prospekte/lidl/kaufDA - Lidl - LIDL LOHNT SICH.pdf")
    
    if not pdf_path.exists():
        print(f"❌ PDF nicht gefunden: {pdf_path}")
        sys.exit(1)
    
    print(f"✅ PDF: {pdf_path}")
    
    # Output directory
    output_dir = Path("../server/media/prospekte/lidl")
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Initialize extractors
    gpt_extractor = GPTVisionExtractor("lidl")
    pdf_extractor = PDFExtractor("lidl")
    normalizer = Normalizer("lidl", "2025-W52")
    
    # Step 1: Extract offers with GPT Vision
    print("\n🔍 Extrahiere Angebote mit GPT Vision...")
    print("🔄 GPT Vision Extraktion läuft... (Dies kann einige Minuten dauern je nach PDF-Größe)")
    
    try:
        offers, page_stats = gpt_extractor.extract(pdf_path, week_key="2025-W52")
        
        if offers:
            print(f"✅ {len(offers)} Angebote mit GPT Vision extrahiert")
            
            # Normalize offers
            print("\n🔧 Normalisiere Angebote...")
            normalized_offers = normalizer.normalize(offers)
            
            print(f"✅ {len(normalized_offers)} Angebote normalisiert")
            
            # Convert offers to dict format (similar to aldi_sued_simple.py)
            offers_dict = []
            for offer in normalized_offers:
                if isinstance(offer, dict):
                    offers_dict.append(offer)
                else:
                    # Offer Object - convert to dict
                    offers_dict.append({
                        "id": getattr(offer, 'id', ''),
                        "supermarket": getattr(offer, 'supermarket', 'lidl'),
                        "weekKey": getattr(offer, 'week_key', '2025-W52'),
                        "title": getattr(offer, 'title', ''),
                        "brand": getattr(offer, 'brand', None),
                        "category": getattr(offer, 'category', None),
                        "quantity": {
                            "value": getattr(offer.quantity, 'value', None) if hasattr(offer, 'quantity') and offer.quantity else None,
                            "unit": getattr(offer.quantity, 'unit', None) if hasattr(offer, 'quantity') and offer.quantity else None,
                        } if hasattr(offer, 'quantity') else None,
                        "basePrice": {
                            "amount": getattr(offer.base_price, 'amount', None) if hasattr(offer, 'base_price') and offer.base_price else None,
                            "currency": getattr(offer.base_price, 'currency', 'EUR') if hasattr(offer, 'base_price') and offer.base_price else 'EUR',
                        } if hasattr(offer, 'base_price') else None,
                        "priceTiers": [
                            {
                                "amount": tier.amount,
                                "currency": getattr(tier, 'currency', 'EUR'),
                                "condition": {
                                    "type": tier.condition.type if hasattr(tier, 'condition') else 'standard',
                                    "label": getattr(tier.condition, 'label', None) if hasattr(tier, 'condition') else None,
                                }
                            }
                            for tier in (getattr(offer, 'price_tiers', []) or [])
                        ],
                        "source": {
                            "primary": getattr(offer.source, 'primary', 'pdf') if hasattr(offer, 'source') else 'pdf',
                            "page": getattr(offer.source, 'page', None) if hasattr(offer, 'source') else None,
                        } if hasattr(offer, 'source') else {"primary": "pdf"},
                    })
            
            # Save offers
            output_file = output_dir / "lidl_offer.json"
            import json
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump({
                    "supermarket": "lidl",
                    "currency": "EUR",
                    "validity": {
                        "from": datetime.now().strftime("%Y-%m-%d"),
                        "to": datetime.now().strftime("%Y-%m-%d")
                    },
                    "offers_catalog": offers_dict,
                    "extraction_metadata": {
                        "source": "gpt_vision",
                        "pdf_path": str(pdf_path),
                        "total_offers": len(offers_dict),
                        "page_stats": page_stats
                    }
                }, f, ensure_ascii=False, indent=2)
            
            print(f"\n✅ Angebote gespeichert: {output_file}")
            print("\n" + "=" * 70)
            print("✅ ERFOLGREICH")
            print("=" * 70)
            print(f"📊 Angebote: {len(normalized_offers)}")
            print(f"📁 Datei: {output_file}")
            return True
        else:
            print("⚠️ GPT Vision Extraktion lieferte keine Angebote")
            print("🔄 Versuche Fallback zu traditioneller PDF-Extraktion...")
            raise Exception("No offers extracted")
            
    except Exception as e:
        logger.error(f"GPT Vision Fehler: {e}")
        print("🔄 Versuche Fallback zu traditioneller PDF-Extraktion...")
        
        # Fallback: Traditional PDF extraction
        try:
            offers = pdf_extractor.extract(pdf_path, "2025-W52")
            
            if offers:
                print(f"✅ {len(offers)} Angebote mit traditioneller Methode extrahiert")
                
                # Normalize offers
                print("\n🔧 Normalisiere Angebote...")
                normalized_offers = normalizer.normalize(offers)
                
                print(f"✅ {len(normalized_offers)} Angebote normalisiert")
                
                # Convert offers to dict format
                offers_dict = []
                for offer in normalized_offers:
                    if isinstance(offer, dict):
                        offers_dict.append(offer)
                    else:
                        # Offer Object - convert to dict (simplified)
                        offers_dict.append({
                            "id": getattr(offer, 'id', ''),
                            "supermarket": "lidl",
                            "weekKey": "2025-W52",
                            "title": getattr(offer, 'title', ''),
                            "brand": getattr(offer, 'brand', None),
                            "category": getattr(offer, 'category', None),
                        })
                
                # Save offers
                output_file = output_dir / "lidl_offer.json"
                import json
                with open(output_file, 'w', encoding='utf-8') as f:
                    json.dump({
                        "supermarket": "lidl",
                        "currency": "EUR",
                        "validity": {
                            "from": datetime.now().strftime("%Y-%m-%d"),
                            "to": datetime.now().strftime("%Y-%m-%d")
                        },
                        "offers_catalog": offers_dict,
                        "extraction_metadata": {
                            "source": "pdf_extractor",
                            "pdf_path": str(pdf_path),
                            "total_offers": len(offers_dict)
                        }
                    }, f, ensure_ascii=False, indent=2)
                
                print(f"\n✅ Angebote gespeichert: {output_file}")
                print("\n" + "=" * 70)
                print("✅ ERFOLGREICH")
                print("=" * 70)
                print(f"📊 Angebote: {len(normalized_offers)}")
                print(f"📁 Datei: {output_file}")
                return True
            else:
                print("❌ Keine Angebote extrahiert")
                return False
                
        except Exception as e2:
            logger.error(f"Fallback-Extraktion fehlgeschlagen: {e2}")
            print("❌ Extraktion fehlgeschlagen")
            return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

