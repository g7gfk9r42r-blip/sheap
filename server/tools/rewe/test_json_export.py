#!/usr/bin/env python3
"""
Test für JSON-Export-Funktionalität
Prüft ob run_rewe_once.main() die erwartete JSON-Datei erzeugt
"""

import logging
import sys
import re
from datetime import datetime
from pathlib import Path

# Import des Moduls
try:
    from run_rewe_once import main as run_main
except ImportError:
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from run_rewe_once import main as run_main

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Konfiguration
OUTPUT_DIR = Path(__file__).parent / "output"
FILE_PATTERN = re.compile(r'angebote_rewe_\d{8}\.json')


def find_export_file():
    """Findet die erzeugte JSON-Datei."""
    if not OUTPUT_DIR.exists():
        return None
    
    # Suche nach Datei mit Pattern angebote_rewe_YYYYMMDD.json
    for file_path in OUTPUT_DIR.glob('angebote_rewe_*.json'):
        if FILE_PATTERN.match(file_path.name):
            return file_path
    
    return None


def test_json_export():
    """Testet ob JSON-Export funktioniert."""
    logger.info("=" * 60)
    logger.info("TEST: JSON-Export-Funktionalität")
    logger.info("=" * 60)
    
    # Lösche eventuell vorhandene alte Test-Dateien
    existing_file = find_export_file()
    if existing_file:
        logger.info(f"Lösche vorhandene Test-Datei: {existing_file.name}")
        existing_file.unlink()
    
    # Rufe main() auf
    logger.info("Rufe run_rewe_once.main() auf...")
    try:
        exit_code = run_main()
        logger.info(f"run_rewe_once.main() beendet mit Exit-Code: {exit_code}")
    except Exception as e:
        logger.error(f"❌ Fehler beim Aufruf von run_rewe_once.main(): {e}")
        return False
    
    # Prüfe ob Datei erzeugt wurde
    logger.info("Prüfe ob JSON-Datei erzeugt wurde...")
    export_file = find_export_file()
    
    if export_file and export_file.exists():
        logger.info(f"✅ Datei gefunden: {export_file.name}")
        
        # Prüfe Dateigröße
        file_size = export_file.stat().st_size
        logger.info(f"📊 Dateigröße: {file_size} Bytes")
        
        if file_size > 0:
            logger.info("✅ Datei ist nicht leer")
        else:
            logger.warning("⚠️  Datei ist leer")
        
        # Lösche Datei nach Test
        logger.info("Lösche Test-Datei...")
        try:
            export_file.unlink()
            logger.info(f"✅ Datei gelöscht: {export_file.name}")
            logger.info("=" * 60)
            logger.info("✅ Test bestanden: Datei erfolgreich erzeugt und gelöscht.")
            logger.info("=" * 60)
            return True
        except Exception as e:
            logger.error(f"❌ Fehler beim Löschen der Datei: {e}")
            return False
    else:
        logger.error("=" * 60)
        logger.error("❌ Fehler: Datei wurde nicht erstellt.")
        logger.error("=" * 60)
        return False


def main():
    """Hauptfunktion."""
    success = test_json_export()
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

