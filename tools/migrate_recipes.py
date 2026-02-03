#!/usr/bin/env python3
import json, re
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[1]
RECIPES_DIR = ROOT / "assets" / "recipes"

MARKETS = ["aldi_nord","aldi_sued","edeka","kaufland","lidl","netto","norma","penny","rewe","tegut","biomarkt"]

def iso_week_monday(week_key: str) -> str:
    m = re.match(r"(\d{4})-W(\d{2})$", str(week_key))
    if not m:
        return "1970-01-01"
    y, w = int(m.group(1)), int(m.group(2))
    return date.fromisocalendar(y, w, 1).isoformat()

def ensure_min3_categories(tags):
    cats = []
    if isinstance(tags, list):
        cats = [str(x).strip() for x in tags if str(x).strip()]
    elif isinstance(tags, str) and tags.strip():
        cats = [t.strip() for t in tags.split(",") if t.strip()]

    defaults = ["High Protein", "Low Carb", "Kalorienarm"]
    for d in defaults:
        if len(cats) >= 3:
            break
        if d not in cats:
            cats.append(d)
    return cats[:6]

def normalize_steps(v):
    if isinstance(v, list) and v:
        return [str(x).strip() for x in v if str(x).strip()]
    if isinstance(v, str) and v.strip():
        parts = [p.strip() for p in re.split(r"\n+|(?<=\.)\s+", v.strip()) if p.strip()]
        return parts[:20] if parts else ["Zubereiten und servieren."]
    return ["Zubereiten und servieren."]

def normalize_servings(v):
    if isinstance(v, int) and v > 0:
        return v
    if isinstance(v, str) and v.isdigit():
        return int(v)
    return 2

def detect_payload(raw):
    # Case A: list legacy (aldi_nord example)
    if isinstance(raw, list):
        return ("list_legacy", raw, None)

    # Case B: wrapper legacy (aldi_sued example)
    if isinstance(raw, dict) and isinstance(raw.get("recipes"), list):
        return ("wrapper_legacy", raw["recipes"], raw)

    # Fallback
    return ("unknown", [], None)

def derive_valid_from(kind, recipe, wrapper):
    # prefer explicit validity if present (aldi_sued wrapper)
    if wrapper and isinstance(wrapper.get("validity"), dict):
        vf = wrapper["validity"].get("valid_from") or wrapper["validity"].get("from")
        if isinstance(vf, str) and re.match(r"\d{4}-\d{2}-\d{2}", vf):
            return vf

    # list legacy has weekKey per recipe (aldi_nord)
    wk = recipe.get("weekKey") if isinstance(recipe, dict) else None
    if wk:
        return iso_week_monday(wk)

    return "1970-01-01"

def derive_retailer(kind, recipe, wrapper, fallback_market):
    # list legacy has "supermarket"
    if isinstance(recipe, dict) and isinstance(recipe.get("supermarket"), str) and recipe["supermarket"].strip():
        return recipe["supermarket"].strip()
    # wrapper legacy has wrapper["supermarket"]
    if wrapper and isinstance(wrapper.get("supermarket"), str) and wrapper["supermarket"].strip():
        return wrapper["supermarket"].strip()
    return fallback_market

def derive_title(kind, recipe):
    if not isinstance(recipe, dict):
        return "Rezept"
    # list legacy: shortTitle
    for k in ["title", "shortTitle", "name"]:
        v = recipe.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return "Rezept"

def migrate_market(market: str):
    path = RECIPES_DIR / f"recipes_{market}.json"
    if not path.exists():
        print(f"skip {market}: missing {path}")
        return

    raw = json.load(open(path, "r", encoding="utf-8"))
    kind, recipes, wrapper = detect_payload(raw)

    out = []
    for i, r in enumerate(recipes[:999], start=1):
        if not isinstance(r, dict):
            continue

        rid = f"R{i:03d}"
        retailer = derive_retailer(kind, r, wrapper, market)
        valid_from = derive_valid_from(kind, r, wrapper)

        migrated = dict(r)
        migrated["id"] = rid
        migrated["title"] = derive_title(kind, r)
        migrated["retailer"] = retailer
        migrated["valid_from"] = valid_from
        migrated["servings"] = normalize_servings(r.get("servings"))
        migrated["categories"] = ensure_min3_categories(r.get("tags"))
        migrated["steps"] = normalize_steps(r.get("steps"))

        out.append(migrated)

    json.dump(out, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"migrated {market}: kind={kind} -> {len(out)}")

def main():
    for m in MARKETS:
        migrate_market(m)

if __name__ == "__main__":
    main()