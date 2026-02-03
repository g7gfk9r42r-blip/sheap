#!/usr/bin/env python3
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "assets" / "recipes" / "recipes_aldi_sued.json"

def to_float(x, default=0.0):
    try:
        return float(x)
    except Exception:
        return default

def main():
    raw = json.load(open(P, "r", encoding="utf-8"))

    # raw is already migrated to list? (after your migrate script, it's now canonical list)
    # but you still have the original offers_catalog somewhere only in the old wrapper file.
    # Therefore: load the original wrapper weekly file (which still contains offers_catalog).
    # If you kept it: assets/recipes/recipes_aldi_sued_2026-W01.json
    wrapper_path = ROOT / "assets" / "recipes" / "recipes_aldi_sued_2026-W01.json"
    wrapper = json.load(open(wrapper_path, "r", encoding="utf-8"))
    offers_catalog = wrapper.get("offers_catalog", [])

    # build offer_id -> offer map
    offer_map = {}
    for o in offers_catalog:
        if isinstance(o, dict):
            oid = o.get("offer_id") or o.get("id")
            if oid:
                offer_map[str(oid)] = o

    fixed = 0
    total = 0

    for r in raw:
        if not isinstance(r, dict):
            continue
        ings = r.get("ingredients", [])
        if not isinstance(ings, list):
            continue

        for idx, ing in enumerate(ings):
            if not isinstance(ing, dict):
                continue

            # detect from_offer
            from_offer = ing.get("from_offer")
            if from_offer is None:
                # legacy keys
                if ing.get("fromOffer") is True:
                    from_offer = True
                else:
                    from_offer = False

            if not from_offer:
                continue

            total += 1

            # resolve offer id
            oid = ing.get("offer_id") or ing.get("offerId") or ing.get("matchedOfferId") or ing.get("matchedOfferID")
            if oid is None:
                # sometimes offer ref stored inside ingredient
                oid = ing.get("offer") if isinstance(ing.get("offer"), str) else None
            offer = offer_map.get(str(oid)) if oid is not None else None

            # Fill required fields
            if ing.get("offer_id") is None and oid is not None:
                ing["offer_id"] = str(oid)

            if ing.get("brand") is None:
                ing["brand"] = (offer.get("brand") if isinstance(offer, dict) else None) or "Unbekannt"

            if ing.get("unit") is None:
                ing["unit"] = (offer.get("unit") if isinstance(offer, dict) else None) or "pcs"

            if ing.get("pack_size") is None:
                ing["pack_size"] = (
                    (offer.get("pack_size") if isinstance(offer, dict) else None)
                    or (offer.get("quantity") if isinstance(offer, dict) else None)
                    or "1x"
                )

            if ing.get("packs_used") is None:
                ing["packs_used"] = 1

            if ing.get("used_amount") is None:
                ing["used_amount"] = ing.get("amountText") or ing.get("amount") or "1x"

            if ing.get("price_eur") is None:
                val = None
                if isinstance(offer, dict):
                    val = offer.get("price_eur") or offer.get("price")
                ing["price_eur"] = to_float(val, 0.0)

            if ing.get("price_before_eur") is None:
                val = None
                if isinstance(offer, dict):
                    val = offer.get("price_before_eur") or offer.get("price_before")
                # allow null if not known; if validator needs number, change to 0.0
                ing["price_before_eur"] = to_float(val, 0.0) if val is not None else 0.0

            fixed += 1

        r["ingredients"] = ings

    json.dump(raw, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    print(f"aldi_sued: fixed from_offer ingredients: {fixed} (total offer-ings seen: {total})")

if __name__ == "__main__":
    main()