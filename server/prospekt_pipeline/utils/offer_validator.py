"""Comprehensive validation and filtering of extracted offers."""
from __future__ import annotations

import re
from typing import Optional

from .logger import get_logger

LOGGER = get_logger("utils.validator")

# Patterns für Müll-Daten
QR_CODE_PATTERNS = [
    re.compile(r"qr[- ]?code", re.IGNORECASE),
    re.compile(r"https?://[^\s]+", re.IGNORECASE),  # URLs
    re.compile(r"www\.[^\s]+", re.IGNORECASE),
    re.compile(r"[a-z0-9]{20,}", re.IGNORECASE),  # Lange alphanumerische Strings (QR-Code-Inhalte)
    re.compile(r"[A-Z0-9]{15,}"),  # Lange Großbuchstaben-Zahlen-Kombinationen
    re.compile(r"^[0-9A-F]{32,}$", re.IGNORECASE),  # MD5/Hash-ähnliche Strings
]

JUNK_PATTERNS = [
    re.compile(r"^[0-9\s\-\.]+$"),  # Nur Zahlen
    re.compile(r"^[A-Z0-9]{8,}$"),  # Nur Großbuchstaben/Zahlen (Codes)
    re.compile(r"^(impressum|datenschutz|agb|versand|lieferung|kontakt|adresse|telefon|email)", re.IGNORECASE),
    re.compile(r"^(seite|page|p\.?)\s*\d+", re.IGNORECASE),
    re.compile(r"^\d+\.\d+\.\d+", re.IGNORECASE),  # Datum
    re.compile(r"^[€$]\s*$"),  # Nur Währungssymbol
    re.compile(r"^[a-z]{1,2}$", re.IGNORECASE),  # Zu kurz (1-2 Buchstaben)
    re.compile(r"^(von|bis|ab|gültig|gültigkeit)", re.IGNORECASE),  # Zeitangaben ohne Produkt
    re.compile(r"^(prospekt|angebot|aktion|rabatt|preis)", re.IGNORECASE),  # Generische Begriffe allein
    re.compile(r"^[^\w\s]+$"),  # Nur Sonderzeichen
    re.compile(r"^\d+\s*(?:x|×)\s*\d+", re.IGNORECASE),  # Nur Dimensionen (z.B. "10 x 20")
]

# Produkt-Keywords die auf echte Angebote hindeuten
PRODUCT_KEYWORDS = [
    r"\b(?:kg|g|ml|l|L|stück|stk|packung|pack|dose|flasche|glas|beutel|tube|tüte)\b",
    r"\b(?:bio|organic|frisch|frische|frozen|tiefkühl|tiefgekühlt)\b",
    r"\b(?:käse|milch|joghurt|butter|eier|fleisch|wurst|brot|brötchen|obst|gemüse)\b",
    r"\b(?:kaffee|tee|wasser|saft|limonade|bier|wein|schnaps)\b",
    r"\b(?:nudeln|reis|mehl|zucker|salz|öl|essig|gewürz)\b",
]

MIN_TITLE_LENGTH = 3
MAX_TITLE_LENGTH = 200
MIN_PRICE = 0.01
MAX_PRICE = 10000.0
MIN_WORD_COUNT = 1  # Mindestens 1 Wort (kann auch ein Produktname sein)


