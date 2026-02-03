#!/usr/bin/env python3
"""
LIDL PDF zu Text Konverter
Konvertiert PDF zu kopierbarem Text - perfekt für GPT-Analyse
"""

import sys
from pathlib import Path

# UTF-8 Encoding
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

try:
    import pdfplumber
    PDFPLUMBER_AVAILABLE = True
except ImportError:
    PDFPLUMBER_AVAILABLE = False

try:
    import PyPDF2
    PYPDF2_AVAILABLE = True
except ImportError:
    PYPDF2_AVAILABLE = False

try:
    import pytesseract
    from pdf2image import convert_from_path
    from PIL import Image
    TESSERACT_AVAILABLE = True
except ImportError:
    TESSERACT_AVAILABLE = False

SCRIPT_DIR = Path(__file__).parent
OUTPUT_TXT = SCRIPT_DIR / "lidl.txt"

def extract_text_pdfplumber(pdf_path: Path) -> str:
    """Extrahiert Text mit pdfplumber (beste Qualität für strukturierte PDFs)"""
    text_parts = []
    print("📄 Methode 1: pdfplumber...")
    
    try:
        with pdfplumber.open(pdf_path) as pdf:
            for page_num, page in enumerate(pdf.pages, 1):
                # Extrahiere Text
                text = page.extract_text()
                if text:
                    text_parts.append(f"\n{'='*60}\nSEITE {page_num}\n{'='*60}\n\n{text}")
                
                # Extrahiere auch Tabellen (falls vorhanden)
                tables = page.extract_tables()
                if tables:
                    for table_num, table in enumerate(tables, 1):
                        text_parts.append(f"\n[TABELLE {page_num}-{table_num}]\n")
                        for row in table:
                            if row:
                                text_parts.append(" | ".join(str(cell) if cell else "" for cell in row))
                                text_parts.append("\n")
    except Exception as e:
        print(f"   ⚠️  Fehler: {str(e)}")
        return ""
    
    result = "\n".join(text_parts)
    print(f"   ✓ {len(result)} Zeichen extrahiert")
    return result

def extract_text_pypdf2(pdf_path: Path) -> str:
    """Extrahiert Text mit PyPDF2 (Fallback)"""
    text_parts = []
    print("📄 Methode 2: PyPDF2...")
    
    try:
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            for page_num, page in enumerate(pdf_reader.pages, 1):
                text = page.extract_text()
                if text:
                    text_parts.append(f"\n{'='*60}\nSEITE {page_num}\n{'='*60}\n\n{text}")
    except Exception as e:
        print(f"   ⚠️  Fehler: {str(e)}")
        return ""
    
    result = "\n".join(text_parts)
    print(f"   ✓ {len(result)} Zeichen extrahiert")
    return result

def extract_text_ocr(pdf_path: Path) -> str:
    """Extrahiert Text mit OCR (Tesseract) - für gescannte PDFs"""
    text_parts = []
    print("📄 Methode 3: OCR (Tesseract)...")
    print("   ⚠️  Dies kann mehrere Minuten dauern...")
    
    try:
        # Konvertiere PDF zu Bildern
        images = convert_from_path(pdf_path, dpi=300)
        print(f"   → {len(images)} Seiten konvertiert")
        
        for page_num, image in enumerate(images, 1):
            print(f"   → OCR Seite {page_num}/{len(images)}...")
            text = pytesseract.image_to_string(image, lang='deu')
            if text.strip():
                text_parts.append(f"\n{'='*60}\nSEITE {page_num}\n{'='*60}\n\n{text}")
    except Exception as e:
        print(f"   ⚠️  Fehler: {str(e)}")
        return ""
    
    result = "\n".join(text_parts)
    print(f"   ✓ {len(result)} Zeichen extrahiert")
    return result

def combine_texts(*texts: str) -> str:
    """Kombiniert mehrere Texte und entfernt Duplikate"""
    # Sammle alle Zeilen
    all_lines = []
    seen_lines = set()
    
    for text in texts:
        if not text:
            continue
        
        lines = text.split('\n')
        for line in lines:
            line_stripped = line.strip()
            # Überspringe leere Zeilen und Seiten-Trenner
            if not line_stripped or line_stripped.startswith('='*60):
                continue
            
            # Prüfe auf Duplikate (nur für längere Zeilen)
            if len(line_stripped) > 10:
                line_hash = hash(line_stripped)
                if line_hash in seen_lines:
                    continue
                seen_lines.add(line_hash)
            
            all_lines.append(line)
    
    return '\n'.join(all_lines)

