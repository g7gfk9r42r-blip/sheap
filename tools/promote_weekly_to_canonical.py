#!/usr/bin/env python3
"""
Promote Weekly Recipes to Canonical
Wählt für jeden erlaubten Market die neueste Quelle und kopiert zu canonical file.
"""

import json
import shutil
import re
from pathlib import Path
from typing import Dict, List, Optional
from collections import defaultdict

PROJECT_ROOT = Path(__file__).parent.parent
ASSETS_RECIPES_DIR = PROJECT_ROOT / 'assets' / 'recipes'

# HART: Nur diese Markets sind erlaubt (Globus entfernt)
ALLOWED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'lidl', 'rewe', 'edeka', 'kaufland',
    'netto', 'penny', 'norma', 'biomarkt', 'tegut'
}


def extract_market_slug_from_filename(filename: str) -> Optional[str]:
    """Extrahiert market_slug aus recipes_<market_slug>[_weekKey].json"""
    if not filename.startswith('recipes_') or not filename.endswith('.json'):
        return None
    
    # Entferne "recipes_" und ".json"
    slug_part = filename[8:-5]
    
    # Entferne Week-Key Pattern (z.B. _2025-W52, _2026-W01)
    slug_part = re.sub(r'_\d{4}-W\d{2}$', '', slug_part)
    
    # Filtere "with" und "unknown"
    if 'with' in slug_part.lower() or 'unknown' in slug_part.lower():
        return None
    
    # Prüfe ob in ALLOWED_MARKETS
    if slug_part in ALLOWED_MARKETS:
        return slug_part
    
    return None


def find_candidate_sources() -> Dict[str, List[Path]]:
    """Findet alle Kandidaten-Quellen pro Market"""
    candidates_by_market = defaultdict(list)
    
    # Scan assets/recipes/ für alle recipes_*.json
    for json_file in ASSETS_RECIPES_DIR.glob('recipes_*.json'):
        market = extract_market_slug_from_filename(json_file.name)
        if market and market in ALLOWED_MARKETS:
            candidates_by_market[market].append(json_file)
    
    return dict(candidates_by_market)


def promote_to_canonical(market_slug: str, candidates: List[Path]) -> Optional[Path]:
    """Wählt neueste Quelle und kopiert zu canonical file"""
    if market_slug not in ALLOWED_MARKETS:
        return None
    
    canonical_file = ASSETS_RECIPES_DIR / f'recipes_{market_slug}.json'
    
    # Wenn canonical bereits existiert: behalte es
    if canonical_file.exists():
        return canonical_file
    
    # Wenn keine Kandidaten: nichts tun
    if not candidates:
        return None
    
    # Wähle neueste Datei (nach mtime)
    latest = max(candidates, key=lambda p: p.stat().st_mtime)
    
    # Wenn latest == canonical: skip (sollte nicht passieren, aber sicherheitshalber)
    if latest == canonical_file:
        return canonical_file
    
    # Kopiere zu canonical
    try:
        ASSETS_RECIPES_DIR.mkdir(parents=True, exist_ok=True)
        shutil.copy2(latest, canonical_file)
        return latest
    except Exception as e:
        print(f"  ❌ Fehler beim Kopieren {market_slug}: {e}")
        return None


def main():
    print("🔄 Promote Weekly Recipes to Canonical\n")
    print("=" * 60)
    
    # Finde Kandidaten
    print("\n1️⃣ Suche Kandidaten-Quellen...")
    candidates = find_candidate_sources()
    
    if not candidates:
        print("  ⚠️  Keine Kandidaten gefunden")
        return
    
    print(f"  Gefunden: {len(candidates)} Markets mit Kandidaten")
    
    # Promote pro Market
    print("\n2️⃣ Promote zu Canonical Files...")
    promoted = {}
    kept = {}
    skipped = {}
    
    for market in sorted(ALLOWED_MARKETS):
        market_candidates = candidates.get(market, [])
        
        canonical_file = ASSETS_RECIPES_DIR / f'recipes_{market}.json'
        
        if canonical_file.exists():
            kept[market] = canonical_file
            print(f"  ✅ {market}: canonical bereits vorhanden")
        elif market_candidates:
            source = promote_to_canonical(market, market_candidates)
            if source:
                promoted[market] = source
                print(f"  ✅ {market}: promoted von {source.name}")
            else:
                skipped[market] = market_candidates
                print(f"  ⚠️  {market}: promote fehlgeschlagen")
        else:
            skipped[market] = []
            print(f"  ⚠️  {market}: keine Kandidaten gefunden")
    
    # Zusammenfassung
    print("\n" + "=" * 60)
    print("\n📊 Zusammenfassung:")
    print(f"   Canonical behalten: {len(kept)}")
    print(f"   Promoted: {len(promoted)}")
    print(f"   Übersprungen (keine Quelle): {len([m for m, c in skipped.items() if not c])}")
    
    if promoted:
        print("\n📋 Promoted Sources:")
        for market, source in sorted(promoted.items()):
            print(f"   {market}: {source.name}")
    
    if kept:
        print("\n📋 Canonical Files (bereits vorhanden):")
        for market, canonical in sorted(kept.items()):
            print(f"   {market}: {canonical.name}")
    
    print("\n✅ Promote abgeschlossen!")


if __name__ == '__main__':
    main()

