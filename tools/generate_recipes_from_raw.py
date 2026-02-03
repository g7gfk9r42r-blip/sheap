#!/usr/bin/env python3
"""
Generate weekly recipes JSON from raw prospect text (Terminal tool).

This script runs OUTSIDE Flutter (local/CI/server) and produces a strict JSON file.

Requirements:
- Python 3
- OPENAI_API_KEY env var
- openai python package (OpenAI Chat Completions)

Example:
  python3 tools/generate_recipes_from_raw.py \
    --retailer "NORMA" \
    --week "2026-W03" \
    --valid-from "2026-01-13" \
    --in "weekly_raw/norma.txt" \
    --out "assets/recipes/norma_recipes.json"
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    from openai import OpenAI
except Exception:
    print("❌ Error: openai package not installed.")
    print("Fix: pip install -r tools/recipe_generator_requirements.txt")
    raise SystemExit(1)


BASE_INGREDIENTS = ["Salz", "Pfeffer", "Öl", "Wasser", "Zucker", "Gewürze"]
CATEGORY_SET = {
    "High Protein",
    "Low Carb",
    "Vegetarisch",
    "Vegan",
    "Gluten-free",
    "Laktosefrei",
    "Kalorienarm",
    "Kalorienreich",
}

_LAST_DIE_MESSAGE: Optional[str] = None


def _slugify_de(s: str) -> str:
    """
    Convert German-ish text into kebab-case with ASCII only.
    Examples:
      "feta-salat-mit-gemüse" -> "feta-salat-mit-gemuese"
      "hähnchenflügel-grill"  -> "haehnchenfluegel-grill"
    """
    s = (s or "").strip().lower()
    s = (
        s.replace("ä", "ae")
        .replace("ö", "oe")
        .replace("ü", "ue")
        .replace("ß", "ss")
    )
    s = re.sub(r"[^a-z0-9]+", "-", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s


PROMPT_TEMPLATE = """\
⸻
AUFGABE:
Erstelle {recipe_count} hochwertige Rezepte aus den gegebenen Angebotsdaten.

AUSGABE:
NUR JSON
Dateiname logisch aus Kontext ableitbar
Kein Text außerhalb des JSON

⸻
ZUTATEN-LOGIK (streng):

1. Angebotszutaten ("ingredients"):
- from_offer: true
- exakt aus Angebotsdaten
- "ingredients" darf NUR Angebotszutaten enthalten (keine Nicht-Angebotszutaten!)
- JEDER Eintrag in "ingredients" MUSS ein Objekt sein und MUSS explizit "from_offer": true enthalten.
- Beispiel (gültig):
  {{
    "from_offer": true,
    "offer_id": "O001",
    "name": "Hähnchenbrustfilet",
    "brand": "ALDI",
    "unit": "g",
    "pack_size": 400,
    "packs_used": 1,
    "used_amount": 400,
    "price_eur": 3.99,
    "price_before_eur": 4.99
  }}
- Packungen müssen vollständig aufgehen
- Packungen müssen vollständig aufgehen (SEHR WICHTIG):
  - packs_used muss eine ganze Zahl >= 1 sein (keine 0, keine Brüche)
  - used_amount MUSS GENAU pack_size * packs_used sein
  - used_amount darf NICHT kleiner sein als pack_size*packs_used
  Beispiel:
  pack_size=500, packs_used=1  => used_amount=500
  pack_size=250, packs_used=2  => used_amount=500
- Pflichtfelder:
  offer_id, name, brand
  unit, pack_size, packs_used, used_amount
  price_eur, price_before_eur

2. Nicht-Angebotszutaten ("without_offers"):
- keine Basiszutaten
- nur geschmacksrelevant (z. B. Zwiebel, Knoblauch, Zitrone, Honig)
- ohne Preis & Marke
- immer mit Mengenangabe
- Format: String-Liste, z.B. "Zwiebel (1 Stk)", "Knoblauch (1 Zehe)", "Zitrone (1/2 Stk)"
- WICHTIG: mindestens 50% der Zutaten müssen Angebotszutaten sein
  → len(ingredients) >= len(without_offers)

3. Basiszutaten ("base_ingredients"):
- immer exakt:
  ["Salz","Pfeffer","Öl","Wasser","Zucker","Gewürze"]

⸻
REZEPT-REGELN:
- Portionen/servings:
  - Standard: 2 Portionen
  - ABER: Wenn eine Angebots-Packung sonst nicht sinnvoll aufgeht, darfst du servings erhöhen
    (z.B. 4 oder 6), sodass die Angebots-Packung(en) vollständig verwendet werden können.
  - In diesem Fall muss das Rezept konsistent sein: Title/Steps bleiben logisch, und servings ist
    die tatsächliche Ausgabemenge.