def main():
    print("📄 LIDL PDF zu Text Konverter")
    print("=" * 60)
    print()
    
    # Finde PDF-Datei
    pdf_files = list(SCRIPT_DIR.glob("*.pdf"))
    
    if not pdf_files:
        print("❌ Keine PDF-Datei gefunden!")
        print(f"   Erwartet in: {SCRIPT_DIR}")
        print()
        print("💡 Bitte lade eine LIDL-PDF in diesen Ordner:")
        print(f"   {SCRIPT_DIR}")
        sys.exit(1)
    
    # Nimm die erste PDF (oder größte, falls mehrere)
    pdf_path = max(pdf_files, key=lambda p: p.stat().st_size)
    print(f"📄 PDF gefunden: {pdf_path.name}")
    print(f"   Größe: {pdf_path.stat().st_size / 1024 / 1024:.1f} MB")
    print()
    
    # Prüfe verfügbare Methoden
    methods_available = []
    if PDFPLUMBER_AVAILABLE:
        methods_available.append(("pdfplumber", extract_text_pdfplumber))
    if PYPDF2_AVAILABLE:
        methods_available.append(("PyPDF2", extract_text_pypdf2))
    if TESSERACT_AVAILABLE:
        methods_available.append(("OCR", extract_text_ocr))
    
    if not methods_available:
        print("❌ Keine PDF-Extraktions-Bibliotheken gefunden!")
        print()
        print("💡 Bitte installiere eine der folgenden:")
        print("   pip install pdfplumber  # Empfohlen (beste Qualität)")
        print("   pip install PyPDF2      # Alternative")
        print("   pip install pytesseract pdf2image pillow  # Für OCR (gescannte PDFs)")
        print("   # Für OCR: brew install tesseract tesseract-lang  # macOS")
        sys.exit(1)
    
    print("🔄 Extrahiere Text aus PDF...")
    print(f"   Verfügbare Methoden: {', '.join(m[0] for m in methods_available)}")
    print()
    
    # Extrahiere mit allen verfügbaren Methoden
    extracted_texts = []
    
    # Methode 1: pdfplumber (beste Qualität)
    if PDFPLUMBER_AVAILABLE:
        text1 = extract_text_pdfplumber(pdf_path)
        if text1:
            extracted_texts.append(text1)
        print()
    
    # Methode 2: PyPDF2 (Fallback)
    if PYPDF2_AVAILABLE and len(extracted_texts) == 0:
        text2 = extract_text_pypdf2(pdf_path)
        if text2:
            extracted_texts.append(text2)
        print()
    
    # Methode 3: OCR (nur wenn Text-Extraktion wenig ergibt oder hauptsächlich URLs)
    if TESSERACT_AVAILABLE:
        # Prüfe ob bereits genug Text vorhanden
        total_chars = sum(len(t) for t in extracted_texts)
        combined_so_far = combine_texts(*extracted_texts) if extracted_texts else ""
        
        # Prüfe ob hauptsächlich URLs/links vorhanden (kein echter Prospekt-Text)
        url_count = combined_so_far.lower().count('http') if combined_so_far else 0
        text_ratio = len([w for w in combined_so_far.split() if not w.startswith('http')]) if combined_so_far else 0
        
        use_ocr = False
        if total_chars < 5000:  # Weniger als 5000 Zeichen
            use_ocr = True
            print("   ⚠️  Text-Extraktion ergab wenig Text, versuche OCR...")
        elif url_count > 10 and text_ratio < 100:  # Viele URLs, wenig echten Text
            use_ocr = True
            print("   ⚠️  PDF enthält hauptsächlich URLs (kein echter Text), versuche OCR...")
            print("   → Dies kann mehrere Minuten dauern...")
        
        if use_ocr:
            text3 = extract_text_ocr(pdf_path)
            if text3:
                extracted_texts.append(text3)
            print()
    
    # Kombiniere alle Texte
    if not extracted_texts:
        print("❌ Kein Text konnte extrahiert werden!")
        sys.exit(1)
    
    print("🔄 Kombiniere extrahierte Texte...")
    combined_text = combine_texts(*extracted_texts)
    
    # Speichere Ergebnis
    print()
    print(f"💾 Speichere Text in: {OUTPUT_TXT.name}...")
    
    with open(OUTPUT_TXT, 'w', encoding='utf-8') as f:
        f.write("LIDL PROSPEKT - EXTRAHIERTER TEXT\n")
        f.write("=" * 60 + "\n")
        f.write(f"Quelle: {pdf_path.name}\n")
        f.write(f"Zeichen: {len(combined_text)}\n")
        f.write("=" * 60 + "\n\n")
        f.write(combined_text)
    
    print(f"✅ Fertig!")
    print()
    print("📊 Statistiken:")
    print(f"   Zeichen: {len(combined_text):,}")
    print(f"   Wörter: ~{len(combined_text.split()):,}")
    print(f"   Zeilen: {len(combined_text.splitlines()):,}")
    print()
    print("📁 Output:")
    print(f"   {OUTPUT_TXT}")
    print()
    print("💡 Du kannst diesen Text jetzt:")
    print("   1. In ChatGPT kopieren für Rezept-Generierung")
    print("   2. Mit anderen Tools weiterverarbeiten")
    print("   3. Manuell durchsuchen")
    print()

if __name__ == "__main__":
    main()
