#!/usr/bin/env python3
"""
REWE Angebots-Wrapper
=====================

Ruft fetch_rewe_offers auf und speichert die Daten als JSON.
Wird von Cron einmal pro Woche ausgeführt.
"""

import json
import logging
import sys
from datetime import datetime
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
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('rewe_fetch.log', encoding='utf-8'),
    ]
)
logger = logging.getLogger(__name__)

# Konfiguration
ZIP_CODE = "53113"  # TODO: Passe deine PLZ an
OUTPUT_DIR = Path(__file__).parent / "output"  # Unterordner "output"


def main():
    """Hauptfunktion: Lädt Angebote und speichert sie als JSON."""
    logger.info("=" * 60)
    logger.info("REWE Angebots-Abruf gestartet")
    logger.info("=" * 60)
    
    try:
        # Erstelle Output-Verzeichnis, falls nicht vorhanden
        OUTPUT_DIR.mkdir(exist_ok=True)
        
        # Lade Angebote
        logger.info(f"Lade Angebote für PLZ {ZIP_CODE}...")
        offers = fetch_rewe_offers(ZIP_CODE)
        
        if not offers:
            logger.warning("⚠️  Keine Angebote gefunden!")
            return 1
        
        logger.info(f"✅ {len(offers)} Angebote geladen")
        
        # Erstelle Dateiname mit aktuellem Datum
        date_str = datetime.now().strftime('%Y%m%d')
        output_file = OUTPUT_DIR / f"angebote_rewe_{date_str}.json"
        
        # Erstelle JSON-Struktur
        output_data = {
            'market': 'REWE',
            'zip_code': ZIP_CODE,
            'fetched_at': datetime.now().isoformat(),
            'fetched_date': date_str,
            'total_offers': len(offers),
            'offers': offers,
        }
        
        # Speichere JSON
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ Angebote gespeichert: {output_file}")
        logger.info("=" * 60)
        
        # Konsolen-Ausgabe für Cron
        print(f"\n✅ REWE Angebots-Abruf erfolgreich!")
        print(f"📊 {len(offers)} Angebote gefunden")
        print(f"💾 Gespeichert in: {output_file}")
        print(f"📅 Datum: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        
        return 0
        
    except Exception as e:
        logger.error(f"❌ Fehler beim Abruf: {e}", exc_info=True)
        print(f"\n❌ Fehler: {e}\n")
        return 1


if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)

