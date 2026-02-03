"""
🔥 GROCIFY – MULTIPROCESSING PROSPEKT PIPELINE
--------------------------------------------------
• Pro Folder ein eigener Worker
• Voll automatisiert
• AI Vision + OCR + HTML Parser
• Auto-Recovery
• Progress Tracking
"""

from __future__ import annotations

import json
import sys
import traceback
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from tqdm import tqdm
except ImportError:
    # Fallback if tqdm not available
    def tqdm(iterable, **kwargs):
        return iterable

from prospekt_pipeline.multiprocessing.worker import process_folder
from prospekt_pipeline.multiprocessing.config import CPU_LIMIT
from prospekt_pipeline.utils.logger import setup_logger

LOGGER = setup_logger("multiprocessing.run_all")


def find_all_prospekt_folders(base: Path | None = None) -> List[Path]:
    """Sucht automatisch ALLE Prospekt-Ordner in der Ordnerstruktur.
    
    Args:
        base: Base directory to search (default: media/prospekte)
        
    Returns:
        List of folder paths containing prospekt files
    """
    if base is None:
        # Try common locations
        if Path("media/prospekte").exists():
            base = Path("media/prospekte")
        elif Path("server/media/prospekte").exists():
            base = Path("server/media/prospekte")
        else:
            base = Path(".") / "media" / "prospekte"
    
    if not base.exists():
        LOGGER.warning("[RUN_ALL] Base directory not found: %s", base)
        return []
    
    folders = []
    
    # Look for folders containing raw.pdf or raw.html
    for folder in base.rglob("*"):
        if not folder.is_dir():
            continue
        
        # Check if folder contains prospekt files
        has_pdf = (folder / "raw.pdf").exists()
        has_html = (folder / "raw.html").exists()
        
        if has_pdf or has_html:
            folders.append(folder)
    
    return sorted(folders)


def run_all(force: bool = False, max_workers: int | None = None) -> Dict[str, Any]:
    """Startet die gesamte MP-Pipeline.
    
    Args:
        force: Force reprocessing even if output exists
        max_workers: Maximum number of parallel workers (overrides config)
        
    Returns:
        Dictionary with run results
    """
    folders = find_all_prospekt_folders()
    
    if not folders:
        base_search = Path("media/prospekte")
        print("❌ Keine Prospekt-Ordner gefunden.")
        print(f"   Gesucht in: {base_search}")
        return {
            "status": "error",
            "message": "No prospekt folders found",
            "folders_processed": 0,
        }
    
    workers = max_workers if max_workers is not None else CPU_LIMIT
    
    base_dir = folders[0].parent if folders else Path("media/prospekte")
    
    print(f"\n📦 Gefunden: {len(folders)} Prospekt-Ordner")
    print(f"🚀 Starte Verarbeitung mit {workers} parallelen Prozessen...")
    print(f"📂 Basis-Verzeichnis: {base_dir}\n")
    
    # Import multiprocessing
    import multiprocessing as mp
    
    # Prepare results
    results: List[Dict[str, Any]] = []
    
    # Use multiprocessing pool
    with mp.Pool(workers) as pool:
        try:
            # Process with progress bar
            iterator = pool.imap_unordered(process_folder, folders)
            
            if tqdm:
                iterator = tqdm(iterator, total=len(folders), desc="🔄 Gesamtfortschritt")
            
            for result in iterator:
                results.append(result)
                
                # Print status for each result
                if result.get("status") == "ok":
                    print(f"   ✓ {Path(result['folder']).name}: {result['offers_count']} Angebote")
                else:
                    print(f"   ✗ {Path(result['folder']).name}: {result.get('error', 'Unknown error')}")
                    
        except KeyboardInterrupt:
            print("\n⚠️  Verarbeitung abgebrochen durch Benutzer")
            pool.terminate()
            pool.join()
            return {
                "status": "interrupted",
                "folders_processed": len(results),
                "results": results,
            }
        except Exception as exc:
            LOGGER.error("[RUN_ALL] Pool processing failed: %s", exc)
            traceback.print_exc()
            return {
                "status": "error",
                "error": str(exc),
                "folders_processed": len(results),
                "results": results,
            }
    
    # Erfolgsauswertung
    ok = sum(1 for r in results if r.get("status") == "ok")
    failed = len(results) - ok
    total_offers = sum(r.get("offers_count", 0) for r in results)
    
    print("\n" + "=" * 60)
    print("🎉 MULTIPROCESSING-PIPELINE ABGESCHLOSSEN")
    print("=" * 60)
    print(f"📊 Verarbeitet: {len(folders)} Ordner")
    print(f"   ✔ Erfolgreich: {ok}")
    print(f"   ❌ Fehlgeschlagen: {failed}")
    print(f"   📦 Gesamt-Angebote: {total_offers}")
    print("=" * 60)
    
    # Speichere Log
    log_dir = Path(__file__).parent
    log_file = log_dir / "last_run.json"
    
    run_summary = {
        "timestamp": datetime.now().isoformat(),
        "status": "completed",
        "folders_total": len(folders),
        "folders_success": ok,
        "folders_failed": failed,
        "total_offers": total_offers,
        "workers_used": workers,
        "results": results,
    }
    
    log_file.write_text(
        json.dumps(run_summary, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    
    print(f"\n📝 Log gespeichert: {log_file}")
    
    return run_summary


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Process all prospekt folders in parallel")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force reprocessing even if output exists",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=None,
        help="Number of parallel workers (default: auto-detect)",
    )
    
    args = parser.parse_args()
    
    try:
        run_all(force=args.force, max_workers=args.workers)
    except KeyboardInterrupt:
        print("\n⚠️  Abgebrochen durch Benutzer")
        sys.exit(1)
    except Exception as exc:
        LOGGER.error("[RUN_ALL] Fatal error: %s", exc)
        traceback.print_exc()
        sys.exit(1)

