#!/usr/bin/env python3
"""
REWE Angebots-Scraper
=====================

⚠️  RECHTLICHE HINWEISE:
- Dieses Script nutzt nicht-dokumentierte Endpunkte der REWE-Website.
- Bitte prüfe vor Nutzung:
  1. REWE AGB: https://www.rewe.de/service/agb/
  2. robots.txt: https://www.rewe.de/robots.txt
  3. Ob automatisierte Abfragen erlaubt sind
- Nutze Rate-Limiting und respektiere Server-Last
- Für kommerzielle Nutzung: Kontaktiere REWE für eine offizielle API/Partnerschaft

Technische Hinweise:
- REWE nutzt dynamische JavaScript-Ladung, daher kann reines HTML-Parsing limitiert sein
- Die Angebotsdaten werden oft über JSON-Endpunkte geladen (Network-Tab im Browser prüfen)
- Bei Strukturänderungen: Selektoren in `_extract_offer_data()` anpassen
"""

import json
import logging
import re
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional
from urllib.parse import urlencode

import requests
from bs4 import BeautifulSoup

# Logging konfigurieren
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# KONFIGURATION & RATE-LIMITING
# ============================================================================

# TODO: Prüfe robots.txt und passe ggf. an
REQUEST_DELAY_SECONDS = 2.0  # Mindest-Abstand zwischen Requests (höflich)
MAX_RETRIES = 3
TIMEOUT_SECONDS = 30

# Höflicher User-Agent (kein Bot-Name)
USER_AGENT = (
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120.0.0.0 Safari/537.36'
)

# REWE-Basis-URLs
REWE_BASE_URL = 'https://www.rewe.de'
REWE_OFFERS_URL = 'https://www.rewe.de/angebote/'


# ============================================================================
# HAUPTFUNKTION
# ============================================================================

def fetch_rewe_offers(zip_code: str, market_id: Optional[str] = None) -> List[Dict]:
    """
    Ruft REWE-Angebote für eine bestimmte PLZ ab.
    
    Args:
        zip_code: Deutsche Postleitzahl (z.B. "53113")
        market_id: Optional: Spezifische Markt-ID (falls bekannt)
    
    Returns:
        Liste von Angebots-Dictionaries mit:
        - title: Produktname
        - price: Preis als float
        - price_str: Preis als String (z.B. "1,99 €")
        - unit: Einheit (z.B. "kg", "Stück", "Packung")
        - valid_from: Startdatum (ISO-Format)
        - valid_to: Enddatum (ISO-Format)
        - image_url: URL zum Produktbild (optional)
        - category: Kategorie (optional)
        - brand: Marke (optional)
        
        Gibt IMMER eine Liste zurück:
        - Leere Liste [] wenn kein Markt für die PLZ gefunden wurde
        - Leere Liste [] wenn keine Angebote extrahiert werden konnten
        - Liste mit Angeboten bei erfolgreicher Abfrage
    
    Raises:
        requests.RequestException: Bei schwerwiegenden HTTP-Fehlern (z.B. 500, Timeout)
        
    Note:
        Bei "kein Markt gefunden" wird eine Warnung geloggt und eine leere Liste
        zurückgegeben (keine Exception). Dies ermöglicht es Cron-Jobs, weiterzulaufen
        und später einen Fallback (z.B. nächster Markt im Umkreis) zu implementieren.
    """
    logger.info(f"Starte Abfrage für PLZ {zip_code}")
    
    session = requests.Session()
    session.headers.update({
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-DE,de;q=0.9',
        'Referer': REWE_BASE_URL,
    })
    
    try:
        # Schritt 1: Markt-ID ermitteln (falls nicht gegeben)
        if not market_id:
            logger.info(f"Suche REWE-Markt für PLZ {zip_code}...")
            market_id = _get_market_id_for_zip(session, zip_code)
            
            if not market_id:
                logger.warning(
                    f"⚠️  Kein REWE-Markt für PLZ {zip_code} gefunden. "
                    f"Gebe leere Liste zurück."
                )
                # TODO: Fallback-Implementierung möglich:
                # - Suche nach nächstgelegenem Markt im Umkreis (z.B. 10km)
                # - Nutze eine Standard-Markt-ID als Fallback
                # - Versuche alternative PLZ-Formate (z.B. mit führender 0)
                return []
            
            logger.info(f"✅ Markt-ID gefunden: {market_id}")
        
        # Schritt 2: Angebotsseite laden
        offers_page_url = _build_offers_url(zip_code, market_id)
        logger.info(f"Lade Angebote von: {offers_page_url}")
        
        response = session.get(offers_page_url, timeout=TIMEOUT_SECONDS)
        response.raise_for_status()
        
        # Rate-Limiting: Warte zwischen Requests
        time.sleep(REQUEST_DELAY_SECONDS)
        
        # Schritt 3: Angebote extrahieren
        logger.info("Extrahiere Angebote aus HTML...")
        offers = _extract_offers_from_html(response.text, zip_code)
        
        if not offers:
            logger.warning(f"⚠️  Keine Angebote aus HTML extrahiert für PLZ {zip_code}")
            return []
        
        logger.info(f"✅ {len(offers)} Angebote erfolgreich extrahiert")
        return offers
        
    except requests.RequestException as e:
        # Bei schwerwiegenden HTTP-Fehlern (500, Timeout) Exception werfen
        # Dies signalisiert dem Cron-Job einen echten Fehler
        logger.error(f"❌ HTTP-Fehler beim Abruf der Angebote: {e}")
        raise
    except Exception as e:
        # Unerwartete Fehler: Loggen und leere Liste zurückgeben
        # (statt Exception zu werfen, damit Cron-Job weiterläuft)
        logger.error(f"❌ Unerwarteter Fehler beim Abruf: {e}", exc_info=True)
        logger.warning(f"Gebe leere Liste zurück aufgrund des Fehlers")
        return []


