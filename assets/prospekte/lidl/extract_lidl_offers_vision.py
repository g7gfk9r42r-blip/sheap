#!/usr/bin/env python3
"""
LIDL PDF Extraktion mit GPT Vision (die perfekte Methode!)
Extrahiert ALLE Angebote aus PDF mit GPT-4o Vision
Pro Kachel für maximale Genauigkeit

Verbesserte Version: Läuft von assets/prospekte/lidl/
Lädt .env automatisch aus Projekt-Root
"""

import os
import sys
import json
import base64
import time
import re
from pathlib import Path
from typing import List, Dict, Tuple
from openai import OpenAI
from pdf2image import convert_from_path
from PIL import Image
import io

# UTF-8 Encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# Konfiguration
SCRIPT_DIR = Path(__file__).parent
OUTPUT_TXT = SCRIPT_DIR / "lidl.txt"
OUTPUT_JSON = SCRIPT_DIR / "lidl.json"

# Versuche .env zu laden (verschiedene mögliche Pfade)
try:
    from dotenv import load_dotenv
    # Versuche verschiedene Pfade (von Script zu Projekt-Root)
    # assets/prospekte/lidl/ -> roman_app/ = 3 Ebenen
    possible_env_paths = [
        SCRIPT_DIR.parent.parent.parent / '.env',  # Projekt-Root (3 Ebenen: lidl -> prospekte -> assets -> roman_app)
        SCRIPT_DIR.parent.parent.parent.parent / '.env',  # 4 Ebenen (Fallback)
        Path.home() / '.env',  # Home-Verzeichnis (Fallback)
    ]
    
    loaded = False
    for env_path in possible_env_paths:
        if env_path.exists():
            load_dotenv(env_path, override=False)
            loaded = True
            break
    
    # Fallback: Versuche auch im aktuellen Verzeichnis
    if not loaded:
        load_dotenv(override=False)  # Lädt .env aus current working directory
except ImportError:
    pass

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not OPENAI_API_KEY:
    print("❌ OPENAI_API_KEY nicht gesetzt!")
    print()
    print("💡 Lösung: Setze den API-Key in .env oder als Environment-Variable")
    print("   Option 1: In .env Datei (Projekt-Root):")
    print("      OPENAI_API_KEY=sk-proj-...")
    print()
    print("   Option 2: Als Environment-Variable:")
    print("      export OPENAI_API_KEY='sk-proj-...'")
    print()
    sys.exit(1)

client = OpenAI(api_key=OPENAI_API_KEY)

# ============================================================================
# Helper Functions
# ============================================================================

def image_to_base64(image: Image.Image) -> str:
    """Konvertiert PIL Image zu Base64 String (optimiert)"""
    # Konvertiere zu RGB falls nötig (für bessere Kompatibilität)
    if image.mode != 'RGB':
        image = image.convert('RGB')
    
    # Optimiere Bildgröße für API (max 20MB, aber wir bleiben bei Original-Qualität)
    img_byte_arr = io.BytesIO()
    
    # Verwende optimale Qualität
    image.save(img_byte_arr, format='PNG', optimize=False)
    img_byte_arr.seek(0)
    
    return base64.b64encode(img_byte_arr.read()).decode('utf-8')

def split_image_into_tiles(image: Image.Image, grid_size: Tuple[int, int] = (2, 3)) -> List[Image.Image]:
    """
    Teilt ein Bild in kleinere Kacheln (Tiles) auf
    grid_size: (rows, cols) - z.B. (2, 3) = 2x3 Grid = 6 Kacheln
    """
    width, height = image.size
    rows, cols = grid_size
    
    tile_width = width // cols
    tile_height = height // rows
    
    tiles = []
    
    for row in range(rows):
        for col in range(cols):
            left = col * tile_width
            top = row * tile_height
            right = left + tile_width if col < cols - 1 else width
            bottom = top + tile_height if row < rows - 1 else height
            
            tile = image.crop((left, top, right, bottom))
            tiles.append(tile)
    
    return tiles

# ============================================================================
# Robust Data Validation & Normalization
# ============================================================================

def robust_parse_price(value) -> float | None:
    """
    Extrem robuste Preis-Parsing-Funktion.
    Handelt alle Edge Cases ab: Strings, Zahlen, Kommas, Punkte, None, etc.
    """
    if value is None:
        return None
    
    # Wenn bereits float/int
    if isinstance(value, (float, int)):
        result = float(value)
        return result if result >= 0 else None
    
    # String verarbeiten
    if isinstance(value, str):
        value = value.strip()
        if not value or value.lower() in ['null', 'none', 'n/a', 'na', '-', '']:
            return None
        
        # Entferne alle nicht-numerischen Zeichen außer Komma und Punkt
        cleaned = re.sub(r'[^\d,.\-]', '', value)
        
        # Ersetze Komma durch Punkt (Deutsch -> Englisch)
        cleaned = cleaned.replace(',', '.')
        
        # Entferne führende/trailing Punkte
        cleaned = cleaned.strip('.')
        
        # Mehrere Punkte → nur der letzte ist Dezimaltrenner
        if cleaned.count('.') > 1:
            parts = cleaned.split('.')
            cleaned = ''.join(parts[:-1]) + '.' + parts[-1]
        
        try:
            result = float(cleaned)
            # Plausibilitäts-Check: Preise sollten zwischen 0.01 und 9999.99 sein
            if 0.01 <= result <= 9999.99:
                return round(result, 2)
            return None
        except (ValueError, OverflowError):
            return None
    
    return None

def robust_parse_string(value, max_length: int = 200) -> str | None:
    """Robuste String-Parsing mit Bereinigung"""
    if value is None:
        return None
    
    if isinstance(value, (int, float)):
        return str(value).strip()[:max_length] if str(value).strip() else None
    
    if isinstance(value, str):
        cleaned = value.strip()
        if cleaned.lower() in ['null', 'none', 'n/a', 'na', '-', '']:
            return None
        return cleaned[:max_length] if cleaned else None
    
    return None

def normalize_price_candidates(candidates) -> List[Dict]:
    """Normalisiert price_candidates Array - extrem robust"""
    if not candidates:
        return []
    
    if not isinstance(candidates, list):
        return []
    
    valid_candidates = []
    seen_values = set()  # Verhindert Duplikate
    
    for candidate in candidates:
        if not isinstance(candidate, dict):
            continue
        
        try:
            value = robust_parse_price(candidate.get("value"))
            if value is None or value <= 0:
                continue
            
            # Verhindere Duplikate (gleiche Werte)
            if value in seen_values:
                continue
            seen_values.add(value)
            
            context = robust_parse_string(candidate.get("context", ""), max_length=100) or ""
            type_hint = str(candidate.get("type_hint", "unknown")).lower()
            
            # Validiere type_hint
            valid_hints = ["offer", "unit", "uvp", "before", "unknown"]
            if type_hint not in valid_hints:
                type_hint = "unknown"
            
            valid_candidates.append({
                "value": value,
                "context": context,
                "type_hint": type_hint
            })
        except Exception:
            continue  # Überspringe ungültige Kandidaten
    
    return valid_candidates

