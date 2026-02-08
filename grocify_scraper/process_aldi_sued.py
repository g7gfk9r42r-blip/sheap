#!/usr/bin/env python3
"""
Pipeline für ALDI SÜD mit neuem PDF
Extrahiert Angebote und erstellt Rezepte
"""

import sys
import os
from pathlib import Path
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from src.pipeline.cached_pipeline import CachedPipeline

def get_week_key() -> str:
    """Get current week key"""
    now = datetime.now()
    year, week, _ = now.isocalendar()
    return f"{year}-W{week:02d}"

def find_pdf_file() -> Path:
    """Find ALDI SÜD PDF file"""
    # Wenn Pfad als Argument übergeben wurde, verwende diesen
    if len(sys.argv) > 1:
        pdf_path = Path(sys.argv[1])
        # Wenn relativer Pfad, mache ihn absolut relativ zum Script
        if not pdf_path.is_absolute():
            script_dir = Path(__file__).parent
            pdf_path = (script_dir / pdf_path).resolve()
        if pdf_path.exists():
            return pdf_path
        else:
            raise FileNotFoundError(f"PDF-Datei nicht gefunden: {pdf_path}")
    
    # Ansonsten suche in Standard-Verzeichnissen
    script_dir = Path(__file__).parent
    search_paths = [
        script_dir.parent / "server" / "media" / "prospekte" / "aldi_sued",
        script_dir / "sources" / "pdf" / "aldi_sued",
        script_dir.parent / "server" / "media" / "prospekte",
        script_dir / "sources" / "pdf",
    ]
    
    for search_path in search_paths:
        if search_path.exists():
            # Suche nach aldi_sued PDFs
            pdfs = list(search_path.glob("**/aldi*sued*.pdf")) + list(search_path.glob("**/aldi*sued*.PDF"))
            if pdfs:
                # Nimm das neueste
                pdfs.sort(key=lambda p: p.stat().st_mtime, reverse=True)
                return pdfs[0]
    
    raise FileNotFoundError(
        "ALDI SÜD PDF nicht gefunden!\n"
        "Bitte PDF in einen dieser Ordner legen:\n"
        "  - server/media/prospekte/aldi_sued/\n"
        "  - grocify_scraper/sources/pdf/aldi_sued/\n"
        "Oder Pfad als Argument angeben: python3 process_aldi_sued.py /path/to/file.pdf"
    )

def main():
    print("=" * 70)
    print("ALDI SÜD PIPELINE")
    print("=" * 70)
    print()
    
    # Finde PDF
    try:
        pdf_path = find_pdf_file()
        print(f"✅ PDF gefunden: {pdf_path}")
    except FileNotFoundError as e:
        print(f"❌ {e}")
        sys.exit(1)
    
    # Woche bestimmen (aktuelle Woche)
    week_key = get_week_key()
    print(f"📅 Woche: {week_key}")
    print()
    
    # Output-Verzeichnis
    out_dir = Path("out")
    out_dir.mkdir(parents=True, exist_ok=True)
    
    # Erstelle Pipeline
    print("🔄 Starte Pipeline...")
    print()
    
    try:
        pipeline = CachedPipeline(
            supermarket="aldi_sued",
            week_key=week_key,
            out_dir=out_dir,
            pdf_path=pdf_path,
            raw_list_path=None,  # Keine Liste, nur PDF
            max_loops=10
        )
        
        result = pipeline.run()
        
        if result.get("status") == "OK":
            metrics = result.get("metrics", {})
            offers_count = metrics.get("offers", 0)
            recipes_count = metrics.get("recipes", 0)
            
            print()
            print("=" * 70)
            print("✅ ERFOLGREICH")
            print("=" * 70)
            print(f"📊 Angebote: {offers_count}")
            print(f"🍽️  Rezepte: {recipes_count}")
            print()
            # Kopiere/benenne Dateien um für einfachen Zugriff
            offers_file = out_dir / "offers" / f"offers_aldi_sued_{week_key}.json"
            recipes_file = out_dir / "recipes" / f"recipes_aldi_sued_{week_key}.json"
            
            # Erstelle auch Dateien ohne Week-Key
            offers_simple = out_dir / "offers" / "aldi_sued_offer.json"
            recipes_simple = out_dir / "recipes" / "aldi_sued_recipes.json"
            
            if offers_file.exists():
                import shutil
                shutil.copy2(offers_file, offers_simple)
            if recipes_file.exists():
                import shutil
                shutil.copy2(recipes_file, recipes_simple)
            
            print(f"📁 Output-Dateien:")
            print(f"   Angebote: {offers_file}")
            print(f"   Rezepte: {recipes_file}")
            print(f"   (Kopien auch als: aldi_sued_offer.json und aldi_sued_recipes.json)")
            print()
        else:
            error_msg = result.get('error', 'Unknown error')
            print(f"❌ Fehler: {error_msg}")
            sys.exit(1)
            
    except Exception as e:
        print(f"❌ Fehler: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()

