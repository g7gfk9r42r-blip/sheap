# 🔧 Technische Dokumentation - LIDL PDF Extraktion

## 📋 Übersicht

Das Script `extract_lidl_offers_vision.py` extrahiert Lebensmittel-Angebote aus einer LIDL-PDF mithilfe von **GPT-4o Vision** (Multimodal LLM). Der Prozess nutzt Bildverarbeitung und KI-Analyse für maximale Genauigkeit.

---

## 🔄 Workflow (Step-by-Step)

### 1. **Initialisierung & Setup**

```
Script startet
  ↓
Lädt OPENAI_API_KEY (.env oder Environment-Variable)
  ↓
Findet PDF-Datei im Script-Ordner (größte .pdf Datei)
  ↓
Initialisiert OpenAI Client
```

**Code:**
- `.env` Loading mit mehreren Pfad-Versuchen
- Automatische PDF-Suche via `Path.glob("*.pdf")`
- Fehlerbehandlung bei fehlendem API-Key

---

### 2. **PDF → Bilder Konvertierung**

```
PDF-Datei (57 Seiten, 45.5 MB)
  ↓
pdf2image.convert_from_path()
  ↓
57 PNG-Bilder (300 DPI, RGB)
```

**Technik:**
- **Bibliothek:** `pdf2image` (nutzt `poppler` unter der Haube)
- **Auflösung:** 300 DPI (hoch genug für OCR, nicht zu groß für API)
- **Format:** PNG (RGB), jedes Bild = eine PDF-Seite

**Warum Bilder?**
- PDFs sind oft nicht direkt text-extrahierbar (Layout-basiert, eingebettete Bilder)
- GPT Vision kann visuelle Layouts besser verstehen
- Funktioniert auch bei gescannten/sehr grafischen PDFs

---

### 3. **Tile-basierte Bildaufteilung**

```
1 Seite (z.B. 1654×2339 Pixel)
  ↓
split_image_into_tiles() - 2×3 Grid
  ↓
6 Kacheln (ca. 827×780 Pixel pro Kachel)
```

**Code-Logik:**
```python
def split_image_into_tiles(image, grid_size=(2, 3)):
    width, height = image.size
    tile_width = width // grid_size[0]   # 827 Pixel
    tile_height = height // grid_size[1]  # 780 Pixel
    
    for row in range(grid_size[1]):
        for col in range(grid_size[0]):
            left = col * tile_width
            top = row * tile_height
            right = left + tile_width
            bottom = top + tile_height
            
            tile = image.crop((left, right, top, bottom))
            tiles.append(tile)
```

**Warum Kacheln?**
- **Token-Limit:** GPT Vision hat Limits für Bildgröße/Token
- **Fokus:** Kleinere Kacheln = bessere Erkennung von Details
- **Parallelität:** Theoretisch parallelisierbar (aktuell sequenziell)
- **Genauigkeit:** Vermeidet Übersehen von kleinen Angeboten

**Grid-Größe:** 2×3 = **6 Kacheln pro Seite**
- Pro 57 Seiten = **342 API-Calls**

---

### 4. **Base64-Encoding für API**

```
PNG-Kachel (ca. 827×780 Pixel)
  ↓
PIL.Image → Bytes
  ↓
base64.b64encode()
  ↓
Base64-String (z.B. "iVBORw0KGgoAAAANSUhEUgAA...")
```

**Format für OpenAI API:**
```json
{
  "type": "image_url",
  "image_url": {
    "url": "data:image/png;base64,{base64_string}"
  }
}
```

**Warum Base64?**
- OpenAI API erwartet Base64-encoded Bilder
- `data:` URL-Schema für Inline-Bilder
- Keine externe Bild-URL nötig

---

### 5. **GPT-4o Vision API Call**

```
Kachel-Base64 + Prompt
  ↓
OpenAI Chat Completions API (model: "gpt-4o")
  ↓
JSON-Response mit extrahierten Angeboten
```

**API Request:**
```python
response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": EXTRACTION_PROMPT},
            {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{base64}"}}
        ]
    }],
    max_tokens=4000,
    temperature=0.1  # Niedrig für konsistente Extraktion
)
```

**Prompt-Strategie:**
- **Detailliertes Schema:** Alle gewünschten Felder explizit definiert
- **Klare Regeln:** Nur Lebensmittel, keine Haushaltswaren
- **Format-Anforderung:** "Return ONLY a JSON array. No markdown."
- **Vollständigkeit:** "Extrahiere ALLE Angebote! Kein einziges darf übersehen werden!"