def is_valid_offer(title: Optional[str], price: Optional[str] = None) -> bool:
    """Prüft ob ein Angebot gültig ist (kein QR-Code, keine URL, etc.)."""
    if not title:
        return False
    
    title = title.strip()
    
    # Zu kurz oder zu lang
    if len(title) < MIN_TITLE_LENGTH or len(title) > MAX_TITLE_LENGTH:
        return False
    
    # Mindestens ein Wort
    words = title.split()
    if len(words) < MIN_WORD_COUNT:
        return False
    
    # QR-Code oder URL erkannt
    for pattern in QR_CODE_PATTERNS:
        if pattern.search(title):
            LOGGER.debug("Filtered QR/URL: %s", title[:50])
            return False
    
    # Junk-Patterns
    for pattern in JUNK_PATTERNS:
        if pattern.match(title):
            LOGGER.debug("Filtered junk: %s", title[:50])
            return False
    
    # Mindestens ein Buchstabe muss enthalten sein
    if not re.search(r"[a-zA-ZäöüÄÖÜß]", title):
        return False
    
    # Zu viele Zahlen im Verhältnis zu Buchstaben (wahrscheinlich ein Code)
    letter_count = len(re.findall(r"[a-zA-ZäöüÄÖÜß]", title))
    digit_count = len(re.findall(r"[0-9]", title))
    if digit_count > 0 and letter_count > 0:
        ratio = digit_count / (letter_count + digit_count)
        if ratio > 0.7:  # Mehr als 70% Zahlen
            LOGGER.debug("Filtered code-like: %s (ratio: %.2f)", title[:50], ratio)
            return False
    
    # Preis-Validierung (falls vorhanden)
    if price:
        try:
            # Entferne Währungssymbol und konvertiere
            price_str = price.replace("€", "").replace("EUR", "").replace(",", ".").strip()
            # Entferne Einheiten
            price_str = re.sub(r"\s*(?:kg|l|L|g|ml)\s*", "", price_str, flags=re.IGNORECASE)
            price_float = float(price_str)
            if price_float < MIN_PRICE or price_float > MAX_PRICE:
                LOGGER.debug("Filtered invalid price: %s (%.2f)", title[:50], price_float)
                return False
        except (ValueError, AttributeError):
            pass  # Preis-Parsing fehlgeschlagen, aber Titel ist ok
    
    # Bonus: Wenn Produkt-Keywords vorhanden, ist es wahrscheinlich ein echtes Angebot
    has_product_keyword = any(re.search(keyword, title, re.IGNORECASE) for keyword in PRODUCT_KEYWORDS)
    if has_product_keyword:
        return True
    
    # Wenn kein Produkt-Keyword, aber mindestens 2 Wörter und Buchstaben vorhanden, akzeptieren
    if len(words) >= 2 and letter_count >= 3:
        return True
    
    # Sonst ablehnen (zu generisch oder unklar)
    if len(words) == 1 and letter_count < 5:
        LOGGER.debug("Filtered too generic: %s", title[:50])
        return False
    
    return True


def clean_title(title: str) -> str:
    """Bereinigt einen Titel von OCR-Artefakten und normalisiert ihn."""
    if not title:
        return ""
    
    # Entferne führende/trailing Sonderzeichen
    title = re.sub(r"^[^\w]+|[^\w]+$", "", title)
    
    # Entferne mehrfache Leerzeichen
    title = re.sub(r"\s+", " ", title)
    
    # Entferne isolierte Zeichen (z.B. "a | b" -> "a b")
    title = re.sub(r"\s+[|¦§]\s+", " ", title)
    
    # Entferne isolierte Zahlen am Anfang/Ende (wahrscheinlich Seitenzahlen)
    title = re.sub(r"^\d+\s+|\s+\d+$", "", title)
    
    # Entferne häufige OCR-Fehler
    title = title.replace("|", "l").replace("¦", "l")  # | wird oft als l gelesen
    title = re.sub(r"([a-z])\s+([a-z])", r"\1\2", title)  # Leerzeichen in Wörtern entfernen
    
    # Normalisiere häufige Fehler
    title = title.replace("rn", "m").replace("vv", "w").replace("ii", "n")
    
    return title.strip()


def extract_product_name(text: str) -> Optional[str]:
    """Extrahiert den Produktnamen aus einem Textblock."""
    # Entferne Preise
    text = re.sub(r"\d+[\.,]\d{1,2}\s*€", "", text)
    # Entferne Einheitspreise
    text = re.sub(r"\d+[\.,]\d{1,2}\s*(?:kg|l|L|g|ml)", "", text)
    # Entferne Rabatte
    text = re.sub(r"-\s*\d+\s*%", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\d+[\.,]\d{1,2}\s*€\s*sparen", "", text, flags=re.IGNORECASE)
    # Entferne Datumsangaben
    text = re.sub(r"\d+\.\d+\.\d+", "", text)
    # Entferne Seitenzahlen
    text = re.sub(r"(?:seite|page|p\.?)\s*\d+", "", text, flags=re.IGNORECASE)
    
    cleaned = clean_title(text)
    return cleaned if cleaned and len(cleaned) >= 3 else None