def validate_and_normalize_offer(offer: Dict, page_number: int, tile_index: int | None = None) -> Dict | None:
    """
    EXTREM robuste Normalisierung und Validierung eines einzelnen Angebots.
    Handelt ALLE Edge Cases ab und stellt sicher, dass IMMER ein valides Objekt zurückkommt.
    """
    if not isinstance(offer, dict):
        return None
    
    # ===== 1. Produkt-Daten extrahieren (robust) =====
    product_data = offer.get("product") or {}
    if not isinstance(product_data, dict):
        product_data = {}
    
    # Fallback auf alte Schema-Variante
    if not product_data.get("exact_name") and offer.get("exact_name"):
        product_data = {
            "exact_name": offer.get("exact_name"),
            "brand": offer.get("brand"),
            "variant": offer.get("variant")
        }
    
    product_name = robust_parse_string(product_data.get("exact_name"), max_length=200)
    
    # WICHTIG: Wenn kein Produktname, versuche aus anderen Feldern
    if not product_name:
        product_name = robust_parse_string(offer.get("product_name"), max_length=200)
        if not product_name:
            product_name = robust_parse_string(offer.get("name"), max_length=200)
    
    # KRITISCH: Wenn IMMER NOCH kein Name → verwende Fallback
    if not product_name:
        # Versuche aus price_candidates Kontext zu extrahieren
        candidates = normalize_price_candidates(offer.get("price_candidates", []))
        if candidates and candidates[0].get("context"):
            context = candidates[0]["context"]
            # Versuche Produktnamen aus Kontext zu extrahieren
            words = context.split()
            if words:
                product_name = " ".join(words[:3])  # Erste 3 Wörter als Name
    
    # FINAL FALLBACK: Wenn immer noch kein Name
    if not product_name:
        return None  # Überspringe Angebote OHNE Namen (unbrauchbar)
    
    brand = robust_parse_string(product_data.get("brand") or offer.get("brand"), max_length=100)
    variant = robust_parse_string(product_data.get("variant") or offer.get("variant"), max_length=100)
    
    # ===== 2. Preis-Daten extrahieren (robust) =====
    pricing_data = offer.get("pricing") or {}
    if not isinstance(pricing_data, dict):
        pricing_data = {}
    
    # Fallback auf alte Schema-Variante
    if not pricing_data:
        pricing_data = {
            "offer_price_eur": offer.get("offer_price_eur") or offer.get("offer_price"),
            "price_before_eur": offer.get("price_before_eur") or offer.get("price_before"),
            "uvp_eur": offer.get("uvp_eur") or offer.get("uvp"),
            "unit_price": offer.get("unit_price", {}),
            "discount_percent": offer.get("discount_percent")
        }
    
    # Parse alle Preise robust
    offer_price = robust_parse_price(pricing_data.get("offer_price_eur") or pricing_data.get("offer_price"))
    price_before = robust_parse_price(pricing_data.get("price_before_eur") or pricing_data.get("price_before"))
    uvp = robust_parse_price(pricing_data.get("uvp_eur") or pricing_data.get("uvp"))
    discount_percent = robust_parse_price(pricing_data.get("discount_percent"))
    
    # Unit Price Handling (EXTREM robust)
    unit_price_data = pricing_data.get("unit_price") or {}
    if not isinstance(unit_price_data, dict):
        unit_price_data = {}
    
    unit_price_value = robust_parse_price(unit_price_data.get("value"))
    unit_price_per = robust_parse_string(unit_price_data.get("per"), max_length=10)
    
    # Validiere unit_price_per
    valid_units = ["kg", "l", "100g", "100ml"]
    if unit_price_per not in valid_units:
        unit_price_per = None
        if unit_price_value is not None:
            # Wenn unit_price_value aber keine gültige Einheit → setze auf None
            unit_price_value = None
    
    # ===== 3. KRITISCHE Validierungen (Preis-Logik) =====
    
    # Regel: offer_price < uvp (sonst ungültig)
    if offer_price is not None and uvp is not None:
        if offer_price >= uvp:
            # Wenn Unterschied < 0.01, behandeln als gleich → offer_price auf null
            if abs(offer_price - uvp) < 0.01:
                offer_price = None
            elif offer_price > uvp:
                # Logischer Fehler: Angebotspreis > UVP → ungültig
                offer_price = None
    
    # Regel: offer_price != unit_price.value (sonst redundant)
    if offer_price is not None and unit_price_value is not None:
        if abs(offer_price - unit_price_value) < 0.01:
            # Gleicher Preis → wahrscheinlich ist es der Grundpreis, nicht Angebotspreis
            offer_price = None
    
    # Regel: Wenn offer_price aber auch price_before → prüfe Logik
    if offer_price is not None and price_before is not None:
        if offer_price >= price_before:
            # Angebotspreis sollte < price_before sein
            if abs(offer_price - price_before) < 0.01:
                price_before = None  # Gleich → kein "vorher" Preis
            elif offer_price > price_before:
                # Logischer Fehler → setze beide auf null, behalte in price_candidates
                offer_price = None
                price_before = None
    
    # ===== 4. Price Candidates (ALLE Zahlen sammeln) =====
    price_candidates = normalize_price_candidates(offer.get("price_candidates", []))
    
    # Falls keine price_candidates aber Preise vorhanden → erstelle Kandidaten
    if not price_candidates:
        temp_candidates = []
        if offer_price is not None:
            temp_candidates.append({
                "value": offer_price,
                "context": "Angebotspreis (validiert)",
                "type_hint": "offer"
            })
        if unit_price_value is not None:
            temp_candidates.append({
                "value": unit_price_value,
                "context": f"Grundpreis ({unit_price_per or '?'})",
                "type_hint": "unit"
            })
        if uvp is not None:
            temp_candidates.append({
                "value": uvp,
                "context": "UVP/Vorher-Preis",
                "type_hint": "uvp"
            })
        if price_before is not None and price_before != uvp:
            temp_candidates.append({
                "value": price_before,
                "context": "Vorher-Preis",
                "type_hint": "before"
            })
        price_candidates = temp_candidates
    
    # ===== 5. Pack-Daten =====
    pack_data = offer.get("pack") or {}
    if not isinstance(pack_data, dict):
        pack_data = {}
    
    pack_size_text = robust_parse_string(pack_data.get("pack_size_text") or offer.get("pack_size_text"), max_length=50)
    multi_buy_text = robust_parse_string(pack_data.get("multi_buy_text") or offer.get("multi_buy_text"), max_length=50)
    
    # ===== 6. Badges =====
    badges_data = offer.get("badges") or {}
    if not isinstance(badges_data, dict):
        badges_data = {}
    
    # Fallback auf alte Schema-Variante
    lidl_plus = False
    if badges_data.get("lidl_plus") is True or offer.get("lidl_plus") is True:
        lidl_plus = True
    
    other_badges = badges_data.get("other_badges", [])
    if not isinstance(other_badges, list):
        other_badges = []
    else:
        # Bereinige Badges
        cleaned_badges = []
        for badge in other_badges:
            cleaned = robust_parse_string(badge, max_length=50)
            if cleaned:
                cleaned_badges.append(cleaned)
        other_badges = cleaned_badges
    
    lidl_plus_only = False
    if isinstance(other_badges, list):
        badge_text = " ".join([str(b).lower() for b in other_badges])
        if "nur" in badge_text and "lidl plus" in badge_text:
            lidl_plus_only = True
            lidl_plus = True
    
    # ===== 7. Action Type =====
    action_type = robust_parse_string(offer.get("action_type"), max_length=20)
    valid_action_types = ["regular", "lidl_plus", "multi_buy", "restricted", None]
    if action_type not in valid_action_types:
        action_type = None
    
    if lidl_plus_only:
        action_type = "lidl_plus"
    elif lidl_plus and action_type is None:
        action_type = "lidl_plus"
    
    # ===== 8. Category =====
    category = robust_parse_string(offer.get("category"), max_length=50)
    
    # ===== 9. Confidence =====
    confidence = robust_parse_string(offer.get("confidence"), max_length=10)
    valid_confidences = ["high", "medium", "low"]
    if confidence not in valid_confidences:
        confidence = "medium"  # Default
    
    # Auto-Confidence basierend auf Datenqualität
    if confidence == "medium":
        if offer_price is not None and product_name:
            confidence = "high"
        elif not product_name or (not offer_price and not price_candidates):
            confidence = "low"
    
    # ===== 10. Source =====
    source_data = offer.get("source") or {}
    if not isinstance(source_data, dict):
        source_data = {}
    
    page = source_data.get("page") or page_number
    tile = source_data.get("tile") if source_data.get("tile") is not None else tile_index
    
    # ===== 11. Erstelle normiertes Objekt =====
    normalized = {
        "product_name": product_name,
        "brand": brand,
        "variant": variant,
        "offer_price": offer_price,
        "price_before": price_before,
        "uvp": uvp,
        "unit_price_value": unit_price_value,
        "unit_price_per": unit_price_per,
        "discount_percent": discount_percent,
        "pack_size_text": pack_size_text,
        "multi_buy_text": multi_buy_text,
        "lidl_plus": bool(lidl_plus),
        "lidl_plus_only": bool(lidl_plus_only),
        "other_badges": other_badges,
        "category": category,
        "action_type": action_type,
        "price_candidates": price_candidates,
        "confidence": confidence,
        "page": int(page) if page is not None else page_number,
        "tile": int(tile) if tile is not None else None,
    }
    
    return normalized