# ============================================================================
# HILFSFUNKTIONEN
# ============================================================================

def _get_market_id_for_zip(session: requests.Session, zip_code: str) -> Optional[str]:
    """
    Ermittelt die Markt-ID für eine PLZ.
    
    TODO: REWE nutzt möglicherweise JavaScript für Markt-Auswahl.
          Prüfe im Browser-Network-Tab, welcher Endpunkt aufgerufen wird.
    
    Returns:
        Markt-ID als String, oder None wenn kein Markt gefunden wurde.
    """
    # Ansatz 1: Versuche Markt-Suche über API
    search_url = f"{REWE_BASE_URL}/api/markets/search"
    params = {'zip': zip_code}
    
    try:
        logger.debug(f"Versuche Markt-Suche über API: {search_url}")
        response = session.get(search_url, params=params, timeout=TIMEOUT_SECONDS)
        if response.status_code == 200:
            data = response.json()
            markets = data.get('markets', [])
            
            if markets and len(markets) > 0:
                market_id = markets[0].get('id')
                market_name = markets[0].get('name', 'Unbekannt')
                logger.info(f"✅ {len(markets)} Markt/Märkte gefunden (verwende: {market_name}, ID: {market_id})")
                return market_id
            else:
                logger.debug(f"API-Antwort enthält keine Märkte für PLZ {zip_code}")
    except requests.RequestException as e:
        logger.warning(f"Markt-Suche über API fehlgeschlagen (HTTP): {e}")
    except Exception as e:
        logger.warning(f"Markt-Suche über API fehlgeschlagen: {e}")
    
    # Ansatz 2: Fallback: Parse HTML der Angebotsseite
    # REWE leitet oft automatisch zum nächstgelegenen Markt weiter
    try:
        offers_url = f"{REWE_OFFERS_URL}?plz={zip_code}"
        logger.debug(f"Versuche Markt-ID aus HTML-URL zu extrahieren: {offers_url}")
        response = session.get(offers_url, timeout=TIMEOUT_SECONDS, allow_redirects=True)
        
        # Extrahiere Markt-ID aus URL oder HTML
        # TODO: Anpassen, falls REWE die Struktur ändert
        match = re.search(r'/markt/(\d+)', response.url)
        if match:
            market_id = match.group(1)
            logger.info(f"✅ Markt-ID aus URL extrahiert: {market_id}")
            return market_id
        else:
            logger.debug(f"Keine Markt-ID in URL gefunden: {response.url}")
    except requests.RequestException as e:
        logger.warning(f"Markt-ID-Ermittlung aus HTML fehlgeschlagen (HTTP): {e}")
    except Exception as e:
        logger.warning(f"Markt-ID-Ermittlung aus HTML fehlgeschlagen: {e}")
    
    logger.debug(f"Keine Markt-ID für PLZ {zip_code} gefunden")
    return None


def _build_offers_url(zip_code: str, market_id: Optional[str] = None) -> str:
    """Baut die URL für die Angebotsseite."""
    if market_id:
        return f"{REWE_OFFERS_URL}markt/{market_id}/"
    return f"{REWE_OFFERS_URL}?plz={zip_code}"


