#!/usr/bin/env python3
"""
Weekly Recipe Refresh Pipeline - Replica API (Offline-First)
- Liest Rezept-JSONs aus assets/prospekte/<market>/
- Generiert Bilder via Replica API
- Schreibt nach assets/recipes/ und assets/images/recipes/
- WICHTIG: Keine Rezepte erfinden, ergänzen oder entfernen
"""

import argparse
import json
import os
import sys
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from collections import defaultdict

# Import local modules
sys.path.insert(0, str(Path(__file__).parent))

from json_utils import (
    load_recipe_json,
    save_recipe_json,
    validate_recipe,
    update_recipe_image_path,
    backup_file,
)
from replica_image import ReplicaImageClient


class WeeklyRefreshPipeline:
    """Haupt-Pipeline für wöchentliche Rezept-Aktualisierung (Offline-First, Replica)"""
    
    def __init__(
        self,
        input_dir: Path,
        output_dir: Path,
        images_dir: Path,
        backup_dir: Optional[Path] = None,
        dry_run: bool = False,
        force_images: bool = False,
        only_markets: Optional[List[str]] = None,
        strict: bool = False,
        image_backend: str = "replica",
    ):
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.images_dir = Path(images_dir)
        self.backup_dir = Path(backup_dir) if backup_dir else self.output_dir / '_backup'
        self.dry_run = dry_run
        self.force_images = force_images
        self.only_markets = [m.lower().strip() for m in only_markets] if only_markets else None
        self.strict = strict
        
        # Stats
        self.stats = {
            'markets_processed': 0,
            'recipes_loaded': defaultdict(int),
            'recipes_valid': defaultdict(int),
            'recipes_invalid': defaultdict(int),
            'recipes_output': defaultdict(int),
            'images_generated': defaultdict(int),
            'images_skipped': defaultdict(int),
            'images_failed': defaultdict(int),
            'files_written': 0,
            'errors': [],
            'markets_found': 0,
            'markets_skipped': 0,
            'skipped_markets': [],
            'duplicate_ids': defaultdict(list),
        }
        
        # Image Client
        self.image_client = None
        if image_backend == "replica":
            try:
                self.image_client = ReplicaImageClient()
            except ValueError as e:
                print(f"⚠️  WARNING: {e}")
                if strict:
                    sys.exit(1)
            except Exception as e:
                print(f"⚠️  WARNING: Replica Client Fehler: {e}")
                if strict:
                    sys.exit(1)
    
    def validate_recipe_id(self, recipe_id: str, market: str) -> Tuple[bool, Optional[str]]:
        """Validiert Recipe-ID Format (R001-R999)"""
        if not isinstance(recipe_id, str):
            return False, f"ID is not a string: {type(recipe_id)}"
        
        match = re.match(r'^R(\d{3})$', recipe_id)
        if not match:
            return False, f"Invalid ID format: {recipe_id} (must be R001-R999)"
        
        number = int(match.group(1))
        if number < 1 or number > 999:
            return False, f"ID out of range: {recipe_id} (must be R001-R999)"
        
        return True, None
    
    def discover_markets(self) -> List[Tuple[str, Path]]:
        """
        Entdeckt alle Markets dynamisch durch Scannen von Unterordnern.
        Erwartet genau 12 Supermärkte.
        Returns: List of (market_key, json_file_path) tuples
        """
        discovered = []
        skipped = []
        
        if not self.input_dir.exists():
            return discovered
        
        # Iteriere über alle direkten Unterordner
        for subdir in sorted(self.input_dir.iterdir()):
            if not subdir.is_dir():
                continue
            
            dir_name = subdir.name
            market_key = dir_name.lower().strip()
            
            # Filter nach only_markets
            if self.only_markets:
                if market_key not in self.only_markets:
                    continue
            
            # Erwartete Datei: <dir>/<dir.name>_recipes.json
            json_file = subdir / f"{dir_name}_recipes.json"
            
            if not json_file.exists() or not json_file.is_file():
                reason = f"missing file: {json_file.name}"
                skipped.append((market_key, subdir, reason))
                continue
            
            # Prüfe ob JSON parsebar ist
            try:
                recipes, error = load_recipe_json(json_file)
                if error:
                    reason = f"unreadable JSON: {error}"
                    skipped.append((market_key, subdir, reason))
                    continue
                
                if recipes is None:
                    reason = "invalid JSON structure"
                    skipped.append((market_key, subdir, reason))
                    continue
                
                # Erfolgreich gefunden
                discovered.append((market_key, json_file))
                print(f"   ✅ {market_key:15}: {json_file.relative_to(self.input_dir.parent.parent)}")
            
            except Exception as e:
                reason = f"unexpected error: {str(e)}"
                skipped.append((market_key, subdir, reason))
                continue
        
        # Logge übersprungene Markets
        for market_key, subdir, reason in skipped:
            self.stats['skipped_markets'].append({
                'market': market_key,
                'path': str(subdir.relative_to(self.input_dir.parent.parent)),
                'reason': reason,
            })
            print(f"   ⚠️  {market_key:15}: {reason}")
        
        self.stats['markets_found'] = len(discovered)
        self.stats['markets_skipped'] = len(skipped)
        
        return discovered
    
    def process_market(self, market_key: str, input_file: Path) -> bool:
        """Verarbeitet einen Market"""
        print(f"\n📋 Verarbeite {market_key}...")
        print(f"   Input: {input_file.relative_to(self.input_dir.parent.parent)}")
        
        # Lade Rezepte
        recipes, error = load_recipe_json(input_file)
        if error:
            self.stats['errors'].append(f"{market_key}: {error}")
            print(f"   ❌ Fehler beim Laden: {error}")
            if self.strict:
                return False
            return False
        
        if not recipes:
            self.stats['errors'].append(f"{market_key}: Keine Rezepte gefunden")
            print(f"   ⚠️  Keine Rezepte gefunden")
            if self.strict:
                return False
            return False
        
        recipes_count = len(recipes)
        print(f"   📚 {recipes_count} Rezepte geladen")
        self.stats['recipes_loaded'][market_key] = recipes_count
        
        # Validiere Rezepte und prüfe IDs
        valid_recipes = []
        seen_ids = set()
        
        for idx, recipe in enumerate(recipes):
            # Validierung
            is_valid, error_msg, json_path = validate_recipe(recipe, index=idx)
            if not is_valid:
                recipe_id = recipe.get('id', 'unknown')
                self.stats['errors'].append(f"{market_key}/{recipe_id}: {error_msg} (JSON-Pfad: {json_path})")
                self.stats['recipes_invalid'][market_key] += 1
                
                if self.strict:
                    print(f"   ❌ STRICT MODE: Fehler bei Rezept {idx}: {error_msg}")
                    if json_path:
                        print(f"      JSON-Pfad: {json_path}")
                    return False
                continue
            
            # ID Validierung
            recipe_id = recipe.get('id')
            id_valid, id_error = self.validate_recipe_id(recipe_id, market_key)
            if not id_valid:
                self.stats['errors'].append(f"{market_key}/{recipe_id}: {id_error}")
                self.stats['recipes_invalid'][market_key] += 1
                
                if self.strict:
                    print(f"   ❌ STRICT MODE: Ungültige ID: {recipe_id} - {id_error}")
                    return False
                continue
            
            # Duplikat-Prüfung
            if recipe_id in seen_ids:
                self.stats['duplicate_ids'][market_key].append(recipe_id)
                self.stats['errors'].append(f"{market_key}/{recipe_id}: Duplicate ID")
                
                if self.strict:
                    print(f"   ❌ STRICT MODE: Doppelte ID gefunden: {recipe_id}")
                    return False
                continue
            
            seen_ids.add(recipe_id)
            valid_recipes.append(recipe)
        
        valid_count = len(valid_recipes)
        invalid_count = len(recipes) - valid_count
        self.stats['recipes_valid'][market_key] = valid_count
        self.stats['recipes_invalid'][market_key] = invalid_count
        
        print(f"   ✅ {valid_count} valide Rezepte")
        if invalid_count > 0:
            print(f"   ⚠️  {invalid_count} Rezepte übersprungen")
        
        if not valid_recipes:
            self.stats['errors'].append(f"{market_key}: Keine validen Rezepte")
            print(f"   ❌ Keine validen Rezepte")
            if self.strict:
                return False
            return False
        
        # WICHTIG: Output muss exakt gleich viele Rezepte haben wie Input
        if valid_count != recipes_count and self.strict:
            print(f"   ❌ STRICT MODE: Rezept-Anzahl geändert! Input: {recipes_count}, Valid: {valid_count}")
            return False
        
        # Verarbeite Bilder (nur wenn nicht dry-run)
        updated_recipes = []
        
        if not self.dry_run:
            for recipe in valid_recipes:
                recipe_id = recipe.get('id')
                
                # Erwarteter Bild-Pfad
                image_filename = f"{recipe_id}.webp"
                image_path = self.images_dir / market_key / image_filename
                image_path_str = f"assets/images/recipes/{market_key}/{image_filename}"
                
                # Prüfe ob Bild existiert
                if image_path.exists() and not self.force_images:
                    # Bild existiert bereits
                    updated_recipe = update_recipe_image_path(recipe, image_path_str)
                    updated_recipes.append(updated_recipe)
                    self.stats['images_skipped'][market_key] += 1
                    continue
                
                # Generiere Bild (falls Client verfügbar)
                if self.image_client:
                    success, error_msg = self.image_client.generate_image(
                        recipe,
                        image_path,
                        overwrite=self.force_images
                    )
                    
                    if success:
                        updated_recipe = update_recipe_image_path(recipe, image_path_str)
                        updated_recipes.append(updated_recipe)
                        self.stats['images_generated'][market_key] += 1
                        print(f"   ✅ Bild generiert: {recipe_id}")
                    else:
                        # Fehler: Rezept trotzdem behalten, aber ohne image_path
                        updated_recipes.append(recipe)
                        self.stats['images_failed'][market_key] += 1
                        self.stats['errors'].append(f"{market_key}/{recipe_id}: Bild-Generierung fehlgeschlagen - {error_msg}")
                        print(f"   ⚠️  Bild fehlgeschlagen: {recipe_id} - {error_msg}")
                else:
                    # Kein Image Client - Rezept ohne image_path
                    updated_recipes.append(recipe)
                    self.stats['images_skipped'][market_key] += 1
        else:
            # Dry-run: Nur Validierung, keine Bildgenerierung
            updated_recipes = valid_recipes
        
        # WICHTIG: Output-Anzahl muss exakt Input-Anzahl entsprechen
        output_count = len(updated_recipes)
        if output_count != recipes_count and self.strict:
            print(f"   ❌ STRICT MODE: Output-Anzahl ({output_count}) != Input-Anzahl ({recipes_count})")
            return False
        
        self.stats['recipes_output'][market_key] = output_count
        
        # Speichere Output (nur wenn nicht dry-run)
        output_file = self.output_dir / f"{market_key}_recipes.json"
        
        if self.dry_run:
            print(f"   [DRY RUN] Würde schreiben: {output_file.name} ({output_count} Rezepte)")
            self.stats['files_written'] += 1
        else:
            # Backup
            backup_success, backup_path = backup_file(output_file, self.backup_dir)
            if backup_success and backup_path:
                print(f"   💾 Backup erstellt: {backup_path.relative_to(self.backup_dir.parent)}")
            
            # Speichere
            success, error = save_recipe_json(updated_recipes, output_file)
            if success:
                self.stats['files_written'] += 1
                print(f"   ✅ Gespeichert: {output_file.name} ({output_count} Rezepte)")
            else:
                self.stats['errors'].append(f"{market_key}: Fehler beim Speichern - {error}")
                print(f"   ❌ Fehler beim Speichern: {error}")
                if self.strict:
                    return False
                return False
        
        self.stats['markets_processed'] += 1
        
        return True
    
    def run(self) -> int:
        """Führt die Pipeline aus. Returns exit code."""
        print("🔄 Weekly Recipe Refresh Pipeline - Replica (Offline-First)")
        print("=" * 60)
        
        if self.dry_run:
            print("⚠️  DRY RUN MODUS - Keine Dateien werden geschrieben, keine Bilder generiert")
            print("   Nur Market-Discovery und Validierung")
        
        if not self.image_client:
            print("⚠️  WARNING: Kein Replica API Key gefunden - Bilder werden nicht generiert")
            print("   Setze REPLICA_API_KEY environment variable")
        
        # Entdecke Markets dynamisch
        print(f"\n🔍 Entdecke Markets in {self.input_dir.relative_to(self.input_dir.parent.parent.parent) if self.input_dir.parent.parent.parent.exists() else self.input_dir}...")
        discovered_markets = self.discover_markets()
        
        if not discovered_markets:
            print(f"\n❌ Keine Markets gefunden in {self.input_dir}")
            if self.strict and self.stats['markets_skipped'] > 0:
                print(f"\n❌ STRICT MODE: {self.stats['markets_skipped']} Markets übersprungen -> Exit 1")
                return 1
            return 2
        
        print(f"\n📁 {self.stats['markets_found']} Market(s) gefunden")
        if self.stats['markets_skipped'] > 0:
            print(f"❌ {self.stats['markets_skipped']} Ordner übersprungen")
        
        # Verarbeite Markets
        for market_key, input_file in discovered_markets:
            success = self.process_market(market_key, input_file)
            if not success:
                if self.strict:
                    print(f"\n❌ STRICT MODE: Fehler bei {market_key} -> Exit 1")
                    return 1
                # Nicht-strict: Weiter mit nächstem Market
        
        # Report
        self.print_report()
        
        # Exit code
        if self.stats['markets_processed'] == 0:
            if self.strict and self.stats['markets_skipped'] > 0:
                return 1
            return 2
        
        if self.strict and (self.stats['markets_skipped'] > 0 or len(self.stats['errors']) > 0):
            return 1
        
        return 0
    
    def print_report(self):
        """Druckt einen Report"""
        print("\n" + "=" * 60)
        print("📊 REPORT")
        print("=" * 60)
        
        print(f"\n✅ Markets verarbeitet: {self.stats['markets_processed']}")
        
        print(f"\n📚 Rezepte pro Market:")
        for market in sorted(set(list(self.stats['recipes_loaded'].keys()) + list(self.stats['recipes_output'].keys()))):
            loaded = self.stats['recipes_loaded'].get(market, 0)
            valid = self.stats['recipes_valid'].get(market, 0)
            invalid = self.stats['recipes_invalid'].get(market, 0)
            output = self.stats['recipes_output'].get(market, 0)
            print(f"   {market}: geladen={loaded}, valide={valid}, invalide={invalid}, output={output}")
            
            # Prüfe Konsistenz
            if loaded != output:
                print(f"      ⚠️  WARNING: Input ({loaded}) != Output ({output})")
        
        if not self.dry_run:
            print(f"\n🖼️  Bilder:")
            total_generated = sum(self.stats['images_generated'].values())
            total_skipped = sum(self.stats['images_skipped'].values())
            total_failed = sum(self.stats['images_failed'].values())
            
            print(f"   Generiert: {total_generated}")
            print(f"   Übersprungen: {total_skipped}")
            print(f"   Fehlgeschlagen: {total_failed}")
            
            if self.stats['images_generated']:
                print(f"\n   Pro Market (generiert):")
                for market, count in sorted(self.stats['images_generated'].items()):
                    print(f"      {market}: {count}")
        
        if not self.dry_run:
            print(f"\n💾 Dateien geschrieben: {self.stats['files_written']}")
        
        if self.stats['duplicate_ids']:
            print(f"\n⚠️  Doppelte IDs gefunden:")
            for market, ids in sorted(self.stats['duplicate_ids'].items()):
                print(f"   {market}: {', '.join(ids)}")
        
        if self.stats['skipped_markets']:
            print(f"\n❌ Übersprungene Markets ({len(self.stats['skipped_markets'])}):")
            for skipped in self.stats['skipped_markets']:
                print(f"   - {skipped['market']:15} ({skipped['path']}): {skipped['reason']}")
        
        if self.stats['errors']:
            print(f"\n⚠️  Fehler ({len(self.stats['errors'])}):")
            max_errors = 20 if self.dry_run else 10
            for error in self.stats['errors'][:max_errors]:
                print(f"   - {error}")
            if len(self.stats['errors']) > max_errors:
                print(f"   ... und {len(self.stats['errors']) - max_errors} weitere Fehler")
        
        print("\n" + "=" * 60)


