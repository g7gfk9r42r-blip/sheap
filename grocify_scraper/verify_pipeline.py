#!/usr/bin/env python3
"""Verify pipeline can process existing files"""

import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

def check_files():
    """Check if source files exist"""
    base = Path(__file__).parent.parent / "server" / "media" / "prospekte"
    
    supermarkets = {
        "aldi_nord": ["aldi_nord.json"],
        "aldi_sued": ["aldi_sued.json", "ALDI SÜD Prospekt_ aktuelle Angebote.pdf"],
        "biomarkt": ["biomarkt.json", "Handzettel BioMarkt Verbund - BioMarkt_HZ_12s_kw_51-52_2025_ohne_Vorherpreis.pdf"],
        "edeka": ["edeka.json"],
        "kaufland": ["kaufland.json"],
        "lidl": ["kaufDA - Lidl - LIDL LOHNT SICH.pdf"],
        "nahkauf": ["nahkaauf.json"],
        "netto": ["8643a845-ef61-49c7-95e6-4d1e3891fa6b.pdf"],
        "norma": ["norma.json", "2025-52_FG.pdf"],
        "penny": ["penny.json", "PENNY-HZ-KW52-15A-05.pdf"],
        "rewe": ["rewe.json", "446abbff-2963-4daa-865a-21a7ea68e894.pdf"],
        "tegut": ["tegut.json", "tegut... Flugblatt KW 52_2025 Franken.pdf"],
    }
    
    results = {}
    
    for sm, files in supermarkets.items():
        sm_dir = base / sm
        found = []
        missing = []
        
        for file in files:
            file_path = sm_dir / file
            if file_path.exists():
                found.append(file)
            else:
                missing.append(file)
        
        results[sm] = {
            "found": found,
            "missing": missing,
            "has_data": len(found) > 0,
        }
    
    return results

def main():
    print("="*80)
    print("Pipeline File Verification")
    print("="*80)
    
    results = check_files()
    
    all_ok = True
    for sm, data in results.items():
        status = "✅" if data["has_data"] else "❌"
        print(f"{status} {sm:15} - Found: {len(data['found'])} files")
        if data["missing"]:
            print(f"   Missing: {', '.join(data['missing'])}")
            all_ok = False
    
    print("\n" + "="*80)
    if all_ok:
        print("✅ All supermarkets have source files")
    else:
        print("⚠️  Some files are missing, but pipeline can still run")
    print("="*80)
    
    # Save results
    output = Path("file_check_results.json")
    with open(output, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to: {output}")

if __name__ == "__main__":
    main()