def _extract_offers_from_html(html: str, zip_code: str) -> List[Dict]:
    """
    Extrahiert Angebote aus dem HTML.
    
    ⚠️  WICHTIG: Diese Selektoren müssen angepasst werden, wenn REWE die HTML-Struktur ändert.
    Prüfe regelmäßig im Browser (Inspect Element) die aktuelle Struktur.
    """
    soup = BeautifulSoup(html, 'html.parser')
    offers = []
    
    # TODO: Anpassen basierend auf aktueller REWE-Struktur
    # Mögliche Ansätze:
    # 1. Suche nach JSON-LD-Structured-Data
    # 2. Parse Angebots-Karten (div.article-card, .product-tile, etc.)
    # 3. Suche nach <script>-Tags mit JSON-Daten
    
    # Ansatz 1: JSON-LD (falls vorhanden)
    json_ld_scripts = soup.find_all('script', type='application/ld+json')
    for script in json_ld_scripts:
        try:
            data = json.loads(script.string)
            if isinstance(data, dict) and data.get('@type') == 'Product':
                offer = _parse_json_ld_product(data)
                if offer:
                    offers.append(offer)
        except (json.JSONDecodeError, KeyError):
            continue
    
    # Ansatz 2: HTML-Karten parsen
    # TODO: CSS-Selektoren anpassen (prüfe im Browser)
    offer_cards = soup.select(
        'article.article-card, '
        '.product-tile, '
        '.offer-item, '
        '[data-product-id]'
    )
    
    for card in offer_cards:
        offer = _extract_offer_from_card(card)
        if offer:
            offers.append(offer)
    
    # Ansatz 3: Suche nach eingebetteten JSON-Daten in <script>-Tags
    scripts = soup.find_all('script', string=re.compile(r'products|offers|angebote', re.I))
    for script in scripts:
        # Versuche JSON zu extrahieren
        json_match = re.search(r'\{.*"products".*\}', script.string or '', re.DOTALL)
        if json_match:
            try:
                data = json.loads(json_match.group(0))
                parsed = _parse_json_offers(data)
                offers.extend(parsed)
            except (json.JSONDecodeError, KeyError):
                continue
    
    # Gültigkeitszeitraum ermitteln
    valid_from, valid_to = _extract_validity_period(soup)
    
    # Füge Zeitraum zu allen Angeboten hinzu
    for offer in offers:
        if not offer.get('valid_from'):
            offer['valid_from'] = valid_from
        if not offer.get('valid_to'):
            offer['valid_to'] = valid_to
    
    return offers


def _extract_offer_from_card(card) -> Optional[Dict]:
    """Extrahiert Angebotsdaten aus einer HTML-Karte."""
    try:
        # TODO: Selektoren anpassen basierend auf aktueller REWE-Struktur
        title_elem = card.select_one('.product-title, .article-title, h3, [data-product-name]')
        price_elem = card.select_one('.price, .product-price, [data-price]')
        image_elem = card.select_one('img[src], img[data-src]')
        
        if not title_elem:
            return None
        
        title = title_elem.get_text(strip=True)
        price_str = price_elem.get_text(strip=True) if price_elem else ''
        
        # Preis parsen (z.B. "1,99 €" -> 1.99)
        price = _parse_price(price_str)
        
        # Einheit extrahieren (z.B. "pro kg", "je Stück")
        unit = _extract_unit(card)
        
        # Bild-URL
        image_url = None
        if image_elem:
            image_url = image_elem.get('src') or image_elem.get('data-src')
            if image_url and not image_url.startswith('http'):
                image_url = REWE_BASE_URL + image_url
        
        return {
            'title': title,
            'price': price,
            'price_str': price_str,
            'unit': unit,
            'image_url': image_url,
        }
    except Exception as e:
        logger.warning(f"Fehler beim Parsen einer Karte: {e}")
        return None


def _parse_price(price_str: str) -> float:
    """Konvertiert deutschen Preis-String in float."""
    # Entferne Währungssymbol und Leerzeichen
    cleaned = re.sub(r'[€\s]', '', price_str)
    # Ersetze Komma durch Punkt
    cleaned = cleaned.replace(',', '.')
    # Extrahiere Zahl
    match = re.search(r'(\d+\.?\d*)', cleaned)
    if match:
        return float(match.group(1))
    return 0.0