**Temperature 0.1:**
- Niedrige Variabilität = konsistente Extraktion
- Wichtig für strukturierte Daten-Extraktion

---

### 6. **JSON-Parsing & Normalisierung**

```
GPT Response (manchmal mit Markdown-Fences)
  ↓
Entferne "```json" und "```"
  ↓
json.loads() → Python Dict/List
  ↓
Normalisiere zu internem Schema
  ↓
Validiere (product_name + price vorhanden)
```

**Robuste Parsing-Strategie:**
```python
# 1. Entferne Markdown-Fences
if "```json" in content:
    start = content.find("```json") + 7
    end = content.find("```", start)
    content = content[start:end].strip()

# 2. Finde JSON-Array (falls Text davor/danach)
start_idx = content.find('[')
# ... Finde passende ']' ...

# 3. Parse JSON
offers_raw = json.loads(content)
```

**Normalisierung:**
- GPT-Output: `exact_name`, `price_eur`, `unit`, etc.
- Internes Format: `product_name`, `offer_price`, `quantity`, etc.
- Mapping zwischen beiden Formaten

**Validierung:**
- Nur Angebote mit `product_name` UND `offer_price > 0`
- Filtert leere/ungültige Einträge

---

### 7. **Deduplizierung (pro Seite & global)**

**Pro Seite (innerhalb von `extract_offers_from_image`):**
```
6 Kacheln → Alle Angebote
  ↓
Vergleiche: (product_name.lower()[:50], price)
  ↓
Entferne Duplikate (gleiche Seite kann überlappende Kacheln haben)
```

**Global (nach allen Seiten):**
```
Alle Seiten → Alle Angebote
  ↓
deduplicate_offers() - Vergleich (product_name[:50], price)
  ↓
Eindeutige Angebote
```

**Deduplizierungs-Key:**
```python
product_name = offer["product_name"].lower().strip()[:50]  # Erste 50 Zeichen
price = round(float(offer["offer_price"]), 2)  # 2 Dezimalstellen
key = (product_name, price)
```

**Warum 50 Zeichen?**
- Vermeidet Duplikate durch leichte Namensvariationen
- Ausreichend für eindeutige Identifikation

---

### 8. **Fehlerbehandlung & Retries**

**JSON-Parse-Fehler:**
- 3 Retries mit exponential backoff (1s, 2s, 3s)
- Bei weiterem Fehler: Überspringe Kachel (leere Liste zurück)

**Rate Limit (429 Error):**
- 5 Retries mit exponential backoff (4s, 8s, 16s, 32s, 64s)
- Längere Wartezeiten, da API-Limit

**API-Key-Fehler (401/403):**
- Sofortiger Exit (kritischer Fehler)

**Andere Fehler:**
- 2 Retries
- Bei weiterem Fehler: Überspringe Kachel (Script läuft weiter)

---

### 9. **Output-Generierung**

**Text-Datei (`lidl.txt`):**
```
LIDL ANGEBOTE
============================================================
Quelle: kaufDA - Lidl - LIDL LOHNT SICH.pdf
Anzahl Angebote: 234
============================================================

1. Produktname 📱 LIDL PLUS
   Angebotspreis: 1.99 €
   Statt: 2.49 €
   Menge: 500 g
   ...
```

**JSON-Datei (`lidl.json`):**
```json
[
  {
    "product_name": "Produktname",
    "offer_price": 1.99,
    "quantity": "500 g",
    "lidl_plus": true,
    "lidl_plus_only": false,
    "brand": "Markenname",
    "category": "Kategorie",
    "page": 2,
    ...
  },
  ...
]
```

---

## 📊 Datenfluss-Diagramm

```
PDF (45.5 MB, 57 Seiten)
    │
    ├─→ [PDF → PNG] (pdf2image, 300 DPI)
    │       │
    │       ├─→ Seite 1 (1654×2339 px)
    │       │       │
    │       │       ├─→ [Tile 1] → Base64 → GPT Vision → JSON → Angebote
    │       │       ├─→ [Tile 2] → Base64 → GPT Vision → JSON → Angebote
    │       │       ├─→ [Tile 3] → Base64 → GPT Vision → JSON → Angebote
    │       │       ├─→ [Tile 4] → Base64 → GPT Vision → JSON → Angebote
    │       │       ├─→ [Tile 5] → Base64 → GPT Vision → JSON → Angebote
    │       │       └─→ [Tile 6] → Base64 → GPT Vision → JSON → Angebote
    │       │
    │       ├─→ Seite 2 → ... (gleich)
    │       └─→ ... (57 Seiten)
    │
    ├─→ [Deduplizierung] (pro Seite + global)
    │
    └─→ [Output]
            ├─→ lidl.txt (human-readable)
            └─→ lidl.json (machine-readable)
