# 5-teiliger Umsetzungsplan: Wöchentliche Rezept-Pipeline

## 🎯 Ziel
Automatische, wöchentliche Generierung von:
- Präzisen Angeboten (PDF + JSON Fusion)
- Verfügbaren Zutaten
- Genauen Nährwerten
- Hochwertigen Rezeptbildern
- 50-100 Rezepten pro Supermarkt

---

## PHASE 1: Präzise Angebots-Extraktion (PDF + JSON Fusion)

### 1.1 PDF-Extraktion (GPT Vision)
- **Input:** PDF-Dateien in `server/media/prospekte/<supermarket>/*.pdf`
- **Prozess:**
  1. Seiten rendern (250 DPI) → Cache
  2. Tile Discovery (2-3x für Konsens)
  3. Vollständige Extraktion (Initial + Missing-Pass)
  4. Microtext-Pass (UVP, Loyalty, Multi-Price)
- **Output:** `out/cache/<supermarket>/<weekKey>/page_<n>_offers.json`

### 1.2 JSON-Extraktion
- **Input:** JSON-Dateien in `server/media/prospekte/<supermarket>/*.json`
- **Prozess:**
  1. Struktur erkennen (Recipe-List vs. Direct Offers)
  2. Offers aus Ingredients extrahieren (wenn Recipe-Format)
  3. Normalisieren (Brand, Unit, Price, Loyalty)
- **Output:** Normalisierte Offers mit `source="raw"`

### 1.3 Fusion (PDF + JSON)
- **Regel:** RAW (JSON) hat Priorität für Struktur, PDF für Vollständigkeit
- **Matching:** Name + Brand + Unit + Price-Ähnlichkeit
- **Output:** `out/offers/offers_<supermarket>_<weekKey>.json`

### 1.4 Qualitätssicherung
- **Validierung:** 5-Pass Quality Gates
- **Targeted Rechecks:** Nur schlechte Seiten (>10% Missing)
- **Output:** `out/reports/page_quality_<supermarket>_<weekKey>.json`

---

## PHASE 2: Zutaten-Verfügbarkeit

### 2.1 Angebots-Zutaten
- **Quelle:** Extrahierte Offers aus Phase 1
- **Verfügbarkeit:** Automatisch während Gültigkeitszeitraum
- **Metadata:** `validFrom`, `validTo` aus PDF/JSON

### 2.2 Grundsortiment
- **Definition:** Immer verfügbare Basis-Zutaten
- **Liste:**
  - Gewürze: Salz, Pfeffer, Paprika, Knoblauch, Zwiebeln
  - Fette: Öl, Butter, Margarine
  - Flüssigkeiten: Wasser, Milch, Brühe
  - Grundnahrungsmittel: Mehl, Zucker, Essig
- **Metadata:** `isFromOffer=false`, `alwaysAvailable=true`

### 2.3 Live-Verfügbarkeit (Optional)
- **APIs:** REWE API, EDEKA API (wenn verfügbar)
- **Fallback:** Wenn API nicht verfügbar → Angebots-Zutaten + Grundsortiment
- **Output:** `out/availability/<supermarket>_<weekKey>.json`

### 2.4 Integration in Rezepte
- **Regel:** Bevorzuge Angebots-Zutaten, ergänze mit Grundsortiment
- **Markierung:** `fromOffer=true/false` pro Zutat

---

## PHASE 3: Nährwerte-Bestimmung

### 3.1 Datenquellen (Priorität)
1. **OpenFoodFacts API** (Markenprodukte)
   - Barcode-Suche
   - Marke + Produktname
   - Fallback: Fuzzy-Matching
2. **USDA/DGE Datenbank** (Standard-Zutaten)
   - Lokale Datenbank
   - Kategorie-basierte Lookups
3. **Kategorie-Schätzung** (Fallback)
   - Bestehende Heuristik
   - Erweiterte Kategorien

