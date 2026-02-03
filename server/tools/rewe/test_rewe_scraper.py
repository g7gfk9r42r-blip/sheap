#!/usr/bin/env python3
"""
Test-Script für REWE-Scraper
Testet mehrere PLZs und loggt Ergebnisse
"""

import logging
import sys
from pathlib import Path

# Import des Hauptmoduls
try:
    from fetch_rewe_offers import fetch_rewe_offers
except ImportError:
    # Fallback: Wenn Import fehlschlägt, füge aktuelles Verzeichnis zum Path hinzu
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from fetch_rewe_offers import fetch_rewe_offers

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Test-PLZs
TEST_ZIP_CODES = ["53113", "97421", "10115", "80331"]


def analyze_offers(offers):
    """Analysiert Angebote und gibt Statistiken zurück."""
    total = len(offers)
    
    # Prüfe auf App-Angebote (Angebote mit promo_label oder bestimmten Labels)
    app_offers = [
        offer for offer in offers
        if offer.get('promo_label') or 
           offer.get('price_type') in ['promotion', 'aktion', 'knüller'] or
           'app' in str(offer.get('promo_label', '')).lower()
    ]
    has_app_offers = len(app_offers) > 0
    
    # Prüfe auf fehlende Kategorien
    missing_categories = [
        offer for offer in offers
        if not offer.get('category') or offer.get('category', '').strip() == ''
    ]
    has_missing_categories = len(missing_categories) > 0
    
    return {
        'total': total,
        'app_offers_count': len(app_offers),
        'has_app_offers': has_app_offers,
        'missing_categories_count': len(missing_categories),
        'has_missing_categories': has_missing_categories,
    }


def test_zip_code(zip_code):
    """Testet eine PLZ und loggt Ergebnisse."""
    logger.info("=" * 60)
    logger.info(f"Teste PLZ: {zip_code}")
    logger.info("=" * 60)
    
    try:
        offers = fetch_rewe_offers(zip_code)
        
        if not offers:
            logger.warning(f"⚠️  Keine Angebote für PLZ {zip_code}")
            return
        
        # Analysiere Angebote
        stats = analyze_offers(offers)
        
        # Logge Ergebnisse
        logger.info(f"✅ {stats['total']} Angebote gefunden")
        
        if stats['has_app_offers']:
            logger.info(f"📱 App-Angebote vorhanden: {stats['app_offers_count']}")
        else:
            logger.info("📱 Keine App-Angebote gefunden")
        
        if stats['has_missing_categories']:
            logger.warning(f"⚠️  {stats['missing_categories_count']} Angebote ohne Kategorie")
        else:
            logger.info("✅ Alle Angebote haben Kategorien")
        
    except Exception as e:
        logger.error(f"❌ Fehler beim Testen von PLZ {zip_code}: {e}", exc_info=True)


def main():
    """Hauptfunktion: Testet alle PLZs."""
    logger.info("🚀 Starte REWE-Scraper Tests")
    logger.info(f"Teste {len(TEST_ZIP_CODES)} PLZs: {', '.join(TEST_ZIP_CODES)}")
    logger.info("")
    
    for zip_code in TEST_ZIP_CODES:
        test_zip_code(zip_code)
        logger.info("")
    
    logger.info("=" * 60)
    logger.info("✅ Alle Tests abgeschlossen")
    logger.info("=" * 60)


if __name__ == '__main__':
    main()