```

---

## ⚙️ Technische Details

### **Abhängigkeiten:**

```python
openai>=1.0.0          # OpenAI API Client
pdf2image>=1.16.0      # PDF → PNG Konvertierung
Pillow>=10.0.0         # Bildverarbeitung (crop, encode)
python-dotenv>=1.0.0   # .env Datei Loading
```

**System-Abhängigkeiten:**
- `poppler` (für pdf2image) - Install via: `brew install poppler`

---

### **Rate Limiting:**

- **Pause zwischen Kacheln:** 0.3s
- **Pause zwischen Seiten:** 0.5s
- **Retry bei Rate Limit:** Exponential backoff (4s → 64s)

**Warum?**
- OpenAI API hat Rate Limits (Requests pro Minute)
- Pausen vermeiden 429 Errors
- Exponential backoff bei Limit-Erreichen

---

### **Token-Usage:**

- **Pro Bild-Kachel:** ~800-1200 Input-Tokens (Bild + Prompt)
- **Output:** ~100-500 Tokens pro Kachel (je nach Anzahl Angebote)
- **Total:** ~342 API-Calls × ~1500 Tokens = **~513.000 Tokens**

**Kosten-Schätzung (GPT-4o):**
- Input: ~342 × 1200 × $0.0025/1K = **~$1.03**
- Output: ~342 × 300 × $0.01/1K = **~$1.03**
- **Total: ~$2.06 pro Lauf** (für 57 Seiten)

---

## 🎯 Warum diese Methode?

### **Vorteile:**

1. ✅ **Hohe Genauigkeit** - GPT Vision erkennt Layout, Preise, Badges
2. ✅ **Robust** - Funktioniert auch bei grafischen/sehr komplexen PDFs
3. ✅ **Vollständig** - Extrahiert ALLE Felder (LIDL Plus, Marken, etc.)
4. ✅ **Kein OCR nötig** - GPT Vision "versteht" das Bild direkt
5. ✅ **Bewährt** - "lief perfekt durch" (User-Feedback)

### **Nachteile:**

1. ⚠️ **Langsam** - ~10-20 Minuten für 57 Seiten
2. ⚠️ **Kosten** - ~$2 pro Lauf
3. ⚠️ **API-Abhängig** - Benötigt Internet + OpenAI API Key

### **Alternativen (verworfen):**

- **PDF-to-Text:** Lief bei dieser PDF schlecht (hauptsächlich URLs)
- **Playwright/Web-Scraping:** Extrahiert oft Non-Food-Items, benötigt aktive URL
- **OCR (Tesseract):** Unpräzise, erfordert Post-Processing

---

## 🔍 Debugging & Monitoring

**Fortschrittsanzeige:**
```
[12/57] Seite 12...       → 6 Kacheln (Grid: 2x3)
         Kachel 2: 1 Angebote
         Kachel 5: 3 Angebote
✓ 4 Angebote
```

**Fehler-Indikatoren:**
- `⚠️ JSON-Parse-Fehler` - GPT gab kein gültiges JSON zurück
- `⚠️ Keine Angebote` - Keine Lebensmittel in dieser Kachel
- `⏳ Rate Limit - warte Xs...` - API-Limit erreicht, wartet

**Ergebnis-Übersicht:**
```
🔄 Deduplizierung (342 → 234 eindeutige Angebote)
💾 Speichere lidl.txt...
💾 Speichere lidl.json...
✅ Fertig! 234 Angebote extrahiert
```

---

## 📝 Zusammenfassung

Das Script nutzt **GPT-4o Vision** für die Extraktion, kombiniert mit **tile-basierter Bildaufteilung** für maximale Genauigkeit. Der Prozess ist robust gegenüber Fehlern (Retries, Rate Limits) und extrahiert strukturierte Daten direkt aus dem visuellen Layout der PDF-Seiten.

**Kern-Idee:** PDF → Bilder → Kacheln → GPT Vision → JSON → Strukturierte Daten
