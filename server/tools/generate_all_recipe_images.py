#!/usr/bin/env python3
"""
Master-Script für Bildgenerierung
- Stock-markierte Rezepte → Shutterstock
- Rest → SDXL KI-Generierung
"""

import sys
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent.parent


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Generiert/lädt Bilder für Rezepte')
    parser.add_argument('--retailer', required=True, help='Retailer (z.B. aldi_nord)')
    parser.add_argument('--limit', type=int, help='Limit Anzahl Rezepte')
    parser.add_argument('--stock-only', action='store_true', help='Nur Stock-Rezepte verarbeiten')
    parser.add_argument('--ai-only', action='store_true', help='Nur AI-Generierung (keine Stock)')
    
    args = parser.parse_args()
    
    print(f"\n{'='*60}")
    print(f"🎨 MASTER: Bildgenerierung für {args.retailer.upper()}")
    print(f"{'='*60}\n")
    
    # 1. Stock-Rezepte → Shutterstock
    if not args.ai_only:
        print("📸 Schritt 1: Stock-Bilder von Shutterstock...")
        try:
            stock_script = PROJECT_ROOT / 'server' / 'tools' / 'fetch_stock_images_shutterstock.py'
            cmd = [sys.executable, str(stock_script), '--retailer', args.retailer]
            if args.limit:
                cmd.extend(['--limit', str(args.limit)])
            
            subprocess.run(cmd, check=False)
        except Exception as e:
            print(f"⚠️  Fehler bei Stock-Bilder: {e}")
        print()
    
    # 2. Nicht-Stock-Rezepte → SDXL
    if not args.stock_only:
        print("🤖 Schritt 2: KI-Generierung mit SDXL...")
        try:
            sdxl_script = PROJECT_ROOT / 'server' / 'tools' / 'generate_recipe_images_sdxl.py'
            cmd = [sys.executable, str(sdxl_script), '--retailer', args.retailer, '--skip-existing']
            if args.limit:
                cmd.extend(['--limit', str(args.limit)])
            
            subprocess.run(cmd, check=False)
        except Exception as e:
            print(f"⚠️  Fehler bei SDXL-Generierung: {e}")
        print()
    
    print(f"{'='*60}")
    print(f"✅ FERTIG!")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    main()

