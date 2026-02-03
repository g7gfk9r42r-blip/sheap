# 🔧 OCR Performance-Optimierung - OHNE Qualitätsverlust

## 🎯 Ziel
Die OCR-Performance für große PDFs (58+ Seiten) optimieren, **ABER ohne die Qualität der Angebotserkennung zu beeinträchtigen**.

## ❌ Problem
- Aktuell: 58 Seiten × 4 Strategien × 400 DPI = ~17 Minuten pro Prospekt
- Bei vielen Prospekten wird das zu langsam

## ✅ Anforderungen

### Performance
- Große PDFs (> 50 Seiten) sollten max. 5-7 Minuten dauern
- OCR sollte intelligent aktiviert werden (nur wenn nötig)

### Qualität
- **KEINE Reduzierung der Erkennungsqualität**
- Alle wichtigen Angebote müssen erkannt werden
- Erste + letzte Seiten sind wichtig (meiste Angebote)
- Mittlere Seiten können reduziert werden

## 💡 Optimierungs-Strategien

### 1. Intelligente Seiten-Auswahl (QUALITÄTS-ERHALTEND)
- **Erste 20 Seiten**: Immer vollständig (meiste Angebote)
- **Letzte 5 Seiten**: Immer vollständig (meiste Angebote)
- **Mittlere Seiten (21-53 bei 58 Seiten)**: 
  - Option A: Jede 3. Seite (z.B. 21, 24, 27, 30, ...)
  - Option B: Erste 10 der mittleren Seiten (21-30)
  - Option C: Stichproben (21, 25, 30, 35, 40, 45, 50)

### 2. Strategien beibehalten (QUALITÄT)
- **Standard**: Immer auf allen Seiten
- **Aggressive**: Immer auf ersten 20 + letzten 5 Seiten
- **Aggressive**: Optional auf mittleren Seiten (nur wenn Standard < 3 Ergebnisse)
- **Inverted & Grayscale**: Optional, nur bei schlechter Qualität

### 3. DPI-Optimierung (QUALITÄTS-ERHALTEND)
- **Erste 20 + letzte 5 Seiten**: 350 DPI (hohe Qualität)
- **Mittlere Seiten**: 250 DPI (schneller, aber immer noch gut)

### 4. Intelligente OCR-Aktivierung (BEREITS IMPLEMENTIERT)
- OCR läuft NUR wenn PDF-Parsing < 30% Ergebnisse liefert
- Oder wenn < 5 PDF-Ergebnisse vorhanden
- Sonst: OCR übersprungen

## 📊 Erwartete Performance

### Vorher
- 58 Seiten × 4 Strategien × 400 DPI = ~17 Minuten

### Nachher (mit Qualität)
- Erste 20 Seiten: 20 × 2 Strategien × 350 DPI = ~4 Minuten
- Letzte 5 Seiten: 5 × 2 Strategien × 350 DPI = ~1 Minute
- Mittlere 12 Seiten (jede 3.): 12 × 1 Strategie × 250 DPI = ~2 Minuten
- **Gesamt: ~7 Minuten** (statt 17 Minuten)

### Qualität
- ✅ Erste 20 Seiten: Volle Qualität (2 Strategien, 350 DPI)
- ✅ Letzte 5 Seiten: Volle Qualität (2 Strategien, 350 DPI)
- ✅ Mittlere Seiten: Gute Qualität (1 Strategie, 250 DPI, Stichproben)

## 🎯 Implementierung

Bitte implementiere:

1. **Intelligente Seiten-Auswahl**:
   - Erste 20 Seiten: Vollständig
   - Letzte 5 Seiten: Vollständig
   - Mittlere Seiten: Jede 3. Seite (oder intelligente Stichproben)

2. **Strategien beibehalten**:
   - Standard: Immer auf allen ausgewählten Seiten
   - Aggressive: Immer auf ersten 20 + letzten 5, optional auf mittleren

3. **DPI-Optimierung**:
   - Wichtige Seiten (erste 20 + letzte 5): 350 DPI
   - Mittlere Seiten: 250 DPI

4. **Logging**:
   - Klar anzeigen, welche Seiten verarbeitet werden
   - Zeigen, welche Strategien verwendet werden

## ✅ Erfolgskriterien

- Performance: Max. 7 Minuten für 58 Seiten
- Qualität: Mindestens 90% der wichtigen Angebote erkannt
- Intelligente Aktivierung: OCR übersprungen wenn PDF-Parsing gut funktioniert

---

**Wichtig**: Die Qualität der Angebotserkennung darf NICHT leiden. Erste + letzte Seiten müssen vollständig verarbeitet werden.

