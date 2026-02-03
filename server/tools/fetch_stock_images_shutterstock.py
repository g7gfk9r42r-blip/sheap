#!/usr/bin/env python3
"""
Shutterstock API Integration für Stock-Bilder
Lädt Bilder für Rezepte die mit 'stock': true markiert sind
"""

import os
import sys
import json
import requests
from pathlib import Path
from typing import Dict, List, Optional
from dotenv import load_dotenv

# Lade .env
load_dotenv()

# Shutterstock API Konfiguration
SHUTTERSTOCK_API_KEY = os.getenv('SHUTTERSTOCK_API_KEY')
SHUTTERSTOCK_API_SECRET = os.getenv('SHUTTERSTOCK_API_SECRET')
SHUTTERSTOCK_BASE_URL = 'https://api.shutterstock.com/v2'

# Projekt-Pfade
PROJECT_ROOT = Path(__file__).parent.parent.parent
RECIPES_DIR = PROJECT_ROOT / 'assets' / 'recipes'
OUTPUT_DIR = PROJECT_ROOT / 'server' / 'media' / 'recipe_images'
OUTPUT_ASSETS_DIR = PROJECT_ROOT / 'assets' / 'recipe_images'


def get_shutterstock_token() -> Optional[str]:
    """
    Authentifiziert sich bei Shutterstock API und gibt Access Token zurück
    """
    if not SHUTTERSTOCK_API_KEY or not SHUTTERSTOCK_API_SECRET:
        print("❌ SHUTTERSTOCK_API_KEY und SHUTTERSTOCK_API_SECRET müssen in .env gesetzt sein")
        return None
    
    auth_url = f'{SHUTTERSTOCK_BASE_URL}/oauth/access_token'
    auth = (SHUTTERSTOCK_API_KEY, SHUTTERSTOCK_API_SECRET)
    
    try:
        response = requests.post(
            auth_url,
            auth=auth,
            data={'grant_type': 'client_credentials'},
            timeout=10
        )
        response.raise_for_status()
        token_data = response.json()
        return token_data.get('access_token')
    except Exception as e:
        print(f"❌ Fehler bei Shutterstock Authentifizierung: {e}")
        return None


def search_shutterstock_image(query: str, token: str, per_page: int = 1) -> Optional[Dict]:
    """
    Sucht ein Bild auf Shutterstock basierend auf Query-String
    """
    search_url = f'{SHUTTERSTOCK_BASE_URL}/images/search'
    headers = {'Authorization': f'Bearer {token}'}
    
    params = {
        'query': query,
        'image_type': 'photo',
        'category': 'food',  # Food-Kategorie
        'orientation': 'horizontal',
        'people_model_released': True,
        'per_page': per_page,
        'sort': 'relevance',
        'safe': True,
    }
    
    try:
        response = requests.get(search_url, headers=headers, params=params, timeout=15)
        response.raise_for_status()
        data = response.json()
        
        if 'data' in data and len(data['data']) > 0:
            return data['data'][0]  # Erstes/bestes Ergebnis
        return None
    except Exception as e:
        print(f"   ⚠️  Fehler bei Shutterstock Suche für '{query}': {e}")
        return None


def download_shutterstock_image(image_data: Dict, output_path: Path) -> bool:
    """
    Lädt ein Bild von Shutterstock herunter
    Nutzt die preview-URL (für Test) oder kauft die Lizenz (Production)
    """
    # Für Tests: Nutze preview-URL
    # Für Production: Muss Lizenz gekauft werden!
    preview_url = image_data.get('assets', {}).get('preview', {}).get('url')
    
    if not preview_url:
        print(f"   ⚠️  Keine Preview-URL gefunden")
        return False
    
    try:
        response = requests.get(preview_url, timeout=30)
        response.raise_for_status()
        
        # Speichere als WebP
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_bytes(response.content)
        return True
    except Exception as e:
        print(f"   ⚠️  Fehler beim Download: {e}")
        return False


