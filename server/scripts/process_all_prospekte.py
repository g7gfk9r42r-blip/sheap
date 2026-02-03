#!/usr/bin/env python3
"""Einfache Funktion zum Durchscrapen aller Prospekt-Ordner.

Geht durch prospekte/ und verarbeitet jeden Unterordner einzeln.
EDEKA-Unterordner werden als separate Prospekte behandelt.
"""
from __future__ import annotations

import sys
from pathlib import Path

# Add prospekt_pipeline to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from prospekt_pipeline.pipeline.process_prospekt import ProspektProcessor
from prospekt_pipeline.utils.logger import setup_logger


def find_prospekt_folders(base_dir: Path) -> list[Path]:
    """Findet alle Ordner, die Prospekt-Dateien enthalten.
    
    Sucht rekursiv nach Ordnern mit HTML oder PDF Dateien.
    Jeder gefundene Ordner wird als eigenes Prospekt behandelt.
    """
    folders: list[Path] = []
    
    def has_prospekt_files(folder: Path) -> bool:
        """Prüft ob ein Ordner HTML oder PDF Dateien enthält."""
        html_files = list(folder.glob("*.html"))
        pdf_files = list(folder.glob("*.pdf"))
        return len(html_files) > 0 or len(pdf_files) > 0
    
    # Gehe durch alle Unterordner
    for item in base_dir.rglob("*"):
        if not item.is_dir():
            continue
        
        # Überspringe versteckte Ordner und _files Ordner
        if item.name.startswith(".") or item.name.endswith("_files"):
            continue
        
        # Prüfe ob dieser Ordner Prospekt-Dateien hat
        if has_prospekt_files(item):
            folders.append(item)
    
    return sorted(set(folders))  # Entferne Duplikate und sortiere


def prepare_folder(folder: Path) -> Path:
    """Bereitet einen Ordner für die Pipeline vor.
    
    Erstellt raw.html und raw.pdf Symlinks/Kopien falls nötig.
    """
    # Suche nach HTML Dateien
    html_files = sorted(folder.glob("*.html"))
    pdf_files = sorted(folder.glob("*.pdf"))
    
    # Erstelle raw.html wenn nicht vorhanden
    raw_html = folder / "raw.html"
    if not raw_html.exists() and html_files:
        # Nimm die erste HTML Datei
        source_html = html_files[0]
        if source_html != raw_html:
            try:
                # Versuche Symlink, falls das fehlschlägt kopiere
                raw_html.symlink_to(source_html.name)
            except (OSError, NotImplementedError):
                # Fallback: Kopie
                raw_html.write_bytes(source_html.read_bytes())
            print(f"  → raw.html erstellt von {source_html.name}")
    
    # Erstelle raw.pdf wenn nicht vorhanden
    raw_pdf = folder / "raw.pdf"
    if not raw_pdf.exists() and pdf_files:
        # Nimm die erste PDF Datei
        source_pdf = pdf_files[0]
        if source_pdf != raw_pdf:
            try:
                # Versuche Symlink, falls das fehlschlägt kopiere
                raw_pdf.symlink_to(source_pdf.name)
            except (OSError, NotImplementedError):
                # Fallback: Kopie
                raw_pdf.write_bytes(source_pdf.read_bytes())
            print(f"  → raw.pdf erstellt von {source_pdf.name}")
    
    return folder


def main():
    """Hauptfunktion: Verarbeitet alle Prospekt-Ordner mit maximaler Sorgfalt."""
    # Setup mit DEBUG-Level für detailliertes Logging
    import sys
    log_level = "INFO"
    if "--debug" in sys.argv or "-d" in sys.argv:
        log_level = "DEBUG"
    setup_logger(level=log_level)
    processor = ProspektProcessor()
    
    # Base directory
    base_dir = Path(__file__).parent.parent / "media" / "prospekte"
    
    if not base_dir.exists():
        print(f"❌ Ordner nicht gefunden: {base_dir}")
        return 1
    
    print(f"🔍 Suche Prospekt-Ordner in: {base_dir}")
    print()
    
    # Finde alle Prospekt-Ordner
    folders = find_prospekt_folders(base_dir)
    
    if not folders:
        print("⚠️  Keine Prospekt-Ordner gefunden!")
        return 1
    
    print(f"✅ {len(folders)} Prospekt-Ordner gefunden:")
    for folder in folders:
        print(f"   - {folder.relative_to(base_dir)}")
    print()
    
    # Verarbeite jeden Ordner
    processed = 0
    failed = 0
    
    for folder in folders:
        print(f"📦 Verarbeite: {folder.relative_to(base_dir)}")
        
        try:
            # Bereite Ordner vor (erstellt raw.html/raw.pdf falls nötig)
            prepare_folder(folder)
            
            # Verarbeite mit Pipeline
            result = processor.process(folder)
            
            # Zeige detailliertes Ergebnis
            num_offers = len(result.get("offers", []))
            metadata = result.get("metadata", {})
            json_count = metadata.get("json_candidates", 0)
            html_count = metadata.get("html_candidates", 0)
            pdf_count = metadata.get("pdf_candidates", 0)
            ocr_count = metadata.get("ocr_candidates", 0)
            fallback_count = metadata.get("fallback_candidates", 0)
            
            if num_offers > 0:
                print(f"   ✅ {num_offers} Angebote extrahiert")
                sources = []
                if json_count > 0:
                    sources.append(f"JSON: {json_count}")
                if html_count > 0:
                    sources.append(f"HTML: {html_count}")
                if pdf_count > 0:
                    sources.append(f"PDF: {pdf_count}")
                if ocr_count > 0:
                    sources.append(f"OCR: {ocr_count}")
                if fallback_count > 0:
                    sources.append(f"Fallback: {fallback_count}")
                if sources:
                    print(f"      ({', '.join(sources)})")
                processed += 1
            else:
                print(f"   ⚠️  Keine Angebote gefunden")
                sources = []
                if json_count > 0:
                    sources.append(f"JSON: {json_count}")
                if html_count > 0:
                    sources.append(f"HTML: {html_count}")
                if pdf_count > 0:
                    sources.append(f"PDF: {pdf_count}")
                if ocr_count > 0:
                    sources.append(f"OCR: {ocr_count}")
                if fallback_count > 0:
                    sources.append(f"Fallback: {fallback_count}")
                if sources:
                    print(f"      ({', '.join(sources)})")
                failed += 1
                
        except Exception as exc:
            print(f"   ❌ Fehler: {exc}")
            failed += 1
        
        print()
    
    # Zusammenfassung
    print("=" * 60)
    print(f"✅ Erfolgreich: {processed}")
    print(f"❌ Fehlgeschlagen: {failed}")
    print(f"📊 Gesamt: {len(folders)}")
    
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

