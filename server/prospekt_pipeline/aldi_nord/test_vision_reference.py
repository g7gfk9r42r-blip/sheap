"""Test script for reference-based Vision AI parsing."""
from __future__ import annotations

import os
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from prospekt_pipeline.aldi_nord.baseline_builder import BaselineBuilder
from prospekt_pipeline.aldi_nord.reference_vision_parser import ReferenceVisionParser


def load_env():
    """Load .env file manually."""
    env_paths = [
        Path(__file__).parent.parent.parent / ".env",
        Path(".") / ".env",
        Path("server") / ".env",
    ]

    for env_path in env_paths:
        if env_path.exists():
            print(f"📄 Loading .env from: {env_path.absolute()}")
            with open(env_path) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        key, value = line.split("=", 1)
                        os.environ[key.strip()] = value.strip().strip('"').strip("'")
            return True

    print("❌ .env file not found")
    return False


def main():
    """Test reference-based Vision AI."""
    print("=" * 60)
    print("🧪 TEST: Reference-Based Vision AI")
    print("=" * 60)

    # Load environment
    if not load_env():
        return 1

    # Check API key
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("❌ OPENAI_API_KEY not set in .env")
        return 1

    print("✅ OPENAI_API_KEY found\n")

    # Find test folder
    test_folders = [
        Path("media/prospekte/aldi_nord"),
        Path("server/media/prospekte/aldi_nord"),
        Path(".") / "media" / "prospekte" / "aldi_nord",
    ]

    test_folder = None
    for folder in test_folders:
        if folder.exists():
            # First try: find subdirectory
            subdirs = [d for d in folder.iterdir() if d.is_dir()]
            if subdirs:
                test_folder = subdirs[0]
                break
            
            # Second try: check if folder itself has PDFs
            pdf_files = list(folder.glob("*.pdf"))
            if pdf_files:
                test_folder = folder
                print(f"📄 Found PDFs directly in {folder.name}")
                break

    if not test_folder:
        print("❌ No ALDI Nord folder found")
        print("   Expected: media/prospekte/aldi_nord/ or media/prospekte/aldi_nord/<folder>/")
        return 1

    print(f"📂 Test folder: {test_folder.name}")
    print(f"📁 Path: {test_folder}\n")

    # Find PDF (can be raw.pdf or any .pdf file)
    pdf_path = None
    if (test_folder / "raw.pdf").exists():
        pdf_path = test_folder / "raw.pdf"
    else:
        # Find all PDF files and pick the best one
        pdf_files = list(test_folder.glob("*.pdf"))
        if pdf_files:
            # Prefer files with "promotion" or "angebot" in name (better quality)
            preferred = [f for f in pdf_files if any(keyword in f.name.lower() for keyword in ["promotion", "angebot", "cw"])]
            if preferred:
                pdf_path = preferred[0]
            else:
                pdf_path = pdf_files[0]
    
    if not pdf_path or not pdf_path.exists():
        print(f"❌ No PDF found in {test_folder.name}")
        return 1

    print(f"✅ Found PDF: {pdf_path.name}\n")

    # 1. Build baseline
    print("=" * 60)
    print("STEP 1: Building Baseline")
    print("=" * 60)
    baseline_builder = BaselineBuilder()
    baseline_offers = baseline_builder.build_baseline(test_folder)
    baseline_path = baseline_builder.save_baseline(test_folder, baseline_offers)

    print(f"\n✅ Baseline created: {len(baseline_offers)} offers")
    print(f"📄 Saved to: {baseline_path.name}\n")

    # 2. Test Vision AI with reference
    print("=" * 60)
    print("STEP 2: Vision AI with Reference (Test Page 1)")
    print("=" * 60)

    vision_parser = ReferenceVisionParser()
    if not vision_parser.client:
        print("❌ Vision parser not initialized")
        return 1

    print(f"🔍 Testing page 1 extraction...")
    page_offers = vision_parser.find_missing_offers(
        pdf_path,
        baseline_offers,
        page_number=1,
    )

    print(f"\n✅ Extracted {len(page_offers)} offers from page 1")

    if page_offers:
        print("\n📋 Sample offers from page 1:")
        for i, offer in enumerate(page_offers[:10], 1):  # Show first 10
            print(f"   {i}. {offer.title} - {offer.price_raw or offer.price}")
        if len(page_offers) > 10:
            print(f"   ... and {len(page_offers) - 10} more")
    else:
        print("\n⚠️  No offers extracted from page 1")

    # 3. Test full processing (ALL pages)
    print("\n" + "=" * 60)
    print("STEP 3: Full Processing (ALL Pages)")
    print("=" * 60)

    all_vision_offers = vision_parser.process_all_pages(
        pdf_path,
        baseline_offers,
        max_pages=None,  # Process ALL pages
        smart_sampling=False,  # Process every page for maximum coverage
    )

    print(f"\n✅ Total offers extracted from all pages: {len(all_vision_offers)}")

    # Summary
    print("\n" + "=" * 60)
    print("📊 SUMMARY")
    print("=" * 60)
    print(f"Baseline offers (HTML+PDF): {len(baseline_offers)}")
    print(f"Vision offers (page 1): {len(page_offers)}")
    print(f"Vision offers (all pages): {len(all_vision_offers)}")
    print(f"Total extracted: {len(baseline_offers) + len(all_vision_offers)} offers")
    print(f"Note: Duplicates will be removed during merge")
    print("=" * 60)

    print("\n✅ Test completed successfully!")
    return 0


if __name__ == "__main__":
    sys.exit(main())

