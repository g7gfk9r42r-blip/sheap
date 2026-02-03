"""CLI entry point for ALDI Nord prospekt processing."""
from __future__ import annotations

import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from prospekt_pipeline.aldi_nord.aldi_nord_processor import AldiNordProcessor


def main():
    """Find all ALDI Nord folders and process them."""
    # Base directory
    base_dir = Path("media/prospekte/aldi_nord")
    
    # Try alternative paths
    if not base_dir.exists():
        base_dir = Path("server/media/prospekte/aldi_nord")
    if not base_dir.exists():
        base_dir = Path(".") / "media" / "prospekte" / "aldi_nord"

    if not base_dir.exists():
        print(f"❌ ALDI Nord directory not found: {base_dir}")
        print("   Expected structure: media/prospekte/aldi_nord/")
        return 1

    print(f"📂 Searching for ALDI Nord folders in: {base_dir.absolute()}")

    # Find all subdirectories OR process base_dir directly if it has PDFs
    folders = [d for d in base_dir.iterdir() if d.is_dir()]
    
    # If no subdirectories, check if base_dir itself has PDFs
    if not folders:
        pdf_files = list(base_dir.glob("*.pdf"))
        html_files = list(base_dir.glob("*.html"))
        if pdf_files or html_files:
            print(f"📄 Found files directly in {base_dir.name}, processing as single folder")
            folders = [base_dir]
        else:
            print(f"⚠️  No subdirectories, PDFs, or HTML files found in {base_dir}")
            return 1

    print(f"📦 Found {len(folders)} folder(s) to process\n")

    # Initialize processor
    processor = AldiNordProcessor()

    # Process each folder
    results = []
    for folder in sorted(folders):
        try:
            result = processor.process(folder)
            results.append({
                "folder": str(folder),
                "offers_count": result.get("metadata", {}).get("total_offers", 0),
                "status": "success",
            })
        except Exception as e:
            print(f"❌ Error processing {folder.name}: {e}")
            results.append({
                "folder": str(folder),
                "offers_count": 0,
                "status": "error",
                "error": str(e),
            })

    # Summary
    print("\n" + "="*60)
    print("📊 SUMMARY")
    print("="*60)
    total_offers = sum(r["offers_count"] for r in results)
    successful = sum(1 for r in results if r["status"] == "success")
    
    print(f"✅ Processed: {successful}/{len(folders)} folders")
    print(f"📦 Total offers: {total_offers}")
    
    for result in results:
        status_icon = "✅" if result["status"] == "success" else "❌"
        print(f"   {status_icon} {Path(result['folder']).name}: {result['offers_count']} offers")

    print("\n✅ ALDI Nord processing complete!")
    return 0


if __name__ == "__main__":
    sys.exit(main())