def main():
    parser = argparse.ArgumentParser(
        description='Weekly Recipe Refresh Pipeline - Replica API (Offline-First)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Beispiele:
  python3 tools/weekly_refresh_replica.py --input assets/prospekte --out assets/recipes --images assets/images/recipes --image-backend replica --strict
  python3 tools/weekly_refresh_replica.py --input assets/prospekte --out assets/recipes --images assets/images/recipes --dry-run
        """
    )
    
    parser.add_argument(
        '--input',
        type=str,
        required=True,
        help='Input-Verzeichnis mit Rezept-JSONs (z.B. assets/prospekte)'
    )
    
    parser.add_argument(
        '--out',
        type=str,
        required=True,
        help='Output-Verzeichnis für Rezept-JSONs (z.B. assets/recipes)'
    )
    
    parser.add_argument(
        '--images',
        type=str,
        required=True,
        help='Verzeichnis für Rezept-Bilder (z.B. assets/images/recipes)'
    )
    
    parser.add_argument(
        '--backup',
        type=str,
        default=None,
        help='Backup-Verzeichnis (optional, Standard: <out>/_backup)'
    )
    
    parser.add_argument(
        '--only',
        type=str,
        default=None,
        help='Nur bestimmte Markets verarbeiten (komma-separiert, z.B. aldi_nord,aldi_sued)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        default=False,
        help='Dry-Run Modus: Nur Discovery und Validierung, keine Dateien/Bilder'
    )
    
    parser.add_argument(
        '--force-images',
        action='store_true',
        default=False,
        help='Bilder neu generieren auch wenn bereits vorhanden'
    )
    
    parser.add_argument(
        '--strict',
        action='store_true',
        default=False,
        help='Strict Mode: Exit 1 bei Validierungsfehlern'
    )
    
    parser.add_argument(
        '--image-backend',
        type=str,
        default='replica',
        choices=['replica'],
        help='Image Backend (Standard: replica)'
    )
    
    args = parser.parse_args()
    
    # Parse only_markets
    only_markets = None
    if args.only:
        only_markets = [m.strip() for m in args.only.split(',')]
    
    # Erstelle Pipeline
    pipeline = WeeklyRefreshPipeline(
        input_dir=Path(args.input),
        output_dir=Path(args.out),
        images_dir=Path(args.images),
        backup_dir=Path(args.backup) if args.backup else None,
        dry_run=args.dry_run,
        force_images=args.force_images,
        only_markets=only_markets,
        strict=args.strict,
        image_backend=args.image_backend,
    )
    
    # Führe Pipeline aus
    exit_code = pipeline.run()
    
    sys.exit(exit_code)


if __name__ == '__main__':
    main()