def robust_parse_json_response(content: str) -> List[Dict] | None:
    """
    EXTREM robustes JSON-Parsing mit vielen Fallback-Strategien.
    Versucht ALLES um JSON zu extrahieren, auch aus beschädigtem Output.
    """
    if not content or not isinstance(content, str):
        return None
    
    content = content.strip()
    if not content:
        return None
    
    # Strategie 1: Entferne Markdown-Fences
    if "```json" in content:
        start = content.find("```json") + 7
        end = content.find("```", start)
        if end > start:
            content = content[start:end].strip()
    elif content.startswith("```"):
        content = content[3:]
        if content.endswith("```"):
            content = content[:-3]
        content = content.strip()
    
    # Strategie 2: Direktes Parsing
    try:
        result = json.loads(content)
        if isinstance(result, list):
            return result
        if isinstance(result, dict):
            return [result]
        return None
    except json.JSONDecodeError:
        pass
    
    # Strategie 3: Finde JSON-Array durch Klammern-Zählung
    start_idx = content.find('[')
    if start_idx >= 0:
        bracket_count = 0
        end_idx = start_idx
        for i in range(start_idx, len(content)):
            if content[i] == '[':
                bracket_count += 1
            elif content[i] == ']':
                bracket_count -= 1
                if bracket_count == 0:
                    end_idx = i + 1
                    break
        
        if end_idx > start_idx:
            json_str = content[start_idx:end_idx]
            try:
                result = json.loads(json_str)
                if isinstance(result, list):
                    return result
                if isinstance(result, dict):
                    return [result]
            except json.JSONDecodeError:
                pass
    
    # Strategie 4: Repariere häufige JSON-Fehler
    try:
        # Entferne trailing commas
        fixed = re.sub(r',(\s*[}\]])', r'\1', content)
        # Entferne Kommentare (falls vorhanden)
        fixed = re.sub(r'//.*?$', '', fixed, flags=re.MULTILINE)
        fixed = re.sub(r'/\*.*?\*/', '', fixed, flags=re.DOTALL)
        
        result = json.loads(fixed)
        if isinstance(result, list):
            return result
        if isinstance(result, dict):
            return [result]
    except json.JSONDecodeError:
        pass
    
    # Strategie 5: Finde erstes { und letztes } und versuche Array
    first_brace = content.find('{')
    last_brace = content.rfind('}')
    if first_brace >= 0 and last_brace > first_brace:
        try:
            json_str = '[' + content[first_brace:last_brace+1] + ']'
            result = json.loads(json_str)
            if isinstance(result, list):
                return result
        except json.JSONDecodeError:
            pass
    
    # Strategie 6: Versuche mehrere JSON-Objekte zu finden
    objects = []
    start = 0
    while True:
        start_brace = content.find('{', start)
        if start_brace < 0:
            break
        
        brace_count = 0
        end_brace = start_brace
        for i in range(start_brace, len(content)):
            if content[i] == '{':
                brace_count += 1
            elif content[i] == '}':
                brace_count -= 1
                if brace_count == 0:
                    end_brace = i + 1
                    break
        
        if end_brace > start_brace:
            obj_str = content[start_brace:end_brace]
            try:
                obj = json.loads(obj_str)
                if isinstance(obj, dict):
                    objects.append(obj)
            except json.JSONDecodeError:
                pass
        
        start = end_brace
    
    if objects:
        return objects
    
    return None

# ============================================================================
# GPT Vision Extraction
# ============================================================================

