"""Pipeline reporting"""
import json
from datetime import datetime
from pathlib import Path
from typing import Dict


def create_report(
    weekkey: str,
    supermarket: str,
    offers_count: int,
    recipes_count: int,
    nutrition_stats: Dict,
    output_dir: Path
) -> Dict:
    """Create run report"""
    
    report = {
        'weekkey': weekkey,
        'supermarket': supermarket,
        'timestamp': datetime.now().isoformat(),
        'results': {
            'offers_extracted': offers_count,
            'recipes_generated': recipes_count,
            'nutrition_coverage': {
                'ingredients_total': nutrition_stats.get('total_ingredients', 0),
                'ingredients_enriched': nutrition_stats.get('enriched', 0),
                'ingredients_missing': nutrition_stats.get('missing', 0),
                'cache_hits': nutrition_stats.get('cache_hits', 0),
                'coverage_percent': round(
                    nutrition_stats.get('enriched', 0) / max(nutrition_stats.get('total_ingredients', 1), 1) * 100,
                    1
                )
            }
        },
        'output_files': {
            'offers': str(output_dir / f"offers_{weekkey}.json"),
            'recipes': str(output_dir / f"recipes_{weekkey}.json"),
            'report': str(output_dir / f"run_{weekkey}.report.json")
        }
    }
    
    return report


def save_report(report: Dict, output_path: Path):
    """Save report to file"""
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