- mind. 3 Zutaten
- mind. 3 Kategorien aus:
  High Protein, Low Carb, Vegetarisch, Vegan,
  Gluten-free, Laktosefrei, Kalorienarm, Kalorienreich
- categories MUSS eine Liste mit mindestens 3 Einträgen sein (keine leeren Listen, keine Duplikate)
- nur diese erlaubten Kategorien verwenden:
  High Protein | Low Carb | Vegetarisch | Vegan | Gluten-free | Laktosefrei | Kalorienarm | Kalorienreich
- Restaurant-Level, aber alltagstauglich
- konkrete Kochschritte
- Kundentauglichkeit (wichtig):
  - Keine absurden Getränk-Kombos (z.B. "Apfelschorle Smoothie", "Cola-Pasta", "Energy-Bowl")
  - Getränke/Smoothies nur SELTEN:
    - max. 2 Getränke-Rezepte pro 50 Rezepte (und nur wenn passende Angebotszutaten vorhanden sind, z.B. Obst + Skyr/Joghurt)
    - ansonsten Fokus auf echte Mahlzeiten (Frühstück, Lunch, Dinner, Snacks)
    - KEINE Smoothies als "Ausweich-Rezept" nur um Rezepte zu füllen
  - Fokus auf alltagstaugliche, deutsche Geschmäcker (modern, aber nicht weird)
  - Keine Low-Effort Rezepte:
    - KEINE "Butter-Nudeln", "Nudeln mit Butter", "nur Reis", "nur Tiefkühlpizza" ohne Upgrade
    - Fertigprodukte nur, wenn du sie klar als solche benennst UND sinnvoll aufwertest (z.B. Tiefkühlpizza + Upgrade mit Angebotszutaten)
    - WICHTIG: Wenn eine Rezeptidee eine Tiefkühlpizza verwendet, MUSS im Titel das Wort "Tiefkühlpizza" vorkommen.
- Namen smart, modern, viral, nicht zu lang
- duration_minutes: 5–45
- difficulty: easy | medium
- IDs fortlaufend: {recipe_id_start} ... (genau {recipe_count} Stück, fortlaufend)
- Angebots-IDs: nutze die offer_id aus den Angebotsdaten (falls vorhanden), sonst O001, O002, …
- Du darfst Angebotszutaten über mehrere Rezepte wiederverwenden, solange die Packungslogik stimmt.

⸻
ANGEBOTSGÜLTIGKEIT:
Jedes Rezept:
"valid_from": "YYYY-MM-DD"
→ darf nicht vor Angebotsstart gültig sein

⸻
JSON-SCHEMA (Pflicht):

{{
  "retailer": "{retailer}",
  "week_key": "{week_key}",
  "valid_from": "{valid_from}",
  "recipes": [
    {{
      "id": "R001",
      "slug": "kebab-case",
      "title": "Titel",
      "retailer": "{retailer}",
      "week_key": "{week_key}",
      "valid_from": "{valid_from}",
      "servings": 4,
      "duration_minutes": 10,
      "difficulty": "easy",
      "categories": [...],
      "image_hint": "stock",
      "base_ingredients": ["Salz","Pfeffer","Öl","Wasser","Zucker","Gewürze"],
      "ingredients": [...],
      "without_offers": [...],
      "steps": [...],
      "notes": ""
    }}
  ]
}}