def process_recipes_for_stock_images(retailer: str, limit: Optional[int] = None):
    """
    Verarbeitet Rezepte für Stock-Bilder
    """
    # Lade Rezepte
    recipe_file = RECIPES_DIR / f'recipes_{retailer}.json'
    if not recipe_file.exists():
        print(f"❌ Rezept-Datei nicht gefunden: {recipe_file}")
        return
    
    with open(recipe_file, 'r', encoding='utf-8') as f:
        recipes = json.load(f)
    
    # Filtere nur Stock-Rezepte
    stock_recipes = [r for r in recipes if r.get('stock') is True]
    
    if not stock_recipes:
        print(f"⚠️  Keine Stock-markierten Rezepte gefunden in {retailer}")
        return
    
    if limit:
        stock_recipes = stock_recipes[:limit]
    
    print(f"\n{'='*60}")
    print(f"📸 Verarbeite Stock-Bilder für: {retailer.upper()}")
    print(f"{'='*60}")
    print(f"📚 {len(stock_recipes)} Stock-Rezepte gefunden\n")
    
    # Authentifiziere bei Shutterstock
    print("🔐 Authentifiziere bei Shutterstock API...")
    token = get_shutterstock_token()
    if not token:
        print("❌ Authentifizierung fehlgeschlagen")
        return
    print("✅ Authentifizierung erfolgreich\n")
    
    # Verarbeite jedes Rezept
    stats = {'processed': 0, 'success': 0, 'failed': 0, 'skipped': 0}
    
    for i, recipe in enumerate(stock_recipes, 1):
        recipe_id = recipe.get('id', 'UNKNOWN')
        title = recipe.get('title') or recipe.get('name', '')
        week_key = recipe.get('week_key') or recipe.get('weekKey', '2026-W01')
        
        # Normalisiere retailer zu slug
        retailer_normalized = retailer.lower().replace(' ', '_').replace('ü', 'u').replace('ö', 'o')
        if retailer_normalized == 'aldi_süd':
            retailer_normalized = 'aldi_sued'
        
        output_path = OUTPUT_ASSETS_DIR / retailer_normalized / week_key / f'{recipe_id}.webp'
        
        # Überspringe wenn bereits vorhanden
        if output_path.exists():
            print(f"[{i}/{len(stock_recipes)}] {recipe_id}: {title[:50]}")
            print(f"   ⏭️  Übersprungen (bereits vorhanden)")
            stats['skipped'] += 1
            continue
        
        print(f"[{i}/{len(stock_recipes)}] {recipe_id}: {title[:50]}")
        
        # Suche auf Shutterstock
        query = f"{title} food photography"
        print(f"   🔍 Suche: '{query}'")
        
        image_data = search_shutterstock_image(query, token)
        if not image_data:
            print(f"   ❌ Kein Bild gefunden")
            stats['failed'] += 1
            continue
        
        image_id = image_data.get('id', 'UNKNOWN')
        print(f"   ✅ Bild gefunden (ID: {image_id})")
        
        # Download
        if download_shutterstock_image(image_data, output_path):
            size_kb = output_path.stat().st_size / 1024
            print(f"   ✅ Gespeichert: {output_path.relative_to(PROJECT_ROOT)} ({size_kb:.1f} KB)")
            stats['success'] += 1
        else:
            print(f"   ❌ Download fehlgeschlagen")
            stats['failed'] += 1
        
        stats['processed'] += 1
        print()
    
    # Statistik
    print(f"\n{'='*60}")
    print(f"✅ VERARBEITUNG ABGESCHLOSSEN")
    print(f"{'='*60}")
    print(f"📊 Statistiken:")
    print(f"   Gesamt: {len(stock_recipes)}")
    print(f"   Verarbeitet: {stats['processed']}")
    print(f"   Erfolgreich: {stats['success']}")
    print(f"   Übersprungen: {stats['skipped']}")
    print(f"   Fehlgeschlagen: {stats['failed']}")
    print(f"{'='*60}\n")


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Lädt Stock-Bilder von Shutterstock')
    parser.add_argument('--retailer', required=True, help='Retailer (z.B. aldi_nord)')
    parser.add_argument('--limit', type=int, help='Limit Anzahl Rezepte')
    
    args = parser.parse_args()
    process_recipes_for_stock_images(args.retailer, args.limit)