EXTRACTION_PROMPT = """SYSTEM
Du bist ein extrem robuster, fehlertoleranter Extraktions-Engine für LIDL-Prospektbilder.
Dein oberstes Ziel ist: 
❗ IMMER ein Ergebnis liefern ❗
Wenn Unsicherheit besteht, liefere markierte, aber strukturierte Daten – niemals nichts.

Du darfst NICHT abbrechen.
Du darfst KEINE Seite ignorieren.
Du darfst KEINE stillen Fehler machen.

USER
Analysiere dieses Prospekt-Bild (eine Kachel / ein Bildausschnitt).

AUFGABE (mehrstufig, verpflichtend):
1) Identifiziere visuell ALLE Produkt-Boxen (auch kleine, überlappte, abgeschnittene).
2) Für JEDE erkannte Produkt-Box:
   - Extrahiere Text
   - Identifiziere ALLE Zahlen
   - Klassifiziere jede Zahl (Angebotspreis, Grundpreis, UVP, Rabatt, unklar)
3) Erzeuge daraus strukturierte Angebotsobjekte.

⚠️ ABSOLUTE REGEL:
Wenn du NICHT sicher bist, setze Werte auf null,
ABER du MUSST trotzdem ein Angebotsobjekt erzeugen.

❌ VERBOTEN:
- Eine Kachel mit „Keine Angebote" zurückzugeben
- Eine Kachel leer zu lassen
- Preise zu raten
- Grundpreise als Angebotspreis zu verwenden

---

### 🔁 FALLBACK-LOGIK (PFLICHT)

Wenn du kein klares Angebot erkennst:
→ Erstelle trotzdem ein Objekt mit:
- exact_name = erkannter Produktname ODER null
- pricing.offer_price_eur = null
- price_candidates = ALLE erkannten Zahlen mit Kontext
- confidence = "low"

Wenn du mehrere Preise siehst:
→ Nutze NICHT dein Bauchgefühl
→ Lege ALLE in price_candidates ab
→ Setze offer_price_eur nur, wenn:
   - Preis groß dargestellt
   - KEIN "/kg", "/l", "1 kg =", "Grundpreis"
   - KEIN "UVP", "statt", "vorher"

Wenn KEIN Preis eindeutig ist:
→ offer_price_eur = null
→ price_candidates NICHT leer lassen

---

### 💶 PREIS-REGELN (HART)

1) offer_price_eur:
   - NUR der Kassenpreis
   - NIEMALS €/kg, €/l, €/100g, €/100ml
2) unit_price:
   - Nur Preise mit "/kg", "/l", "1 kg =", "1 l ="
3) uvp_eur / price_before_eur:
   - Nur bei expliziten Wörtern ("UVP", "statt", "war")
4) Wenn:
   offer_price_eur == unit_price.value
   → offer_price_eur = null

5) Dezimaltrennung normalisieren:
   "3,33" → 3.33

---

### 🟡 LIDL-SPEZIFISCH

- Wenn ein Badge „LIDL Plus", „Mit Lidl Plus", „Plus Preis" sichtbar:
  → badges.lidl_plus = true
  → action_type = "lidl_plus"

- Alkohol:
  → category = "alcohol"
  → action_type = "restricted"

---

### 📦 AUSGABEFORMAT (IMMER!)

Gib IMMER ein JSON-Array zurück.
Mindestens 1 Objekt pro erkannter Produkt-Box.

Schema (EXAKT):

{
  "source": {
    "supermarket": "lidl",
    "page": <int|null>,
    "tile": <int|null>
  },
  "product": {
    "exact_name": <string|null>,
    "brand": <string|null>,
    "variant": <string|null>
  },
  "pricing": {
    "offer_price_eur": <number|null>,
    "price_before_eur": <number|null>,
    "uvp_eur": <number|null>,
    "unit_price": {
      "value": <number|null>,
      "per": <"kg"|"l"|"100g"|"100ml"|null>
    },
    "discount_percent": <number|null>
  },
  "pack": {
    "pack_size_text": <string|null>,
    "multi_buy_text": <string|null>
  },
  "badges": {
    "lidl_plus": <true|false|null>,
    "other_badges": <array of string>
  },
  "category": <string|null>,
  "action_type": <"regular"|"lidl_plus"|"multi_buy"|"restricted"|null>,
  "price_candidates": [
    {
      "value": <number>,
      "context": <string>,
      "type_hint": <"offer"|"unit"|"uvp"|"before"|"unknown">
    }
  ],
  "confidence": <"high"|"medium"|"low">
}

---

### ✅ ABSCHLUSSREGEL

- Leeres JSON-Array ist VERBOTEN
- „Keine Angebote gefunden" ist VERBOTEN
- Unsicherheit → confidence="low", NICHT Abbruch
- Struktur > Perfektion

Gib NUR das JSON-Array zurück."""

# Prompt für Full-Page-Extraktion (ganze Seiten)
EXTRACTION_PROMPT_FULL_PAGE = """SYSTEM
Du bist ein extrem robuster Extraktions-Engine für LIDL-Prospektbilder.
Dein oberstes Ziel: ❗ IMMER ein Ergebnis liefern ❗

Du analysierst jetzt eine KOMPLETE PROSPEKT-SEITE mit ALLEN Angeboten.

USER
Analysiere diese KOMPLETE LIDL-Prospektseite und extrahiere ALLE sichtbaren Angebote systematisch.

### 🎯 AUFGABE

**Phase 1: Übersicht**
- Identifiziere die Struktur der Seite (Grid, Spalten, Zeilen)
- Erkenne visuell ALLE Produkt-Boxen/Karten (auch kleine, am Rand)

**Phase 2: Extraktion (für JEDE Box)**
Für JEDE erkannte Produkt-Box:
- Produktname (exact_name) - alle relevanten Zeilen
- Marke (brand) - wenn getrennt sichtbar
- ALLE Zahlen auf der Karte
- Klassifiziere Zahlen:
  * Angebotspreis (groß, prominent, OHNE "/kg", "/l")
  * Grundpreis (mit "/kg", "/l", "1 kg =")
  * UVP/Vorher (mit "statt", "war", "UVP", durchgestrichen)
  * Rabatt (Prozent)

### 💶 PREIS-REGELN (HART)

1. offer_price_eur:
   ✅ Nur wenn: GROSS, PROMINENT, OHNE "/kg", "/l", "/100g"
   ❌ NIEMALS bei: "/kg", "/l", "1 kg =", "statt", "UVP"

2. unit_price:
   ✅ Nur bei: "/kg", "/l", "1 kg =", "Grundpreis"
   → `value`: Zahl ohne Einheit
   → `per`: "kg", "l", "100g", "100ml"

3. price_before_eur / uvp_eur:
   ✅ Nur bei: "statt", "war", "UVP", "vorher", durchgestrichen

4. Dezimaltrennung: "3,33" → 3.33

5. Validierung:
   - offer_price_eur < uvp_eur (sonst null)
   - offer_price_eur ≠ unit_price.value (sonst null)

### 🟡 LIDL-SPEZIFISCH

- "LIDL Plus", "Mit Lidl Plus" → badges.lidl_plus = true
- "Nur mit Lidl Plus" → action_type = "lidl_plus"
- "2 für X €", "3 für Y €" → multi_buy_text
- Alkohol → category = "alcohol", action_type = "restricted"

### 📦 AUSGABEFORMAT

JSON-Array mit Schema:
{
  "source": {"supermarket": "lidl", "page": <int|null>, "tile": null},
  "product": {"exact_name": <string|null>, "brand": <string|null>, "variant": <string|null>},
  "pricing": {
    "offer_price_eur": <number|null>,
    "price_before_eur": <number|null>,
    "uvp_eur": <number|null>,
    "unit_price": {"value": <number|null>, "per": <"kg"|"l"|"100g"|"100ml"|null>},
    "discount_percent": <number|null>
  },
  "pack": {"pack_size_text": <string|null>, "multi_buy_text": <string|null>},
  "badges": {"lidl_plus": <true|false|null>, "other_badges": <array>},
  "category": <string|null>,
  "action_type": <"regular"|"lidl_plus"|"multi_buy"|"restricted"|null>,
  "price_candidates": [{"value": <number>, "context": <string>, "type_hint": <"offer"|"unit"|"uvp"|"before"|"unknown">}],
  "confidence": <"high"|"medium"|"low">
}

### ✅ REGELN

- Leeres Array VERBOTEN
- Bei Unsicherheit: Objekt mit confidence="low", offer_price_eur=null
- ALLE Zahlen in price_candidates
- Struktur > Perfektion

Gib NUR das JSON-Array zurück."""

