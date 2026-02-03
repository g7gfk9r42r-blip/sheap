#!/usr/bin/env python3
"""
Weekly Pro Pipeline (one command) for ALL supermarkets.

Replaces manual steps like:
- cd assets/prospekte/lidl && python3 extract_lidl_offers_vision.py ...
- python3 tools/weekly_generate_recipe_images.py

What it does:
1) Reads weekly raw input files (weekly_raw/<market>.txt)
2) (Optional) Lidl: if weekly_raw/lidl.pdf exists, copies it into assets/prospekte/lidl/ and runs the Vision extractor
3) Generates <market>_recipes.json into assets/prospekte/<market>/<market>_recipes.json using tools/generate_recipes_from_raw.py
4) Runs tools/weekly_refresh.py to write:
   - assets/recipes/<market>/<market>_recipes.json
   - assets/images/recipes/<market>_R###.png

Usage:
  python3 tools/weekly_pro.py --week 2026-W03 --valid-from 2026-01-13

Environment:
  OPENAI_API_KEY (required for generation)
  REPLICATE_API_TOKEN (if you want image_backend=replicate)
  REPLICA_API_KEY / other backend vars depending on your image backend
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import List, Optional
import json


PROJECT_ROOT = Path(__file__).parent.parent
PROSPEKTE_DIR = PROJECT_ROOT / "assets" / "prospekte"
ASSETS_RECIPES_OUT_DIR = PROJECT_ROOT / "assets" / "recipes"
IMAGES_OUT_DIR = PROJECT_ROOT / "assets" / "images" / "recipes"
SERVER_MEDIA_DIR = PROJECT_ROOT / "server" / "media"
OUT_RECIPES_DIR = PROJECT_ROOT / "out_recipes"
RUN_LOG_DIR = PROJECT_ROOT / "build_logs"

# Match the fixed MARKETS order from the spec
SUPPORTED_MARKETS = [
    "aldi_sued",
    "aldi_nord",
    "rewe",
    "biomarkt",
    "penny",
    "nahkauf",
    "tegut",
    "lidl",
    "norma",
    "kaufland",
    "netto",
]


@dataclass
class Args:
    week: str
    valid_from: str
    markets: List[str]
    raw_dir: Path
    model: str
    image_backend: str
    strict: bool
    lidl_full_page: bool
    lidl_dpi: int
    publish_server: bool


def _die(msg: str, code: int = 2) -> None:
    print(f"❌ {msg}")
    raise SystemExit(code)


def _load_dotenv_if_present() -> None:
    """
    Minimal .env loader (no dependency).
    Only sets vars that are not already set.
    """
    env_path = PROJECT_ROOT / ".env"
    if not env_path.exists():
        return
    try:
        for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
            s = line.strip()
            if not s or s.startswith("#") or "=" not in s:
                continue
            k, v = s.split("=", 1)
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k and k not in os.environ:
                os.environ[k] = v
    except Exception:
        # never crash on dotenv load
        return


def _run(cmd: List[str], cwd: Optional[Path] = None) -> None:
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=os.environ.copy(),
        stdout=sys.stdout,
        stderr=sys.stderr,
        text=True,
    )
    if proc.returncode != 0:
        _die(f"Command failed (exit={proc.returncode}): {' '.join(cmd)}")


def _run_allow_fail(cmd: List[str], cwd: Optional[Path] = None) -> int:
    """Run a command and return its exit code (never raises)."""
    proc = subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        env=os.environ.copy(),
        stdout=sys.stdout,
        stderr=sys.stderr,
        text=True,
    )
    return int(proc.returncode)


def _is_recipes_json_ok(path: Path, expected_week: str, expected_valid_from: str, min_count: int = 50) -> bool:
    """Lightweight resume check: file exists, parses, matches headers, has >=min_count recipes."""
    try:
        if not path.exists() or path.stat().st_size < 500:
            return False
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
        if not isinstance(data, dict):
            return False
        recipes = data.get("recipes")
        if not isinstance(recipes, list) or len(recipes) < min_count:
            return False
        if str(data.get("week_key", "")).strip() != expected_week:
            return False
        if str(data.get("valid_from", "")).strip() != expected_valid_from:
            return False
        return True
    except Exception:
        return False


def _ensure_dirs() -> None:
    # raw dir is ensured later (after args parsing)
    PROSPEKTE_DIR.mkdir(parents=True, exist_ok=True)
    ASSETS_RECIPES_OUT_DIR.mkdir(parents=True, exist_ok=True)
    IMAGES_OUT_DIR.mkdir(parents=True, exist_ok=True)
    OUT_RECIPES_DIR.mkdir(parents=True, exist_ok=True)
    RUN_LOG_DIR.mkdir(parents=True, exist_ok=True)


def _maybe_extract_lidl(args: Args) -> Path:
    """
    If weekly_raw/lidl.pdf exists, copy it into assets/prospekte/lidl/ and run extractor.
    Returns the path to the resulting lidl.txt (assets/prospekte/lidl/lidl.txt).
    """
    pdf_src = args.raw_dir / "lidl.pdf"
    lidl_dir = PROSPEKTE_DIR / "lidl"
    extractor = lidl_dir / "extract_lidl_offers_vision.py"
    txt_out = lidl_dir / "lidl.txt"
    json_out = lidl_dir / "lidl.json"
       
    if txt_out.exists() and json_out.exists() and json_out.stat().st_size > 1000:
        print("✅ LIDL: cached extraction found (lidl.txt + lidl.json) → skipping PDF extraction.")
        return txt_out
    if not pdf_src.exists():
        return txt_out

    if not extractor.exists():
        _die(
            "Lidl PDF detected at weekly_raw/lidl.pdf, but extractor not found at "
            f"{extractor}.",
        )

    lidl_dir.mkdir(parents=True, exist_ok=True)

    # Copy PDF into extractor dir (extractor auto-detects *.pdf in its directory)
    pdf_dst = lidl_dir / pdf_src.name
    shutil.copy2(pdf_src, pdf_dst)

    cmd = ["python3", str(extractor)]
    if args.lidl_full_page:
        cmd.append("--full-page")
    cmd += ["--dpi", str(args.lidl_dpi)]

    print("🧾 LIDL: extracting offers text from PDF…")
    _run(cmd, cwd=lidl_dir)

    if not txt_out.exists() or txt_out.stat().st_size < 50:
        _die(f"LIDL extractor did not produce a valid text file: {txt_out}")
    if not json_out.exists() or json_out.stat().st_size < 50:
        _die(f"LIDL extractor did not produce a valid JSON file: {json_out}")

    # Also copy to weekly_raw so the weekly inputs remain centralized
    shutil.copy2(txt_out, args.raw_dir / "lidl.txt")
    shutil.copy2(json_out, args.raw_dir / "lidl.json")
    return txt_out


def _prepare_lidl_combined_input(args: Args) -> Path:
    """
    Combine lidl.txt + lidl.json into a single text file for better recipe generation.
    The generator consumes raw text; appending structured JSON offers improves reliability.
    """
    txt_path = args.raw_dir / "lidl.txt"
    json_path = args.raw_dir / "lidl.json"
    combined = args.raw_dir / "lidl_combined.txt"

    if not txt_path.exists():
        return txt_path
    if not json_path.exists():
        return txt_path

    try:
        txt = txt_path.read_text(encoding="utf-8", errors="replace").strip()
        # IMPORTANT: lidl.json can be very large (price_candidates etc.) and may overflow model context.
        # We therefore store a slimmed JSON representation that keeps only fields needed for recipe generation.
        raw_json = json.loads(json_path.read_text(encoding="utf-8", errors="replace"))
        offers = raw_json.get("offers") if isinstance(raw_json, dict) else None
        if not isinstance(offers, list):
            offers = []

        offers_slim = []
        for idx, o in enumerate(offers, start=1):
            if not isinstance(o, dict):
                continue
            offers_slim.append(
                {
                    "offer_id": f"O{idx:03d}",
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
            "supermarket": raw_json.get("supermarket") if isinstance(raw_json, dict) else "LIDL",
            "total_offers": len(offers_slim),
            "offers": offers_slim,
        }
        j = json.dumps(slim_payload, ensure_ascii=False, indent=2)
        combined.write_text(
            "LIDL EXTRACT (TEXT)\n"
            "==================\n"
            f"{txt}\n\n"
            "LIDL EXTRACT (JSON SLIM)\n"
            "========================\n"
            f"{j}\n",
            encoding="utf-8",
        )
        return combined
    except Exception:
        return txt_path


def _generate_market_recipes(args: Args, market: str) -> bool:
    input_txt = args.raw_dir / f"{market}.txt"

    if market == "lidl":
        # allow lidl.txt to come from extractor output
        if not input_txt.exists():
            # maybe extractor already wrote it to prospekte, copy in
            lidl_txt = PROSPEKTE_DIR / "lidl" / "lidl.txt"
            if lidl_txt.exists():
                shutil.copy2(lidl_txt, input_txt)
        # if we also have lidl.json, build a combined input
        input_txt = _prepare_lidl_combined_input(args)

    if not input_txt.exists():
        print(f"⚠️  {market}: missing weekly raw input: {input_txt} — skipping.")
        return False

    # 1) Primary output (fixed structure): out_recipes/<market>_recipes.json
    out_json = OUT_RECIPES_DIR / f"{market}_recipes.json"
    # Resume: if we already have a good file for this week/date, reuse it
    if _is_recipes_json_ok(out_json, args.week, args.valid_from, min_count=50):
        print(f"✅ {market}: existing recipes found → skipping generation ({out_json.name})")
        # Ensure mirror into prospekte dir for weekly_refresh input
        out_dir = PROSPEKTE_DIR / market
        out_dir.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(out_json, out_dir / f"{market}_recipes.json")
        except Exception:
            pass
        return True

    # 2) Convenience copy for traceability: keep raw under assets/prospekte/<market>/<market>.txt
    out_dir = PROSPEKTE_DIR / market
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copy2(input_txt, out_dir / f"{market}.txt")
    except Exception:
        pass

    cmd = [
        "python3",
        str(PROJECT_ROOT / "tools" / "generate_recipes_from_raw.py"),
        "--retailer",
        market.upper(),
        "--week",
        args.week,
        "--valid-from",
        args.valid_from,
        "--in",
        str(input_txt),
        "--out",
        str(out_json),
        "--model",
        args.model,
    ]

    print(f"\n🍽️  {market}: generating recipes from weekly raw text…")
    rc = _run_allow_fail(cmd, cwd=PROJECT_ROOT)
    if rc != 0:
        print(f"⚠️  {market}: recipe generation failed (exit={rc}) — continuing.")
        return False

    # Mirror generated JSON into assets/prospekte/<market>/<market>_recipes.json for:
    # - asset fallback in the app
    # - weekly_refresh input (image generation + normalization)
    shutil.copy2(out_json, out_dir / f"{market}_recipes.json")
    return True


def _run_weekly_refresh_for_market(args: Args, market: str) -> bool:
    only = market
    cmd = [
        "python3",
        str(PROJECT_ROOT / "tools" / "weekly_refresh.py"),
        "--input",
        str(PROSPEKTE_DIR),
        "--out",
        str(ASSETS_RECIPES_OUT_DIR),
        "--images",
        str(IMAGES_OUT_DIR),
        "--only",
        only,
        "--image-backend",
        args.image_backend,
    ]
    if args.strict:
        cmd.append("--strict")

    print(f"\n🖼️  {market}: running weekly_refresh (normalize + images + app assets)…")
    rc = _run_allow_fail(cmd, cwd=PROJECT_ROOT)
    if rc != 0:
        print(f"⚠️  {market}: weekly_refresh failed (exit={rc}) — continuing.")
        return False
    return True

def _publish_market_to_server_media(args: Args, market: str) -> bool:
    """
    Publish weekly assets to server/media so the app can load updates over HTTP without a store update.
    - server/media/prospekte/<market>/<market>_recipes.json
    - server/media/recipe_images/<market>/<R###>.png
    Also rewrites each recipe's image_path to `media/recipe_images/<market>/<R###>.png`.
    """
    prospekte_out = SERVER_MEDIA_DIR / "prospekte"
    images_out = SERVER_MEDIA_DIR / "recipe_images"
    prospekte_out.mkdir(parents=True, exist_ok=True)
    images_out.mkdir(parents=True, exist_ok=True)

    # Publish the primary output (out_recipes) so weekly_raw -> out_recipes is the canonical pipeline.
    src_json = OUT_RECIPES_DIR / f"{market}_recipes.json"
    if not src_json.exists():
        print(f"⚠️  {market}: cannot publish — missing {src_json.name}")
        return False

    dest_dir = prospekte_out / market
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_json = dest_dir / f"{market}_recipes.json"

    # Load + patch image_path for remote serving
    data = json.loads(src_json.read_text(encoding="utf-8", errors="replace"))
    recipes = data["recipes"] if isinstance(data, dict) and isinstance(data.get("recipes"), list) else data
    if not isinstance(recipes, list):
        print(f"⚠️  {market}: cannot publish — unexpected JSON structure in {src_json.name}")
        return False

    for r in recipes:
        rid = str(r.get("id", "")).strip()
        if not rid:
            continue
        r["image_path"] = f"media/recipe_images/{market}/{rid}.png"

    if isinstance(data, dict) and isinstance(data.get("recipes"), list):
        data["recipes"] = recipes
        dest_json.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    else:
        dest_json.write_text(json.dumps(recipes, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # Copy images (if present)
    market_img_dir = images_out / market
    market_img_dir.mkdir(parents=True, exist_ok=True)
    copied = 0
    for img in IMAGES_OUT_DIR.glob(f"{market}_R*.png"):
        recipe_id = img.name.replace(f"{market}_", "").replace(".png", "")
        shutil.copy2(img, market_img_dir / f"{recipe_id}.png")
        copied += 1
    if copied == 0 and args.image_backend != "none":
        print(f"⚠️  {market}: publish ok, but no images found to copy (did weekly_refresh run?)")

    return True


def main() -> None:
    _load_dotenv_if_present()
    _ensure_dirs()

    parser = argparse.ArgumentParser(description="Weekly Pro pipeline for all supermarkets.")
    parser.add_argument("--week", required=False, help='ISO week key, e.g. "2026-W03" (default: current week)')
    parser.add_argument("--valid-from", dest="valid_from", required=False, help="YYYY-MM-DD (default: Monday of current ISO week)")
    parser.add_argument(
        "--markets",
        default=",".join(SUPPORTED_MARKETS),
        help="Comma-separated markets (default: all supported markets)",
    )
    parser.add_argument(
        "--raw-dir",
        default="weekly_raw",
        help='Where weekly raw inputs live (default: "weekly_raw"). You can set e.g. "weekly/raw".',
    )
    parser.add_argument("--model", default="gpt-4o-mini", help="OpenAI model (default: gpt-4o-mini)")
    parser.add_argument(
        "--image-backend",
        default="none",
        choices=["none", "replicate", "sd"],
        help="Image backend for weekly_refresh (default: none)",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Try-hard mode: run to completion (no fail-fast), but still validate and report failures at the end.",
    )
    parser.add_argument("--lidl-full-page", action="store_true", default=True, help="Use LIDL full-page analysis")
    parser.add_argument("--lidl-dpi", type=int, default=200, help="LIDL PDF DPI (default: 200)")
    parser.add_argument(
        "--publish-server",
        action="store_true",
        help="Publish JSON + images to server/media for HTTP updates (no store update after release).",
    )
    ns = parser.parse_args()

    markets = [m.strip().lower() for m in str(ns.markets).split(",") if m.strip()]
    unknown = [m for m in markets if m not in SUPPORTED_MARKETS]
    if unknown:
        _die(f"Unknown markets: {unknown}. Supported: {SUPPORTED_MARKETS}")

    if not os.environ.get("OPENAI_API_KEY"):
        _die("OPENAI_API_KEY not set (set it in your shell or in .env at project root).")

    raw_dir = PROJECT_ROOT / str(ns.raw_dir)
    # Support the common typo/alternate layout automatically if user created weekly/raw/
    if not raw_dir.exists() and (PROJECT_ROOT / "weekly" / "raw").exists():
        raw_dir = PROJECT_ROOT / "weekly" / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)

    # Defaults if user does not want to manage week/date manually
    today = date.today()
    iso = today.isocalendar()
    default_week = f"{iso.year}-W{iso.week:02d}"
    default_valid_from = date.fromisocalendar(iso.year, iso.week, 1).isoformat()  # Monday

    week_val = str(ns.week).strip() if ns.week else default_week
    valid_from_val = str(ns.valid_from).strip() if ns.valid_from else default_valid_from

    args = Args(
        week=week_val,
        valid_from=valid_from_val,
        markets=markets,
        raw_dir=raw_dir,
        model=str(ns.model),
        image_backend=str(ns.image_backend),
        strict=bool(ns.strict),
        lidl_full_page=bool(ns.lidl_full_page),
        lidl_dpi=int(ns.lidl_dpi),
        publish_server=bool(ns.publish_server),
    )

    run_id = datetime.now().strftime("%Y%m%d-%H%M%S")
    report_path = RUN_LOG_DIR / f"weekly_pro_report_{args.week}_{run_id}.json"
    report: dict = {
        "run_id": run_id,
        "week": args.week,
        "valid_from": args.valid_from,
        "markets": list(args.markets),
        "model": args.model,
        "image_backend": args.image_backend,
        "publish_server": args.publish_server,
        "results": {},
    }

    print("✅ Weekly Pro: starting")
    print(f"   Week: {args.week}")
    print(f"   valid_from: {args.valid_from}")
    print(f"   markets: {', '.join(args.markets)}")
    print(f"   raw_dir: {args.raw_dir.relative_to(PROJECT_ROOT)}")
    print(f"   model: {args.model}")
    print(f"   image_backend: {args.image_backend}")
    print(f"   publish_server: {args.publish_server}")
    print()

    # Optional Lidl PDF extraction step
    if "lidl" in args.markets:
        try:
            _maybe_extract_lidl(args)
            report["results"]["lidl_extraction"] = {"ok": True}
        except SystemExit as e:
            report["results"]["lidl_extraction"] = {"ok": False, "error": f"SystemExit({e.code})"}
            print("⚠️  LIDL extraction step failed — continuing (will rely on existing weekly_raw inputs).")

    # Generate recipes for each market from weekly_raw/<market>.txt
    for market in args.markets:
        report["results"][market] = {"recipes_ok": False, "weekly_refresh_ok": False, "published_ok": False}
        try:
            ok = _generate_market_recipes(args, market)
            report["results"][market]["recipes_ok"] = bool(ok)
        except SystemExit as e:
            report["results"][market]["recipes_ok"] = False
            report["results"][market]["recipes_error"] = f"SystemExit({e.code})"
            print(f"⚠️  {market}: recipe generation aborted — continuing.")

    # Normalize + generate images + write final app assets (per market, no fail-fast)
    for market in args.markets:
        if not report["results"].get(market, {}).get("recipes_ok"):
            continue
        ok = _run_weekly_refresh_for_market(args, market)
        report["results"][market]["weekly_refresh_ok"] = bool(ok)

    # Optional: publish to server/media for HTTP updates
    if args.publish_server:
        for market in args.markets:
            ok = _publish_market_to_server_media(args, market)
            report["results"][market]["published_ok"] = bool(ok)

    # Write report for post-mortem even if something failed while you were away
    try:
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"\n🧾 Report written: {report_path}")
    except Exception:
        pass

    print("\n✅ Weekly Pro finished.")
    print("   Output:")
    print(f"   - {OUT_RECIPES_DIR}/<market>_recipes.json")
    print(f"   - {ASSETS_RECIPES_OUT_DIR}/<market>/<market>_recipes.json (app asset fallback)")
    print(f"   - {IMAGES_OUT_DIR}/<market>_R###.png")
    if args.publish_server:
        print(f"   - {SERVER_MEDIA_DIR}/prospekte/<market>/<market>_recipes.json")
        print(f"   - {SERVER_MEDIA_DIR}/recipe_images/<market>/R###.png")

    # In strict mode, fail at the end if anything didn't succeed, but never fail-fast.
    if args.strict:
        failed = []
        for m, r in report.get("results", {}).items():
            if not isinstance(r, dict) or m == "lidl_extraction":
                continue
            if not r.get("recipes_ok"):
                failed.append(f"{m}:recipes")
            if args.image_backend != "none" and not r.get("weekly_refresh_ok"):
                failed.append(f"{m}:weekly_refresh")
            if args.publish_server and not r.get("published_ok"):
                failed.append(f"{m}:publish")
        if failed:
            _die(f"Strict run completed but with failures: {failed}. See report: {report_path}")


if __name__ == "__main__":
    main()