def _extract_unit(card) -> str:
    """Extrahiert Mengeneinheit aus Karte."""
    # TODO: Anpassen basierend auf REWE-Struktur
    unit_elem = card.select_one('.unit, .price-unit, [data-unit]')
    if unit_elem:
        unit_text = unit_elem.get_text(strip=True).lower()
        if 'kg' in unit_text:
            return 'kg'
        elif 'g' in unit_text and 'kg' not in unit_text:
            return 'g'
        elif 'l' in unit_text or 'liter' in unit_text:
            return 'l'
        elif 'ml' in unit_text:
            return 'ml'
        elif 'stück' in unit_text or 'stk' in unit_text:
            return 'Stück'
    return 'Packung'  # Default


def _extract_validity_period(soup: BeautifulSoup) -> tuple[str, str]:
    """Ermittelt Gültigkeitszeitraum aus HTML."""
    # TODO: Anpassen basierend auf REWE-Struktur
    # Suche nach Text wie "Gültig: 01.12. - 07.12.2025"
    validity_text = soup.get_text()
    
    # Pattern: "01.12. - 07.12.2025" oder "01.12.2025 - 07.12.2025"
    pattern = r'(\d{1,2})\.(\d{1,2})\.(?:(\d{4}))?\s*[-–]\s*(\d{1,2})\.(\d{1,2})\.(\d{4})'
    match = re.search(pattern, validity_text)
    
    if match:
        # Parse Datum
        day1, month1, year1, day2, month2, year2 = match.groups()
        current_year = datetime.now().year
        year1 = int(year1) if year1 else current_year
        year2 = int(year2) if year2 else current_year
        
        try:
            valid_from = datetime(int(year1), int(month1), int(day1))
            valid_to = datetime(int(year2), int(month2), int(day2))
            return valid_from.strftime('%Y-%m-%d'), valid_to.strftime('%Y-%m-%d')
        except ValueError:
            pass
    
    # Fallback: Aktuelle Woche
    today = datetime.now()
    monday = today - timedelta(days=today.weekday())
    sunday = monday + timedelta(days=6)
    return monday.strftime('%Y-%m-%d'), sunday.strftime('%Y-%m-%d')


def _parse_json_ld_product(data: Dict) -> Optional[Dict]:
    """Parst JSON-LD Product-Daten."""
    try:
        offers = data.get('offers', {})
        return {
            'title': data.get('name', ''),
            'price': float(offers.get('price', 0)),
            'price_str': f"{offers.get('price', 0):.2f} €",
            'unit': offers.get('priceCurrency', 'EUR'),
        }
    except (KeyError, ValueError):
        return None


def _parse_json_offers(data: Dict) -> List[Dict]:
    """Parst JSON-Angebotsdaten."""
    offers = []
    products = data.get('products', []) or data.get('offers', [])
    
    for product in products:
        try:
            offers.append({
                'title': product.get('name', ''),
                'price': float(product.get('price', 0)),
                'price_str': product.get('priceDisplay', ''),
                'unit': product.get('unit', 'Packung'),
                'image_url': product.get('imageUrl'),
            })
        except (KeyError, ValueError):
            continue
    
    return offers


# ============================================================================
# CLI & HAUPTFUNKTION
# ============================================================================

def main():
    """Beispiel-Nutzung des Scripts."""
    import argparse
    
    parser = argparse.ArgumentParser(description='REWE-Angebote abrufen')
    parser.add_argument('zip_code', help='Postleitzahl (z.B. 53113)')
    parser.add_argument('--output', '-o', help='Ausgabe-Datei (JSON)')
    parser.add_argument('--market-id', help='Spezifische Markt-ID (optional)')
    
    args = parser.parse_args()
    
    try:
        offers = fetch_rewe_offers(args.zip_code, args.market_id)
        
        if not offers:
            logger.warning("Keine Angebote gefunden")
            return
        
        # Ausgabe
        output_file = args.output or f"rewe_offers_{args.zip_code}_{datetime.now().strftime('%Y%m%d')}.json"
        
        output_data = {
            'market': 'REWE',
            'zip_code': args.zip_code,
            'fetched_at': datetime.now().isoformat(),
            'total_offers': len(offers),
            'offers': offers,
        }
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        logger.info(f"✅ Angebote gespeichert: {output_file}")
        print(f"\n📊 {len(offers)} Angebote gefunden und gespeichert in: {output_file}")
        
    except Exception as e:
        logger.error(f"Fehler: {e}")
        raise


if __name__ == '__main__':
    main()