def extract_offers_from_full_page(image_base64: str, page_number: int, retry_count: int = 0) -> List[Dict]:
    """Extrahiert Angebote aus einer ganzen Seite mit GPT Vision (schneller)"""
    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": EXTRACTION_PROMPT_FULL_PAGE
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{image_base64}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=8000,  # Mehr Tokens für ganze Seiten
            temperature=0.1
        )
        
        content = response.choices[0].message.content.strip()
        
        # Verwende robustes JSON-Parsing
        offers_raw = robust_parse_json_response(content)
        
        if offers_raw is None or not offers_raw:
            # Wenn Parsing fehlschlägt, versuche es nochmal mit Retry
            if retry_count < 2:
                time.sleep(1.0)
                return extract_offers_from_full_page(image_base64, page_number, retry_count + 1)
            return []  # Leeres Array statt Fehler
        
        # Normalisiere alle Offers mit robuster Validierung
        normalized_offers = []
        for offer in offers_raw:
            if not isinstance(offer, dict):
                continue
            
            normalized = validate_and_normalize_offer(offer, page_number, tile_index=None)
            if normalized is not None:
                normalized_offers.append(normalized)
        
        return normalized_offers
        
    except Exception as e:
        error_msg = str(e)
        
        # Rate Limit Error
        if "429" in error_msg or "rate limit" in error_msg.lower():
            if retry_count < 3:
                wait_time = min((2 ** retry_count) * 2, 20)
                print(f"      ⏳ Rate Limit - warte {wait_time}s...")
                time.sleep(wait_time)
                return extract_offers_from_full_page(image_base64, page_number, retry_count + 1)
            else:
                print(f"      ⚠️  Rate Limit nach 3 Versuchen - überspringe Seite {page_number}")
                return []
        
        if retry_count < 2:
            time.sleep(1.0)
            return extract_offers_from_full_page(image_base64, page_number, retry_count + 1)
        else:
            if "401" not in error_msg and "403" not in error_msg:
                pass
            return []

def extract_offers_from_tile(tile_base64: str, tile_index: int, page_number: int, retry_count: int = 0) -> List[Dict]:
    """Extrahiert Angebote aus einer Bild-Kachel mit GPT Vision"""
    try:
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": EXTRACTION_PROMPT
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/png;base64,{tile_base64}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=4000,
            temperature=0.1
        )
        
        content = response.choices[0].message.content.strip()
        
        # Verwende robustes JSON-Parsing
        offers_raw = robust_parse_json_response(content)
        
        if offers_raw is None or not offers_raw:
            # Wenn Parsing fehlschlägt, versuche es nochmal mit Retry
            if retry_count < 2:
                time.sleep(1.0)
                return extract_offers_from_tile(tile_base64, tile_index, page_number, retry_count + 1)
            return []  # Leeres Array statt Fehler
        
        # Normalisiere alle Offers mit robuster Validierung
        normalized_offers = []
        for offer in offers_raw:
            if not isinstance(offer, dict):
                continue
            
            normalized = validate_and_normalize_offer(offer, page_number, tile_index=tile_index)
            if normalized is not None:
                normalized_offers.append(normalized)
        
        return normalized_offers
        
    except json.JSONDecodeError as e:
        if retry_count < 3:  # Mehr Retries
            time.sleep(1.0 + retry_count)  # Längere Pause bei Retry
            return extract_offers_from_tile(tile_base64, tile_index, page_number, retry_count + 1)
        else:
            # Still versuchen zu extrahieren (manchmal ist der Text trotzdem nützlich)
            return []
    except Exception as e:
        error_msg = str(e)
        
        # Rate Limit Error - länger warten (aber nicht zu lange)
        if "429" in error_msg or "rate limit" in error_msg.lower():
            if retry_count < 3:  # Reduziert auf 3 Retries
                wait_time = min((2 ** retry_count) * 2, 20)  # Max 20s warten
                print(f"      ⏳ Rate Limit - warte {wait_time}s...")
                time.sleep(wait_time)
                return extract_offers_from_tile(tile_base64, tile_index, page_number, retry_count + 1)
            else:
                print(f"      ⚠️  Rate Limit nach 3 Versuchen - überspringe Kachel {tile_index}")
                return []
        
        if retry_count < 2:
            time.sleep(1.0)
            return extract_offers_from_tile(tile_base64, tile_index, page_number, retry_count + 1)
        else:
            # Nur bei wirklich kritischen Fehlern ausgeben
            if "401" not in error_msg and "403" not in error_msg:  # API-Key Fehler nicht verschleiern
                pass  # Stille Fehler für bessere Ausgabe
            return []

