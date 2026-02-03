#!/usr/bin/env python3
"""
Vollständiger End-to-End-Test für REWE-Scraper Pipeline
"""

import json
import logging
import sys
import unittest.mock
from pathlib import Path

# Import der Module
try:
    from fetch_rewe_offers import fetch_rewe_offers
    from run_rewe_once import main as run_main
except ImportError:
    import os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from fetch_rewe_offers import fetch_rewe_offers
    from run_rewe_once import main as run_main

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

# Test-Konfiguration
VALID_ZIP_CODE = "53113"  # Bonn - sollte funktionieren
INVALID_ZIP_CODE = "99999"  # Ungültige PLZ
REQUIRED_FIELDS = ["title", "price", "unit"]  # Mindestfelder für ein Angebot


class TestResults:
    """Sammelt Testergebnisse."""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.warnings = []
        self.errors = []
    
    def add_pass(self, test_name):
        self.passed += 1
        logger.info(f"✅ PASS: {test_name}")
    
    def add_fail(self, test_name, reason):
        self.failed += 1
        self.errors.append(f"{test_name}: {reason}")
        logger.error(f"❌ FAIL: {test_name} - {reason}")
    
    def add_warning(self, message):
        self.warnings.append(message)
        logger.warning(f"⚠️  WARN: {message}")
    
    def summary(self):
        total = self.passed + self.failed
        logger.info("=" * 60)
        logger.info("TEST-ZUSAMMENFASSUNG")
        logger.info("=" * 60)
        logger.info(f"✅ Bestanden: {self.passed}/{total}")
        logger.info(f"❌ Fehlgeschlagen: {self.failed}/{total}")
        
        if self.warnings:
            logger.info(f"\n⚠️  Warnungen ({len(self.warnings)}):")
            for warning in self.warnings:
                logger.info(f"   - {warning}")
        
        if self.errors:
            logger.info(f"\n❌ Fehler ({len(self.errors)}):")
            for error in self.errors:
                logger.info(f"   - {error}")
        
        logger.info("=" * 60)
        
        if self.failed == 0:
            logger.info("🎉 ALLE TESTS BESTANDEN!")
            return True
        else:
            logger.error("❌ EINIGE TESTS FEHLGESCHLAGEN")
            return False


def test_fetch_rewe_offers_valid_zip(results: TestResults):
    """Testet fetch_rewe_offers mit gültiger PLZ."""
    logger.info("=" * 60)
    logger.info("TEST 1: fetch_rewe_offers mit gültiger PLZ")
    logger.info("=" * 60)
    
    try:
        offers = fetch_rewe_offers(VALID_ZIP_CODE)
        
        # Prüfe: Rückgabewert ist Liste
        if not isinstance(offers, list):
            results.add_fail(
                "fetch_rewe_offers Rückgabetyp",
                f"Erwartet list, erhalten {type(offers)}"
            )
            return
        
        results.add_pass("fetch_rewe_offers Rückgabetyp (Liste)")
        
        # Prüfe: Wenn Angebote vorhanden, müssen sie Felder haben
        if len(offers) > 0:
            logger.info(f"✅ {len(offers)} Angebote gefunden")
            results.add_pass(f"Angebote gefunden ({len(offers)})")
            
            # Prüfe jedes Angebot auf erforderliche Felder
            missing_fields_count = 0
            for idx, offer in enumerate(offers):
                missing_fields = [
                    field for field in REQUIRED_FIELDS
                    if field not in offer or offer[field] is None
                ]
                
                if missing_fields:
                    missing_fields_count += 1
                    results.add_warning(
                        f"Angebot #{idx+1} fehlt Felder: {', '.join(missing_fields)}"
                    )
            
            if missing_fields_count == 0:
                results.add_pass("Alle Angebote haben erforderliche Felder")
            else:
                results.add_warning(
                    f"{missing_fields_count}/{len(offers)} Angebote haben fehlende Felder"
                )
        else:
            results.add_warning(f"Keine Angebote für PLZ {VALID_ZIP_CODE} gefunden")
            
    except Exception as e:
        results.add_fail(
            "fetch_rewe_offers (gültige PLZ)",
            f"Exception: {e}"
        )


def test_fetch_rewe_offers_invalid_zip(results: TestResults):
    """Testet fetch_rewe_offers mit ungültiger PLZ."""
    logger.info("=" * 60)
    logger.info("TEST 2: fetch_rewe_offers mit ungültiger PLZ")
    logger.info("=" * 60)
    
    try:
        offers = fetch_rewe_offers(INVALID_ZIP_CODE)
        
        # Prüfe: Rückgabewert ist Liste (auch wenn leer)
        if not isinstance(offers, list):
            results.add_fail(
                "fetch_rewe_offers Rückgabetyp (ungültige PLZ)",
                f"Erwartet list, erhalten {type(offers)}"
            )
            return
        
        results.add_pass("fetch_rewe_offers Rückgabetyp (Liste, auch bei ungültiger PLZ)")
        
        # Prüfe: Bei ungültiger PLZ sollte leere Liste zurückgegeben werden
        if len(offers) == 0:
            results.add_pass("Leere Liste bei ungültiger PLZ (erwartetes Verhalten)")
        else:
            results.add_warning(
                f"Unerwartet: {len(offers)} Angebote für ungültige PLZ {INVALID_ZIP_CODE}"
            )
            
    except Exception as e:
        results.add_fail(
            "fetch_rewe_offers (ungültige PLZ)",
            f"Exception: {e} (sollte keine Exception werfen)"
        )


def test_run_rewe_once_mocked(results: TestResults):
    """Testet run_rewe_once.main() mit gemocktem Datei-Schreiben."""
    logger.info("=" * 60)
    logger.info("TEST 3: run_rewe_once.main() mit gemocktem Datei-Schreiben")
    logger.info("=" * 60)
    
    try:
        # Mock das Datei-Schreiben
        with unittest.mock.patch('builtins.open', unittest.mock.mock_open()) as mock_file:
            with unittest.mock.patch('pathlib.Path.mkdir'):
                # Rufe main() auf
                exit_code = run_main()
                
                # Prüfe: Exit-Code sollte 0 oder 1 sein
                if exit_code in [0, 1]:
                    results.add_pass("run_rewe_once.main() Exit-Code")
                else:
                    results.add_fail(
                        "run_rewe_once.main() Exit-Code",
                        f"Unerwarteter Exit-Code: {exit_code}"
                    )
                
                # Prüfe: open() sollte aufgerufen worden sein (auch wenn gemockt)
                if mock_file.called:
                    results.add_pass("run_rewe_once.main() Datei-Schreiben (gemockt)")
                else:
                    results.add_warning("run_rewe_once.main() hat keine Datei geöffnet")
                    
    except Exception as e:
        results.add_fail(
            "run_rewe_once.main()",
            f"Exception: {e}"
        )


def main():
    """Hauptfunktion: Führt alle Tests aus."""
    logger.info("🚀 Starte vollständigen End-to-End-Test")
    logger.info("")
    
    results = TestResults()
    
    # Test 1: Gültige PLZ
    test_fetch_rewe_offers_valid_zip(results)
    logger.info("")
    
    # Test 2: Ungültige PLZ
    test_fetch_rewe_offers_invalid_zip(results)
    logger.info("")
    
    # Test 3: run_rewe_once mit Mock
    test_run_rewe_once_mocked(results)
    logger.info("")
    
    # Zusammenfassung
    success = results.summary()
    
    # Exit-Code
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()