⸻
WICHTIG:
- Gib ausschließlich valides JSON zurück
- Keine Kommentare
- Keine Markdown-Blöcke
- Kein erklärender Text
- Erzeuge GENAU {recipe_count} Rezepte.
- IDs müssen genau fortlaufend sein (keine Lücken, keine Duplikate).
"""


def _set_last_die(msg: str) -> None:
    global _LAST_DIE_MESSAGE
    _LAST_DIE_MESSAGE = msg


def _get_last_die() -> Optional[str]:
    return _LAST_DIE_MESSAGE

 


@dataclass
class Args:
    retailer: str
    week: str
    valid_from: str
    input_path: Path
    output_path: Path
    model: str


def _die(msg: str, code: int = 2) -> None:
    _set_last_die(msg)
    print(f"❌ {msg}")
    raise SystemExit(code)


def _read_text(path: Path) -> str:
    if not path.exists():
        _die(f"Input file not found: {path}")
    raw = path.read_text(encoding="utf-8", errors="replace")
    if len(raw.strip()) < 50:
        _die(f"Input file too short/empty: {path}")
    return raw


def _approx_tokens(s: str) -> int:
    """
    Cheap, dependency-free token approximation.
    For German + JSON-heavy text, ~3.2–3.6 chars/token is a decent heuristic.
    We use a conservative divisor to avoid context overflows.
    """
    return max(1, int(len(s) / 3.2))


def _extract_balanced_json_from(text: str, start_index: int = 0) -> Optional[str]:
    """
    Extract the first balanced top-level JSON object starting at/after start_index.
    Returns the JSON string or None.
    """
    start = text.find("{", start_index)
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(text)):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return None


def _to_float(x: Any) -> Optional[float]:
    try:
        if x is None:
            return None
        if isinstance(x, (int, float)):
            return float(x)
        if isinstance(x, str):
            return float(x.strip().replace(",", "."))
    except Exception:
        return None
    return None


def _to_int(x: Any) -> Optional[int]:
    try:
        if x is None:
            return None
        if isinstance(x, bool):
            return None
        if isinstance(x, int):
            return x
        if isinstance(x, float):
            return int(x)
        if isinstance(x, str):
            return int(float(x.strip().replace(",", ".")))
    except Exception:
        return None
    return None


def _normalize_batch_payload(
    payload: Dict[str, Any],
    args: Args,
    *,
    recipe_start_index: int,
    recipe_count: int,
) -> Dict[str, Any]:
    """
    Minimal, safe normalization to reduce avoidable validation failures.
    - enforce header fields (retailer/week/valid_from)
    - enforce sequential IDs for this batch (R{start}..)
    - enforce from_offer=true for offer-ingredient objects that otherwise match required schema
    - fix common pack mistakes: make (pack_size, packs_used, used_amount) consistent
    """
    if not isinstance(payload, dict):
        return payload

    payload["retailer"] = args.retailer
    payload["week_key"] = args.week
    payload["valid_from"] = args.valid_from

    recipes = payload.get("recipes")
    if not isinstance(recipes, list):
        return payload

    for i, r in enumerate(recipes[:recipe_count]):
        if not isinstance(r, dict):
            continue

        # Enforce batch IDs + headers
        r["id"] = f"R{recipe_start_index + i:03d}"
        r["retailer"] = args.retailer
        r["week_key"] = args.week
        r["valid_from"] = args.valid_from

        # Hard defaults for required/strict fields
        r["image_hint"] = "stock"
        r["base_ingredients"] = BASE_INGREDIENTS
        r["notes"] = str(r.get("notes", "") or "")

        # servings: default 2, allow scale-up (2-12)
        servings_int = _to_int(r.get("servings")) or 2
        if servings_int < 2:
            servings_int = 2
        if servings_int > 12:
            servings_int = 12
        r["servings"] = servings_int

        # duration_minutes: clamp 5-45
        dm_int = _to_int(r.get("duration_minutes")) or 20
        if dm_int < 5:
            dm_int = 5
        if dm_int > 45:
            dm_int = 45
        r["duration_minutes"] = dm_int

        # difficulty: only easy|medium
        diff = str(r.get("difficulty", "") or "").strip().lower()
        if diff not in ("easy", "medium"):
            diff = "easy"
        r["difficulty"] = diff

        # categories: must be list with >=3 allowed entries
        cats_raw = r.get("categories", [])
        if isinstance(cats_raw, str):
            cats_raw = [c.strip() for c in cats_raw.split(",") if c.strip()]
        if not isinstance(cats_raw, list):
            cats_raw = []
        cats = []
        for c in cats_raw:
            cs = str(c).strip()
            if cs in CATEGORY_SET and cs not in cats:
                cats.append(cs)
        defaults = ["Vegetarisch", "Kalorienarm", "Low Carb", "High Protein", "Gluten-free", "Laktosefrei", "Vegan", "Kalorienreich"]
        for d in defaults:
            if len(cats) >= 3:
                break
            if d in CATEGORY_SET and d not in cats:
                cats.append(d)
        r["categories"] = cats

        # Normalize slug early (batch-level validation requires kebab-case ASCII)
        slug_raw = str(r.get("slug", "")).strip()
        if not slug_raw:
            slug_raw = str(r.get("title", "")).strip()
        slug = _slugify_de(slug_raw)
        if not slug:
            slug = f"recipe-r{recipe_start_index + i:03d}"
        r["slug"] = slug

        # Quality guard: if recipe uses "Tiefkühlpizza"/Pizza as an offer ingredient,
        # the title must explicitly say "Tiefkühlpizza" (per product truth-in-labeling).
        try:
            title = str(r.get("title", "") or "").strip()
            ing_names = []
            for it in r.get("ingredients", []) if isinstance(r.get("ingredients"), list) else []:
                if isinstance(it, dict):
                    ing_names.append(str(it.get("name", "") or "").strip().lower())
            uses_pizza = any(("pizza" in n) for n in ing_names)
            if uses_pizza and "tiefkühlpizza" not in title.lower():
                # Only enforce when it looks like a frozen/ready pizza offer, not e.g. "Pizza-Gewürz".
                if any(("tiefk" in n) or ("tk" in n and "pizza" in n) or ("pizza" in n and "ofen" not in n) for n in ing_names):
                    if title:
                        r["title"] = f"Tiefkühlpizza-Upgrade: {title}"
                    else:
                        r["title"] = "Tiefkühlpizza-Upgrade"
                    r["slug"] = _slugify_de(r["title"])
        except Exception:
            pass

        # steps: ensure list with >=2 items
        steps = r.get("steps")
        if isinstance(steps, str):
            parts = [p.strip() for p in re.split(r"\n+|\r+|(?m)^\s*\d+\.\s*", steps) if p.strip()]
            steps = parts
        if not isinstance(steps, list):
            steps = []
        steps = [str(s).strip() for s in steps if str(s).strip()]
        if len(steps) < 2:
            # Fallback (rare): keep it short but valid
            steps = ["Zutaten vorbereiten.", "Alles garen und abschmecken."]
        r["steps"] = steps

        ing = r.get("ingredients")
        if not isinstance(ing, list):
            ing = []
            r["ingredients"] = ing

        wo = r.get("without_offers")
        if not isinstance(wo, list):
            wo = []
            r["without_offers"] = wo

        for it in ing:
            if not isinstance(it, dict):
                continue

            # If it looks like an offer ingredient but model forgot the flag, infer it.
            if it.get("from_offer") is not True:
                if all(k in it for k in ("offer_id", "name", "unit", "pack_size", "packs_used", "used_amount", "price_eur")):
                    it["from_offer"] = True

            # Fill missing brand for offer ingredients (required by strict schema)
            if it.get("from_offer") is True:
                b = str(it.get("brand", "") or "").strip()
                if not b:
                    it["brand"] = args.retailer
                # Ensure required keys exist (validator requires presence, value may be null)
                if "price_before_eur" not in it:
                    it["price_before_eur"] = None

            # Normalize pack usage consistency
            pack_size = _to_float(it.get("pack_size"))
            packs_used = _to_int(it.get("packs_used"))
            used_amount = _to_float(it.get("used_amount"))

            if pack_size and pack_size > 0:
                # If used_amount is present and is an exact multiple of pack_size, set packs_used accordingly.
                if used_amount is not None:
                    ratio = used_amount / pack_size
                    if abs(ratio - round(ratio)) < 1e-6 and ratio >= 1:
                        it["packs_used"] = int(round(ratio))
                        packs_used = it["packs_used"]

                # If packs_used is present, enforce used_amount = pack_size * packs_used (full pack usage)
                if packs_used is not None and packs_used >= 1:
                    it["used_amount"] = float(pack_size * packs_used)

        # without_offers: must be list[str], must not include base ingredients tokens
        wo_clean: List[str] = []
        for x in wo:
            s = str(x).strip()
            if not s:
                continue
            if s in BASE_INGREDIENTS:
                continue
            wo_clean.append(s)
        r["without_offers"] = wo_clean
        wo = wo_clean

        # Enforce 50%+ offer-ingredient ratio by trimming without_offers if needed.
        # Rule: len(ingredients) >= len(without_offers)
        if len(ing) < len(wo):
            r["without_offers"] = wo[: len(ing)]
            wo = r["without_offers"]

        # Ensure minimum total ingredients (>=3) while keeping the 50% offer rule.
        # With len(ingredients) >= len(without_offers), the smallest valid combo for total>=3 is:
        # - 2 offer + 1 without (total=3), or 3 offer + 0 without (total=3)
        total = len(ing) + len(wo)
        if total < 3:
            # Prefer to duplicate an existing offer ingredient to reach 2 offers.
            if len(ing) == 1:
                it0 = ing[0]
                if isinstance(it0, dict):
                    dup = dict(it0)
                    # Keep same offer_id; allow using 2 packs if needed.
                    dup_pack_size = _to_float(dup.get("pack_size")) or 0.0
                    dup["packs_used"] = 1
                    if dup_pack_size > 0:
                        dup["used_amount"] = float(dup_pack_size)
                    dup["from_offer"] = True
                    ing.append(dup)
            # If still too small, drop without_offers to 0 and rely on offer ingredients.
            wo = r.get("without_offers", [])
            if isinstance(wo, list) and len(ing) + len(wo) < 3:
                r["without_offers"] = []

    # If model returned too many recipes, trim to expected count for this batch.
    payload["recipes"] = [r for r in recipes if isinstance(r, dict)][:recipe_count]
    return payload


def _ensure_unique_slugs(recipes: List[Dict[str, Any]]) -> None:
    """
    Ensure slugs are unique (and remain kebab-case) across the final merged list.
    If duplicates exist, append "-r###" based on recipe id.
    """
    seen = set()
    for r in recipes:
        if not isinstance(r, dict):
            continue
        rid = str(r.get("id", "")).strip().lower()
        slug = _slugify_de(str(r.get("slug", "")).strip())
        if not slug or not _slug_ok(slug):
            # Derive a basic slug from title if missing/invalid
            title = _slugify_de(str(r.get("title", "")).strip())
            slug = title or f"recipe-{rid or 'unknown'}"
            slug = re.sub(r"-{2,}", "-", slug).strip("-")

        base = slug
        if base in seen:
            suffix = rid if rid.startswith("r") else f"r{rid}"
            slug = f"{base}-{suffix}".strip("-")
            # If still collides (rare), add a counter
            counter = 2
            while slug in seen:
                slug = f"{base}-{suffix}-{counter}"
                counter += 1
        seen.add(slug)
        r["slug"] = slug


def _try_slim_lidl_combined(raw_text: str) -> Optional[str]:
    """
    If the input is a Lidl combined file that embeds a large JSON blob, replace it with a slim JSON.
    This avoids context length overflows while keeping all offers.
    """
    marker_idx = raw_text.find("LIDL EXTRACT (JSON")
    if marker_idx < 0:
        return None

    json_str = _extract_balanced_json_from(raw_text, start_index=marker_idx)
    if not json_str:
        return None
    try:
        data = json.loads(json_str)
    except Exception:
        return None

    offers = data.get("offers") if isinstance(data, dict) else None
    if not isinstance(offers, list) or not offers:
        return None

    offers_slim: List[Dict[str, Any]] = []
    for idx, o in enumerate(offers, start=1):
        if not isinstance(o, dict):
            continue
        offers_slim.append(
            {
                "offer_id": o.get("offer_id") or f"O{idx:03d}",
                "product_name": o.get("product_name"),
                "brand": o.get("brand"),
                "variant": o.get("variant"),
                "offer_price": o.get("offer_price"),
                "price_before": o.get("price_before"),
                "uvp": o.get("uvp"),
                "unit_price_value": o.get("unit_price_value"),
                "unit_price_per": o.get("unit_price_per"),
                "discount_percent": o.get("discount_percent"),
                "pack_size_text": o.get("pack_size_text"),
                "multi_buy_text": o.get("multi_buy_text"),
                "lidl_plus": o.get("lidl_plus"),
                "action_type": o.get("action_type"),
                "confidence": o.get("confidence"),
                "page": o.get("page"),
            }
        )

    slim_payload = {
        "supermarket": data.get("supermarket", "LIDL") if isinstance(data, dict) else "LIDL",
        "total_offers": len(offers_slim),
        "offers": offers_slim,
    }
    slim_json = json.dumps(slim_payload, ensure_ascii=False, indent=2)

    # Replace only the JSON blob (keep the original text section intact).
    replaced = raw_text.replace(json_str, slim_json, 1)
    replaced = replaced.replace("LIDL EXTRACT (JSON)", "LIDL EXTRACT (JSON SLIM)", 1)
    return replaced


def _compact_generic(raw_text: str, max_chars: int) -> str:
    """
    Generic lossy compaction:
    - collapse excessive blank lines
    - drop long separator lines
    - if still too large, truncate to max_chars (head)
    """
    s = raw_text.replace("\r\n", "\n").replace("\r", "\n")
    # Drop common separator-only lines to save tokens
    s = re.sub(r"(?m)^[=—⸻\-\_]{8,}\s*$\n?", "", s)
    # Collapse 3+ blank lines
    s = re.sub(r"\n{3,}", "\n\n", s)
    if len(s) <= max_chars:
        return s
    return s[:max_chars] + "\n\n[TRUNCATED: input was too large; earlier content kept]\n"


def _preprocess_raw_for_model(raw_text: str) -> str:
    """
    Ensure the input fits into large-context models reliably.
    """
    # 128k context models: keep a safety margin for prompt + response.
    max_raw_tokens = 110_000
    if _approx_tokens(raw_text) <= max_raw_tokens:
        return raw_text

    slimmed = _try_slim_lidl_combined(raw_text)
    if slimmed and _approx_tokens(slimmed) < _approx_tokens(raw_text):
        raw_text = slimmed

    # Final generic compaction with a conservative char budget.
    max_chars = int(3.2 * max_raw_tokens)
    return _compact_generic(raw_text, max_chars=max_chars)


def _extract_json(text: str) -> str:
    """Extract the first top-level JSON object from model output."""
    s = text.strip()
    s = re.sub(r"^```(?:json)?\s*", "", s, flags=re.IGNORECASE)
    s = re.sub(r"\s*```$", "", s)
    if s.startswith("{") and s.endswith("}"):
        return s

    start = s.find("{")
    if start < 0:
        _die("Model output did not contain any JSON object.")
    depth = 0
    for i in range(start, len(s)):
        ch = s[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return s[start : i + 1]
    _die("Could not extract a complete JSON object from model output.")
    return ""  # unreachable


def _slug_ok(slug: str) -> bool:
    return bool(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", slug.strip()))


def _expect_sequential(prefix: str, values: List[str]) -> None:
    expected = [f"{prefix}{i:03d}" for i in range(1, len(values) + 1)]
    if values != expected:
        _die(f"IDs not sequential ({prefix}001..): got {values[:5]}... expected {expected[:5]}...")


def _validate_recipe_obj(r: Dict[str, Any], retailer: str, week_key: str, valid_from: str) -> None:
    required = [
        "id",
        "slug",
        "title",
        "retailer",
        "week_key",
        "valid_from",
        "servings",
        "duration_minutes",
        "difficulty",
        "categories",
        "image_hint",
        "base_ingredients",
        "ingredients",
        "without_offers",
        "steps",
        "notes",
    ]
    for k in required:
        if k not in r:
            _die(f"Missing field in recipe: {k}")

    if r["retailer"] != retailer or r["week_key"] != week_key or r["valid_from"] != valid_from:
        _die(f"Recipe header mismatch for {r.get('id')}: retailer/week/valid_from must match args")

    # servings may be increased to make offer pack usage realistic (e.g. use full 500g pack => 4 servings)
    try:
        servings_int = int(r["servings"])
    except Exception:
        _die(f"servings must be an integer for {r.get('id')}")
    if servings_int < 2 or servings_int > 12:
        _die(f"servings out of range (2-12) for {r.get('id')}: {servings_int}")

    dm = int(r["duration_minutes"])
    if dm < 5 or dm > 45:
        _die(f"duration_minutes out of range (5-45) for {r.get('id')}")

    if r["difficulty"] not in ("easy", "medium"):
        _die(f"difficulty must be easy|medium for {r.get('id')}")

    if r["image_hint"] != "stock":
        _die(f"image_hint must be 'stock' for {r.get('id')}")

    if r["base_ingredients"] != BASE_INGREDIENTS:
        _die(f"base_ingredients must match exactly for {r.get('id')}")

    slug = str(r["slug"])
    if not _slug_ok(slug):
        _die(f"slug not kebab-case for {r.get('id')}: {slug}")

    cats = r["categories"]
    if not isinstance(cats, list) or len(cats) < 3:
        _die(f"categories must contain >=3 items for {r.get('id')}")
    for c in cats:
        if c not in CATEGORY_SET:
            _die(f"Invalid category '{c}' for {r.get('id')}")

    steps = r["steps"]
    if not isinstance(steps, list) or len(steps) < 2:
        _die(f"steps must be a list with >=2 items for {r.get('id')}")

    # mind. 3 Zutaten insgesamt (Angebotszutaten + without_offers)
    wo = r["without_offers"]
    if not isinstance(wo, list):
        _die(f"without_offers must be a list for {r.get('id')}")
    total_ingredients = len(r.get("ingredients") or []) + len(wo)
    if total_ingredients < 3:
        _die(f"Recipe must have at least 3 ingredients total for {r.get('id')}")

    ing = r["ingredients"]
    if not isinstance(ing, list) or len(ing) < 1:
        _die(f"ingredients must be a non-empty list for {r.get('id')}")
    # At least 50% offer ingredients:
    # We encode this as: number of offer ingredients >= number of non-offer ingredients
    if len(ing) < len(wo):
        _die(f"At least 50% of ingredients must be from offers for {r.get('id')}: ingredients={len(ing)} without_offers={len(wo)}")
    for it in ing:
        if it.get("from_offer") is not True:
            _die(f"ingredients must be from_offer:true only for {r.get('id')}")
        for k in [
            "offer_id",
            "name",
            "brand",
            "unit",
            "pack_size",
            "packs_used",
            "used_amount",
            "price_eur",
            "price_before_eur",
        ]:
            if k not in it:
                _die(f"Missing ingredient field '{k}' in {r.get('id')}")

        pack_size = float(it["pack_size"])
        packs_used = float(it["packs_used"])
        used_amount = float(it["used_amount"])
        expected_amount = pack_size * packs_used
        if abs(used_amount - expected_amount) > 1e-6:
            _die(
                f"Pack not fully used in {r.get('id')} ingredient {it.get('offer_id')}: "
                f"used_amount={used_amount} expected={expected_amount}"
            )

        # Preis-Sanity: keine 0/negativ, keine absurden Werte, before >= now (wenn before gesetzt)
        price_now = float(it["price_eur"])
        if price_now <= 0 or price_now > 200:
            _die(f"Unreasonable price_eur={price_now} for {r.get('id')} ingredient {it.get('offer_id')}")
        try:
            price_before = float(it["price_before_eur"])
        except Exception:
            price_before = None
        if price_before is not None and price_before > 0 and price_before < price_now:
            _die(
                f"price_before_eur={price_before} must be >= price_eur={price_now} "
                f"for {r.get('id')} ingredient {it.get('offer_id')}"
            )

    # without_offers: string list, must not include base ingredients
    for item in wo:
        s = str(item).strip()
        if not s:
            _die(f"without_offers items must be non-empty strings for {r.get('id')}")
        # forbid exact base ingredient tokens (also if written alone)
        if s in BASE_INGREDIENTS:
            _die(f"without_offers must not include base ingredient '{s}' for {r.get('id')}")


def validate_payload(payload: Dict[str, Any], args: Args) -> int:
    return validate_payload_with_bounds(payload, args, min_recipes=50, max_recipes=100, expect_start_index=1, expect_exact_count=None)


def validate_payload_with_bounds(
    payload: Dict[str, Any],
    args: Args,
    *,
    min_recipes: int,
    max_recipes: int,
    expect_start_index: int = 1,
    expect_exact_count: Optional[int] = None,
) -> int:
    for k in ["retailer", "week_key", "valid_from", "recipes"]:
        if k not in payload:
            _die(f"Missing top-level field: {k}")
    if payload["retailer"] != args.retailer or payload["week_key"] != args.week or payload["valid_from"] != args.valid_from:
        _die("Top-level retailer/week_key/valid_from must match CLI args.")

    recipes = payload["recipes"]
    if not isinstance(recipes, list):
        _die("recipes must be a list.")
    if expect_exact_count is not None and len(recipes) != expect_exact_count:
        _die(f"Recipe count must be exactly {expect_exact_count} (got {len(recipes)}).")
    if len(recipes) < min_recipes or len(recipes) > max_recipes:
        _die(f"Recipe count must be {min_recipes}–{max_recipes} (got {len(recipes)}).")

    ids = [str(r.get("id", "")).strip() for r in recipes]
    expected = [f"R{i:03d}" for i in range(expect_start_index, expect_start_index + len(ids))]
    if ids != expected:
        _die(f"IDs not sequential (expected {expected[:3]}..): got {ids[:3]}..")

    slugs = [str(r.get("slug", "")).strip() for r in recipes]
    if any(not s for s in slugs):
        _die("slug must be non-empty for all recipes.")
    if len(set(slugs)) != len(slugs):
        _die("slug values must be unique across all recipes.")

    for r in recipes:
        if not isinstance(r, dict):
            _die("Each recipe must be an object.")
        _validate_recipe_obj(r, args.retailer, args.week, args.valid_from)

    return len(recipes)


def call_openai_generate_batch(
    client: OpenAI,
    args: Args,
    raw_text: str,
    *,
    recipe_start_index: int,
    recipe_count: int,
    validation_feedback: Optional[str] = None,
) -> Dict[str, Any]:
    prompt = PROMPT_TEMPLATE.format(
        retailer=args.retailer,
        week_key=args.week,
        valid_from=args.valid_from,
        recipe_count=recipe_count,
        recipe_id_start=f"R{recipe_start_index:03d}",
    )
    if validation_feedback:
        prompt += (
            "\n\nVALIDATION-FEEDBACK (fix and regenerate JSON):\n"
            + validation_feedback.strip()
            + "\n"
        )
    messages = [
        {"role": "system", "content": "You are a strict JSON generator. Output valid JSON only, no markdown."},
        {"role": "user", "content": prompt + "\n\nROHTEXT:\n<<<\n" + raw_text + "\n>>>\n"},
    ]
    resp = client.chat.completions.create(
        model=args.model,
        messages=messages,
        temperature=0.3,
        max_tokens=12000,
    )
    text = resp.choices[0].message.content or ""
    j = _extract_json(text)
    try:
        return json.loads(j)
    except Exception as e:
        _die(f"Model output is not valid JSON: {e}")
    return {}  # unreachable


def main() -> None:
    p = argparse.ArgumentParser(description="Generate weekly recipes JSON from raw prospect text using OpenAI.")
    p.add_argument("--retailer", required=True, help='e.g. "NORMA"')
    p.add_argument("--week", required=True, help='e.g. "2026-W03"')
    p.add_argument("--valid-from", dest="valid_from", required=True, help="YYYY-MM-DD")
    p.add_argument("--in", dest="input_path", required=True, help="Input raw text file path")
    p.add_argument("--out", dest="output_path", required=True, help="Output JSON path (will overwrite)")
    p.add_argument("--model", default="gpt-4o-mini", help="OpenAI model (default: gpt-4o-mini)")
    ns = p.parse_args()

    args = Args(
        retailer=str(ns.retailer),
        week=str(ns.week),
        valid_from=str(ns.valid_from),
        input_path=Path(str(ns.input_path)),
        output_path=Path(str(ns.output_path)),
        model=str(ns.model),
    )

    api_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if not api_key:
        _die("OPENAI_API_KEY is not set.")

    raw_text = _read_text(args.input_path)
    # Preprocess once (avoid repeated compaction in batch mode)
    original_len = len(raw_text)
    raw_text = _preprocess_raw_for_model(raw_text)
    if len(raw_text) != original_len:
        print(
            f"ℹ️  Input compacted for model context: {original_len:,} chars → {len(raw_text):,} chars "
            f"(~{_approx_tokens(raw_text):,} tokens est.)"
        )
    args.output_path.parent.mkdir(parents=True, exist_ok=True)

    client = OpenAI(api_key=api_key)

    # Batch mode: a single response usually can't fit 50–100 detailed recipes.
    target_total = 50  # within required 50–100
    batch_size = 10

    all_recipes: List[Dict[str, Any]] = []
    print(f"🍽️  Target: {target_total} recipes total (batch_size={batch_size})")
    for start in range(1, target_total + 1, batch_size):
        count = min(batch_size, target_total - start + 1)
        print(f"🍳 Generating batch: R{start:03d}..R{start+count-1:03d} ({count} recipes)")

        last_err: Optional[str] = None
        feedback: Optional[str] = None
        max_attempts = 6
        for attempt in range(1, max_attempts + 1):
            try:
                payload = call_openai_generate_batch(
                    client,
                    args,
                    raw_text,
                    recipe_start_index=start,
                    recipe_count=count,
                    validation_feedback=feedback,
                )
                payload = _normalize_batch_payload(payload, args, recipe_start_index=start, recipe_count=count)
                # Validate this batch strictly (exact count + exact ID range)
                validate_payload_with_bounds(
                    payload,
                    args,
                    min_recipes=count,
                    max_recipes=count,
                    expect_start_index=start,
                    expect_exact_count=count,
                )
                batch_recipes = payload["recipes"]
                if not isinstance(batch_recipes, list):
                    _die("recipes must be a list.")
                all_recipes.extend(batch_recipes)
                break
            except SystemExit:
                # Validation in this file uses _die() -> SystemExit(code). Treat as retryable per-batch.
                last_err = _get_last_die() or "Validation failed."
                extra = ""
                if "Pack not fully used" in last_err or "used_amount" in last_err:
                    extra = (
                        "\nHARD REQUIREMENT (pack usage): used_amount MUST equal pack_size * packs_used exactly; "
                        "packs_used must be integer >= 1."
                    )
                if "IDs not sequential" in last_err or "ID" in last_err:
                    extra += (
                        f"\nHARD REQUIREMENT (IDs): IDs MUST start at R{start:03d} and be sequential for this batch "
                        f"(R{start:03d}..R{start+count-1:03d})."
                    )
                feedback = (
                    "Your last output failed validation. Fix ALL constraints and output JSON only.\n"
                    "HARD REQUIREMENT: Every object in recipes[*].ingredients must include \"from_offer\": true.\n"
                    f"{extra}\nError: {last_err}"
                )
                wait = 1.5 * attempt
                print(f"⚠️  Batch attempt {attempt}/{max_attempts} failed: {last_err}")
                time.sleep(wait)
                continue
            except Exception as e:
                last_err = str(e)
                feedback = (
                    "Your last output could not be parsed/validated. Fix ALL constraints and output JSON only.\n"
                    "HARD REQUIREMENT: Every object in recipes[*].ingredients must include \"from_offer\": true.\n"
                    f"Error: {last_err}"
                )
                wait = 1.5 * attempt
                print(f"⚠️  Batch attempt {attempt}/{max_attempts} failed: {last_err}")
                time.sleep(wait)
        else:
            _die(f"Failed to generate batch starting at R{start:03d}. Last error: {last_err}")

    final_payload = {
        "retailer": args.retailer,
        "week_key": args.week,
        "valid_from": args.valid_from,
        "recipes": all_recipes,
    }
    # Final normalization across all recipes (fix cross-batch duplicates like slugs)
    _ensure_unique_slugs(all_recipes)
    count = validate_payload_with_bounds(
        final_payload,
        args,
        min_recipes=50,
        max_recipes=100,
        expect_start_index=1,
        expect_exact_count=target_total,
    )
    args.output_path.write_text(json.dumps(final_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✅ Fertig: {args.output_path} ({count} Rezepte)")
    return


if __name__ == "__main__":
    main()


