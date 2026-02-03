# LIDL PDF zu Text Konverter

## 🎯 Zweck

Konvertiert LIDL-PDFs zu kopierbarem Text - perfekt für:
- ChatGPT-Analyse
- Manuelle Durchsuchung
- Weitere Verarbeitung

## 🚀 Quick Start

```bash
cd roman_app/server/media/prospekte/lidl

# Mit venv (empfohlen)
source venv/bin/activate
python pdf_to_text.py

# Oder direkt
./quick_pdf_to_text.sh
```

## 📄 Output

Die extrahierte Text-Datei wird gespeichert als:
- **`lidl.txt`** - Vollständiger Text, kopierbar

## 🔧 Funktionsweise

### Methode 1: pdfplumber (Standard)
- Beste Qualität für strukturierte PDFs
- Schnell und zuverlässig

### Methode 2: PyPDF2 (Fallback)
- Ergänzt pdfplumber
- Findet manchmal andere Text-Passagen

### Methode 3: OCR (Automatisch wenn nötig)
- Wird automatisch verwendet wenn:
  - Text-Extraktion < 5000 Zeichen ergibt, ODER
  - PDF hauptsächlich URLs/Links enthält (wie kaufDA-PDFs)
- Dauert länger (~1-2 Min pro Seite)
- Extrahiert Text aus Bildern (gescannte PDFs)

## 💡 Verwendung

### Option 1: Text in ChatGPT kopieren

1. Öffne `lidl.txt`
2. Kopiere den kompletten Text
3. Füge in ChatGPT ein mit:
   ```
   Ich habe den Text aus dem LIDL-Prospekt extrahiert.
   Bitte erstelle mir daraus strukturierte Rezepte mit:
   - Produktnamen
   - Preisen
   - Mengenangaben
   - LIDL Plus Badges
   ```

### Option 2: Weiterverarbeitung

Der Text kann auch programmatisch weiterverarbeitet werden.

## ⚠️ Hinweis

Wenn die PDF hauptsächlich URLs enthält (wie kaufDA-PDFs), wird automatisch OCR verwendet.
Dies dauert länger, aber extrahiert den tatsächlichen Prospekt-Text aus den Bildern.
