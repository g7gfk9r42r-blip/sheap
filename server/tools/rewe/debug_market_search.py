#!/usr/bin/env python3
"""
Debug-Script für REWE Markt-Suche
Hilft beim Finden der richtigen API-Endpunkte
"""

import json
import logging
import re
import sys
import requests
from pathlib import Path

logging.basicConfig(level=logging.DEBUG, format='%(levelname)s: %(message)s')
logger = logging.getLogger(__name__)

ZIP_CODE = "53113"
REWE_BASE_URL = 'https://www.rewe.de'
REWE_OFFERS_URL = 'https://www.rewe.de/angebote/'

USER_AGENT = (
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Safari/537.36'
)

def test_api_endpoints():
    """Testet verschiedene API-Endpunkte."""
    session = requests.Session()
    session.headers.update({
        'User-Agent': USER_AGENT,
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'de-DE,de;q=0.9',
        'Referer': REWE_BASE_URL,
    })
    
    # Test 1: API-Endpunkt
    logger.info("=" * 60)
    logger.info("TEST 1: API-Endpunkt /api/markets/search")
    logger.info("=" * 60)
    try:
        url = f"{REWE_BASE_URL}/api/markets/search"
        response = session.get(url, params={'zip': ZIP_CODE}, timeout=10)
        logger.info(f"Status: {response.status_code}")
        logger.info(f"URL: {response.url}")
        if response.status_code == 200:
            try:
                data = response.json()
                logger.info(f"Response: {json.dumps(data, indent=2)[:500]}")
            except:
                logger.info(f"Response (Text): {response.text[:500]}")
        else:
            logger.warning(f"Response: {response.text[:300]}")
    except Exception as e:
        logger.error(f"Fehler: {e}")
    
    # Test 2: Angebotsseite mit PLZ
    logger.info("")
    logger.info("=" * 60)
    logger.info("TEST 2: Angebotsseite mit PLZ-Parameter")
    logger.info("=" * 60)
    try:
        url = f"{REWE_OFFERS_URL}?plz={ZIP_CODE}"
        response = session.get(url, timeout=10, allow_redirects=True)
        logger.info(f"Status: {response.status_code}")
        logger.info(f"Final URL: {response.url}")
        
        # Suche nach Markt-ID in URL
        match = re.search(r'/markt/(\d+)', response.url)
        if match:
            logger.info(f"✅ Markt-ID in URL gefunden: {match.group(1)}")
        else:
            logger.warning("❌ Keine Markt-ID in URL gefunden")
        
        # Suche nach Markt-ID im HTML
        html = response.text
        matches = re.findall(r'markt[_-]?id["\']?\s*[:=]\s*["\']?(\d+)', html, re.I)
        if matches:
            logger.info(f"✅ Markt-ID im HTML gefunden: {matches[0]}")
        else:
            logger.warning("❌ Keine Markt-ID im HTML gefunden")
        
        # Suche nach JSON-Daten im HTML
        json_matches = re.findall(r'\{[^{}]*"marketId"[^{}]*\}', html)
        if json_matches:
            logger.info(f"✅ JSON-Daten gefunden: {json_matches[0][:200]}")
        
    except Exception as e:
        logger.error(f"Fehler: {e}")
    
    # Test 3: Alternative Endpunkte
    logger.info("")
    logger.info("=" * 60)
    logger.info("TEST 3: Alternative Endpunkte")
    logger.info("=" * 60)
    
    alternative_urls = [
        f"{REWE_BASE_URL}/api/stores/search?zip={ZIP_CODE}",
        f"{REWE_BASE_URL}/api/markets?zip={ZIP_CODE}",
        f"{REWE_BASE_URL}/angebote/api/markets?zip={ZIP_CODE}",
    ]
    
    for url in alternative_urls:
        try:
            response = session.get(url, timeout=5)
            logger.info(f"URL: {url}")
            logger.info(f"Status: {response.status_code}")
            if response.status_code == 200:
                try:
                    data = response.json()
                    logger.info(f"✅ JSON-Response: {json.dumps(data, indent=2)[:300]}")
                except:
                    logger.info(f"Response: {response.text[:200]}")
            logger.info("")
        except Exception as e:
            logger.warning(f"Fehler bei {url}: {e}")

if __name__ == '__main__':
    test_api_endpoints()