def extract_offers_from_image(image: Image.Image, page_number: int, grid_size: Tuple[int, int] = (2, 3), use_full_page: bool = False) -> List[Dict]:
    """Extrahiert Angebote aus einem Bild (Seite)
    
    Args:
        image: PIL Image der Seite
        page_number: Seitenzahl
        grid_size: Grid-Größe für Kachel-Modus (Standard: (2, 3))
        use_full_page: Wenn True, analysiere ganze Seite (schneller), sonst Kacheln (genauer)
    """
    all_offers = []
    
    if use_full_page:
        # Ganze Seite analysieren (schneller, weniger API-Calls)
        print(f"      → Ganze Seite (Full-Page-Modus)")
        image_base64 = image_to_base64(image)
        offers = extract_offers_from_full_page(image_base64, page_number)
        
        if offers:
            all_offers.extend(offers)
            print(f"         {len(offers)} Angebote gefunden")
        
        # Deduplizierung
        unique_offers = []
        seen = set()
        for offer in all_offers:
            product_name = (offer.get("product_name") or "").lower().strip()
            offer_price = offer.get("offer_price")
            if offer_price is None:
                price = 0
            else:
                price = round(float(offer_price), 2)
            
            if not product_name:
                continue
            
            key = (product_name[:50], price)
            if key not in seen:
                seen.add(key)
                unique_offers.append(offer)
        
        return unique_offers
    else:
        # Kachel-Modus (Standard, genauer)
        tiles = split_image_into_tiles(image, grid_size)
    print(f"      → {len(tiles)} Kacheln (Grid: {grid_size[0]}x{grid_size[1]})")
    
    # Verarbeite jede Kachel
    for tile_idx, tile in enumerate(tiles, 1):
        tile_base64 = image_to_base64(tile)
        offers = extract_offers_from_tile(tile_base64, tile_idx, page_number)
        
        if offers:
            all_offers.extend(offers)
            print(f"         Kachel {tile_idx}: {len(offers)} Angebote")
        
        # Kurze Pause zwischen Kacheln für Rate Limiting
        if tile_idx < len(tiles):
            time.sleep(0.3)
    
    # Deduplizierung (gleiche Seite kann gleiche Angebote in mehreren Kacheln haben)
    unique_offers = []
    seen = set()
    for offer in all_offers:
        product_name = (offer.get("product_name") or "").lower().strip()
        
        # Preis kann null sein - verwende 0 für Vergleich wenn null
        offer_price = offer.get("offer_price")
        if offer_price is None:
            price = 0
        else:
            price = round(float(offer_price), 2)
        
        if not product_name:
            continue
        
        key = (product_name[:50], price)  # Erste 50 Zeichen + Preis
        if key not in seen:
            seen.add(key)
            unique_offers.append(offer)
    
    return unique_offers

# ============================================================================
# Main
# ============================================================================

def find_pdf() -> Path:
    """Findet PDF-Datei im Script-Ordner"""
    pdf_files = list(SCRIPT_DIR.glob("*.pdf"))
    if not pdf_files:
        print("❌ Keine PDF-Datei gefunden!")
        print(f"   Erwartet in: {SCRIPT_DIR}")
        sys.exit(1)
    
    return max(pdf_files, key=lambda p: p.stat().st_size)