### 3.2 Nährwert-Berechnung
- **Pro Zutat:** kcal, protein_g, carbs_g, fat_g (pro 100g)
- **Pro Rezept:** Summe aller Zutaten × Menge
- **Pro Portion:** Rezept-Nährwerte / Portionen
- **Range:** ±25% für Unsicherheit

### 3.3 Output
- **Format:** `nutritionRange: {kcal: [min, max], protein_g: [min, max], ...}`
- **Confidence:** `high` (API), `medium` (DB), `low` (Schätzung)

---

## PHASE 4: Bild-Generierung

### 4.1 Bild-Quellen (Priorität)
1. **Produktbilder aus Offers**
   - `imageUrl` aus PDF/JSON
   - Produktbilder der Hauptzutat
2. **AI-Generierung**
   - DALL-E 3 / Stable Diffusion
   - Prompt: "Photorealistic top-down food photography of [title] with [ingredients], natural lighting, 1:1"
3. **Kategorie-Placeholder**
   - Fallback-Bilder pro Kategorie
   - Neutral, professionell

### 4.2 Image Jobs
- **Format:** `image_jobs_<supermarket>_<weekKey>.json`
- **Inhalt:** Recipe-ID + Prompt + Aspect Ratio
- **Verarbeitung:** Asynchron (kann später generiert werden)

### 4.3 Output
- **Rezepte:** `heroImageUrl` (wenn generiert)
- **Image Jobs:** Separate Datei für Batch-Generierung

---

## PHASE 5: Wöchentliche Automatisierung

### 5.1 Trigger
- **Cron-Job:** Jeden Montag 00:00 (neue Prospekte)
- **Manuell:** Script-Aufruf mit Week-Key
- **Input-Detection:** Automatische Erkennung neuer Prospekte

### 5.2 Pipeline-Flow
```
1. Prospekte scannen → Neue PDFs/JSONs finden
2. Für jeden Supermarkt:
   a. Phase 1: Angebots-Extraktion
   b. Phase 2: Verfügbarkeit prüfen
   c. Phase 3: Nährwerte bestimmen
   d. Phase 4: Rezepte generieren (50-100)
   e. Phase 5: Image Jobs erstellen
3. Global Report generieren
4. Manifest erstellen
```

### 5.3 Output-Struktur
```
out/
├── offers/              # Finale Offers (alle Supermärkte)
├── recipes/             # Finale Rezepte (alle Supermärkte)
├── reports/             # Qualitäts-Reports
├── images/              # Image Jobs
├── cache/               # Zwischen-Cache (resumable)
└── manifest_<weekKey>.json  # Global Manifest
```

### 5.4 Fehlerbehandlung
- **Resumable:** Checkpoints nach jeder Phase
- **Partial Success:** Einzelne Supermärkte können fehlschlagen
- **Retry-Logik:** Automatische Wiederholung bei API-Fehlern

---

## 📋 Implementierungs-Checkliste

### Phase 1: ✅ Bereits implementiert
- [x] GPT Vision Extraktion
- [x] JSON Parsing (Recipe→Offers)
- [x] Fusion (PDF + JSON)
- [x] Quality Gates
- [x] Cache-System

### Phase 2: 🔄 Zu implementieren
- [ ] Grundsortiment-Definition
- [ ] Verfügbarkeits-Logik
- [ ] Supermarkt-API Integration (optional)

### Phase 3: 🔄 Zu implementieren
- [ ] OpenFoodFacts API Integration
- [ ] USDA/DGE Datenbank
- [ ] Verbesserte Nährwert-Schätzung

### Phase 4: 🔄 Zu implementieren
- [ ] Image Job Generator (✅ bereits vorhanden)
- [ ] DALL-E Integration
- [ ] Produktbild-Extraktion

### Phase 5: 🔄 Zu implementieren
- [ ] Wöchentlicher Cron-Job
- [ ] Automatische Prospekt-Erkennung
- [ ] Global Report Generator