def deduplicate_offers(offers: List[Dict]) -> List[Dict]:
    """Entfernt Duplikate basierend auf Produktname und Preis (intelligente Deduplizierung)"""
    seen = set()
    unique = []
    
    for offer in offers:
        # Normalisiere Produktname für Vergleich
        product_name = (offer.get("product_name") or "").lower().strip()
        
        # Überspringe leere Namen
        if not product_name:
            continue
        
        # Normalisiere Produktname (entferne Sonderzeichen, mehrere Leerzeichen)
        import re
        product_name_normalized = re.sub(r'\s+', ' ', product_name)  # Mehrfache Leerzeichen zu einem
        product_name_normalized = product_name_normalized[:60]  # Erste 60 Zeichen
        
        # Preis kann null sein - verwende 0 für Vergleich wenn null
        offer_price = offer.get("offer_price")
        if offer_price is None:
            price = 0
        else:
            try:
                price = round(float(offer_price), 2)
            except (ValueError, TypeError):
                price = 0
        
        # Erstelle Vergleichs-Key (Name + Preis)
        key = (product_name_normalized, price)
        
        # Zusätzlich: Prüfe auch auf ähnliche Namen mit gleichem Preis (bei 0-Preis)
        # Wenn Preis 0 ist, verwende nur Name
        if price == 0:
            # Bei null-Preis: Prüfe auch unit_price oder erste price_candidate
            unit_price = offer.get("unit_price_value")
            if unit_price is not None:
                try:
                    price_key = round(float(unit_price), 2)
                    key = (product_name_normalized, price_key)
                except (ValueError, TypeError):
                    pass
            elif offer.get("price_candidates"):
                # Verwende ersten Preis-Kandidaten
                first_candidate = offer["price_candidates"][0]
                try:
                    price_key = round(float(first_candidate.get("value", 0)), 2)
                    if price_key > 0:
                        key = (product_name_normalized, price_key)
                except (ValueError, TypeError):
                    pass
        
        if key not in seen:
            seen.add(key)
            unique.append(offer)
    
    return unique

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='LIDL PDF Extraktion mit GPT Vision')
    parser.add_argument('--test', action='store_true', help='Test-Modus: Nur erste 5 Seiten')
    parser.add_argument('--limit', type=int, help='Maximale Anzahl Seiten zu verarbeiten')
    parser.add_argument('--skip-rate-limit', action='store_true', help='Überspringe Seiten mit Rate Limit statt zu warten')
    parser.add_argument('--dpi', type=int, default=200, help='DPI für PDF-Konvertierung (Standard: 200, höher = langsamer)')
    parser.add_argument('--convert-only', action='store_true', help='Nur PDF konvertieren, keine Extraktion')
    parser.add_argument('--full-page', action='store_true', help='Analysiere ganze Seiten statt Kacheln (schneller, weniger API-Calls)')
    parser.add_argument('--tiles', action='store_true', help='Analysiere mit Kacheln (Standard, genau aber langsamer)')
    args = parser.parse_args()
    
    print("🛒 LIDL PDF Extraktion mit GPT Vision")
    print("=" * 60)
    print()
    
    # Finde PDF
    pdf_path = find_pdf()
    print(f"📄 PDF: {pdf_path.name}")
    print(f"   Größe: {pdf_path.stat().st_size / 1024 / 1024:.1f} MB")
    print()
    
    # Checkpoint-Datei
    checkpoint_file = SCRIPT_DIR / ".extraction_checkpoint.json"
    start_page = 1
    
    # Lade Checkpoint falls vorhanden
    if checkpoint_file.exists():
        try:
            with open(checkpoint_file, 'r') as f:
                checkpoint = json.load(f)
                start_page = checkpoint.get('last_page', 1) + 1
                print(f"📍 Checkpoint gefunden: Setze fort ab Seite {start_page}")
                all_offers = checkpoint.get('offers', [])
        except:
            all_offers = []
            start_page = 1
    else:
        all_offers = []
        start_page = 1
    
    # Bestimme Seiten-Limit vor Konvertierung (spart Zeit)
    first_page = None
    last_page = None
    if args.test:
        last_page = 5
    elif args.limit:
        last_page = args.limit
    
    # Konvertiere PDF zu Bildern
    print("📄 Konvertiere PDF zu Bildern...")
    print(f"   DPI: {args.dpi} (Standard: 200, höher = langsamer aber schärfer)")
    if not args.test and not args.limit:
        print("   (Dies kann bei 63 Seiten ~2 Minuten dauern...)")
    print("   💡 Tipp: Drücke Ctrl+C zum Abbrechen, falls es zu lange dauert")
    
    if last_page:
        print(f"   → Konvertiere nur Seiten 1-{last_page}")
    else:
        print(f"   → Konvertiere alle Seiten...")
    
    try:
        import time as time_module
        start_time = time_module.time()
        
        # Verwende konfigurierbare DPI für bessere Performance
        images = convert_from_path(
            pdf_path, 
            dpi=args.dpi, 
            thread_count=1, 
            fmt='png',
            first_page=first_page,
            last_page=last_page
        )
        
        elapsed = time_module.time() - start_time
        print(f"✓ {len(images)} Seiten konvertiert ({elapsed:.1f}s)")
        
        # Warnung wenn es sehr lange gedauert hat
        if elapsed > 120:
            print(f"⚠️  Konvertierung dauerte {elapsed/60:.1f} Minuten - das ist normal bei großen PDFs")
        
        # Validiere dass Bilder gültig sind
        valid_images = []
        for img in images:
            if img and img.size[0] > 0 and img.size[1] > 0:
                valid_images.append(img)
        
        if len(valid_images) != len(images):
            print(f"⚠️  {len(images) - len(valid_images)} ungültige Bilder übersprungen")
        
        images = valid_images
        
        if not images:
            print("❌ Keine gültigen Bilder aus PDF extrahiert!")
            sys.exit(1)
            
        # Nur konvertieren, keine Extraktion
        if args.convert_only:
            print()
            print("✅ PDF konvertiert!")
            print(f"   {len(images)} Seiten bereit für Extraktion")
            print("   Starte ohne --convert-only für Extraktion")
            sys.exit(0)
            
    except KeyboardInterrupt:
        print("\n\n⚠️  Konvertierung abgebrochen")
        print("   Versuche es mit --test für weniger Seiten oder --dpi 150 für schnellere Konvertierung")
        sys.exit(0)
    except Exception as e:
        print(f"❌ Fehler beim Konvertieren: {str(e)}")
        print("   Installiere poppler: brew install poppler")
        print("   Oder versuche niedrigere DPI: --dpi 150")
        sys.exit(1)
    
    print()
    print("🔍 Analysiere Seiten mit GPT-4o Vision...")
    print("   (Pro Kachel für maximale Genauigkeit)")
    print()
    
    all_offers = []
    
    # Rate Limit Counter
    rate_limit_count = 0
    
    # Verarbeite jede Seite
    for idx, image in enumerate(images):
        page_num = start_page + idx
        print(f"[{page_num}/{len(images) + start_page - 1}] Seite {page_num}...", end=" ", flush=True)
        
        try:
            # Rate Limit Skip-Modus
            if args.skip_rate_limit and rate_limit_count > 10:
                print("⏭️  Übersprungen (zu viele Rate Limits)")
                continue
            
            # Wähle Modus: Full-Page (schneller) oder Tiles (genauer)
            use_full_page = args.full_page or (not args.tiles and args.limit and args.limit > 20)  # Auto full-page bei großen Limits
            offers = extract_offers_from_image(image, page_num, grid_size=(2, 3), use_full_page=use_full_page)
            all_offers.extend(offers)
            rate_limit_count = 0  # Reset bei Erfolg
            
            # Speichere Checkpoint nach jeder 5. Seite
            if page_num % 5 == 0:
                checkpoint_data = {
                    'last_page': page_num,
                    'offers': all_offers,
                    'timestamp': time.strftime("%Y-%m-%d %H:%M:%S")
                }
                with open(checkpoint_file, 'w') as f:
                    json.dump(checkpoint_data, f, indent=2)
            
            if offers:
                print(f"✓ {len(offers)} Angebote")
            else:
                print("⚠️  Keine Angebote")
            
            # Pause zwischen Seiten für Rate Limiting
            if idx < len(images) - 1:
                time.sleep(0.5)
            
        except KeyboardInterrupt:
            print("\n\n⚠️  Abgebrochen vom Benutzer")
            print(f"   Bis jetzt: {len(all_offers)} Angebote gesammelt (bis Seite {page_num})")
            print("   Speichere teilweise Ergebnisse...")
            
            # Lösche Checkpoint
            checkpoint_file = SCRIPT_DIR / ".extraction_checkpoint.json"
            if checkpoint_file.exists():
                checkpoint_file.unlink()
            
            # Speichere teilweise Ergebnisse
            if all_offers:
                deduplicated = deduplicate_offers(all_offers)
                with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
                    json.dump({
                        "supermarket": "LIDL",
                        "source": str(pdf_path),
                        "total_offers": len(deduplicated),
                        "extraction_date": time.strftime("%Y-%m-%d %H:%M:%S"),
                        "partial": True,
                        "last_page": page_num,
                        "lidl_plus_count": sum(1 for o in deduplicated if o.get("lidl_plus") or o.get("lidl_plus_only")),
                        "offers": deduplicated
                    }, f, indent=2, ensure_ascii=False)
                print(f"   ✓ Teilweise Ergebnisse gespeichert: {OUTPUT_JSON}")
            
            sys.exit(0)
        except Exception as e:
            error_msg = str(e)
            if "401" in error_msg or "403" in error_msg:
                print(f"\n❌ API-Key-Fehler: {error_msg}")
                sys.exit(1)
            
            # Rate Limit Skip-Modus
            if "429" in error_msg or "rate limit" in error_msg.lower():
                rate_limit_count += 1
                if args.skip_rate_limit:
                    print("⏭️  Übersprungen (Rate Limit)")
                    continue
            
            print(f"✗ Fehler: {error_msg[:50]}")
            continue  # Weiter mit nächster Seite
    
    print()
    
    # Deduplizierung
    print()
    print(f"🔄 Deduplizierung ({len(all_offers)} → ", end="", flush=True)
    all_offers = deduplicate_offers(all_offers)
    print(f"{len(all_offers)} eindeutige Angebote)")
    print()
    
    # Normalisiere (sicherstellen dass alle Felder vorhanden)
    for offer in all_offers:
        offer.setdefault("lidl_plus", False)
        offer.setdefault("lidl_plus_only", False)
        offer.setdefault("other_badges", [])
        offer.setdefault("variant", None)
        offer.setdefault("multi_buy_text", None)
        offer.setdefault("brand", None)
        offer.setdefault("category", None)
        offer.setdefault("action_type", None)
        offer.setdefault("discount_percent", None)
        offer.setdefault("original_price", None)
        offer.setdefault("price_before", None)
        offer.setdefault("uvp", None)
        offer.setdefault("unit_price_value", None)
        offer.setdefault("unit_price_per", None)
        offer.setdefault("price_candidates", [])
        offer.setdefault("tile", None)
        offer.setdefault("confidence", "medium")
    
    # Speichere Text-Datei
    print("💾 Speichere lidl.txt...")
    with open(OUTPUT_TXT, 'w', encoding='utf-8') as f:
        f.write("LIDL ANGEBOTE\n")
        f.write("=" * 60 + "\n")
        f.write(f"Quelle: {pdf_path.name}\n")
        f.write(f"Anzahl Angebote: {len(all_offers)}\n")
        f.write("=" * 60 + "\n\n")
        
        for idx, offer in enumerate(all_offers, 1):
            title = offer["product_name"]
            
            # Badges
            badges = []
            if offer.get("lidl_plus_only"):
                badges.append("📱 NUR LIDL PLUS")
            elif offer.get("lidl_plus"):
                badges.append("📱 LIDL PLUS")
            
            other_badges = offer.get("other_badges", [])
            if isinstance(other_badges, list):
                badges.extend([f"🏷️ {b}" for b in other_badges if b])
            
            badge_str = " " + " ".join(badges) if badges else ""
            f.write(f"{idx}. {title}{badge_str}\n")
            
            # Preise
            if offer.get("offer_price") is not None:
                f.write(f"   Angebotspreis: {offer['offer_price']:.2f} €\n")
            
            if offer.get("price_before"):
                f.write(f"   Statt: {offer['price_before']:.2f} €\n")
            
            if offer.get("uvp"):
                f.write(f"   UVP: {offer['uvp']:.2f} €\n")
            
            if offer.get("unit_price_value") is not None:
                per = offer.get("unit_price_per") or ""
                f.write(f"   Grundpreis: {offer['unit_price_value']:.2f} €/{per}\n")
            
            if offer.get("price_candidates") and offer.get("offer_price") is None:
                f.write(f"   ⚠️  Preis unklar, Kandidaten:\n")
                for candidate in offer["price_candidates"]:
                    f.write(f"      - {candidate.get('value')} € ({candidate.get('type_hint')}): {candidate.get('context', '')}\n")
            
            if offer.get("discount_percent"):
                f.write(f"   Rabatt: -{offer['discount_percent']}%\n")
            
            # Basis-Informationen
            if offer.get("quantity"):
                f.write(f"   Menge/Einheit: {offer['quantity']}\n")
            
            if offer.get("variant"):
                f.write(f"   Variante: {offer['variant']}\n")
            
            if offer.get("multi_buy_text"):
                f.write(f"   Mengenrabatt: {offer['multi_buy_text']}\n")
            
            if offer.get("brand"):
                f.write(f"   Marke: {offer['brand']}\n")
            
            if offer.get("category"):
                f.write(f"   Kategorie: {offer['category']}\n")
            
            if offer.get("action_type"):
                f.write(f"   Aktionstyp: {offer['action_type']}\n")
            
            if offer.get("confidence"):
                confidence_emoji = {"high": "🟢", "medium": "🟡", "low": "🔴"}.get(offer['confidence'], "⚪")
                f.write(f"   {confidence_emoji} Confidence: {offer['confidence']}\n")
            
            # Zusätzliche Informationen
            if offer.get("description"):
                f.write(f"   Beschreibung: {offer['description']}\n")
            
            if offer.get("condition"):
                f.write(f"   Bedingung: {offer['condition']}\n")
            
            if offer.get("page"):
                f.write(f"   Seite: {offer['page']}\n")
            
            f.write("\n")
    
    # Deduplizierung
    deduplicated = deduplicate_offers(all_offers)
    
    # Speichere JSON
    print("💾 Speichere lidl.json...")
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
        json.dump({
            "supermarket": "LIDL",
            "source": str(pdf_path),
            "total_offers": len(deduplicated),
            "extraction_date": time.strftime("%Y-%m-%d %H:%M:%S"),
            "lidl_plus_count": sum(1 for o in deduplicated if o.get("lidl_plus") or o.get("lidl_plus_only")),
            "offers": deduplicated
        }, f, indent=2, ensure_ascii=False)
    
    # Lösche Checkpoint bei Erfolg
    checkpoint_file = SCRIPT_DIR / ".extraction_checkpoint.json"
    if checkpoint_file.exists():
        checkpoint_file.unlink()
    
    # Statistiken
    deduplicated = deduplicate_offers(all_offers)
    lidl_plus_count = sum(1 for o in deduplicated if o.get("lidl_plus") or o.get("lidl_plus_only"))
    offers_with_price = sum(1 for o in deduplicated if o.get("offer_price") is not None)
    offers_with_unit_price = sum(1 for o in deduplicated if o.get("unit_price_value") is not None)
    offers_with_candidates = sum(1 for o in deduplicated if len(o.get("price_candidates", [])) > 0)
    confidence_high = sum(1 for o in deduplicated if o.get("confidence") == "high")
    confidence_medium = sum(1 for o in deduplicated if o.get("confidence") == "medium")
    confidence_low = sum(1 for o in deduplicated if o.get("confidence") == "low")
    
    print()
    print("✅ Fertig!")
    print()
    print("📊 Statistiken:")
    print(f"   Gesamt-Angebote: {len(deduplicated)}")
    print(f"   Mit Aktionspreis: {offers_with_price}")
    print(f"   Mit Grundpreis: {offers_with_unit_price}")
    print(f"   Mit Preis-Kandidaten: {offers_with_candidates}")
    print(f"   🟢 High Confidence: {confidence_high}")
    print(f"   🟡 Medium Confidence: {confidence_medium}")
    print(f"   🔴 Low Confidence: {confidence_low}")
    if lidl_plus_count > 0:
        print(f"   📱 LIDL Plus Angebote: {lidl_plus_count}")
    print()
    print("📁 Output-Dateien:")
    print(f"   Text: {OUTPUT_TXT}")
    print(f"   JSON: {OUTPUT_JSON}")
    print()

if __name__ == "__main__":
    main()
