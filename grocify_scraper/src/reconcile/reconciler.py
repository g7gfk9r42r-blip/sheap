"""Reconcile PDF and list sources"""

from typing import List, Dict, Any
import logging
from difflib import SequenceMatcher

from ..models import Offer

logger = logging.getLogger(__name__)


class Reconciler:
    """Reconcile offers from PDF and list sources"""
    
    @staticmethod
    def reconcile(list_offers: List[Offer], pdf_offers: List[Offer]) -> tuple[List[Offer], Dict[str, Any]]:
        """
        Reconcile PDF and list offers.
        
        RAW (list) is PRIMARY source of truth. PDF is fallback/correction only.
        Priority: RAW > PDF. When both exist, RAW wins on conflicts.
        
        Returns:
            Tuple of (merged_offers, diff_report)
        """
        merged = []
        diff_report = {
            "pdf_count": len(pdf_offers),
            "list_count": len(list_offers),
            "merged_count": 0,
            "matches": [],
            "pdf_only": [],
            "list_only": [],
        }
        
        # RAW (list) is PRIMARY - start with all list offers
        matched_pdf_indices = set()
        
        for list_offer in list_offers:
            best_match = None
            best_score = 0.0
            best_index = -1
            
            # Find best match from PDF (for correction/enrichment only)
            for i, pdf_offer in enumerate(pdf_offers):
                if i in matched_pdf_indices:
                    continue
                
                score = Reconciler._match_score(list_offer, pdf_offer)
                if score > best_score and score > 0.7:  # Threshold
                    best_match = pdf_offer
                    best_score = score
                    best_index = i
            
            if best_match:
                # Merge: RAW is base, PDF can only fill gaps or correct flags
                merged_offer = Reconciler._merge_offers_raw_priority(list_offer, best_match)
                merged.append(merged_offer)
                matched_pdf_indices.add(best_index)
                
                # Get IDs
                list_id = list_offer.id if hasattr(list_offer, 'id') else list_offer.get("id", str(list_offer))
                pdf_id = best_match.id if hasattr(best_match, 'id') else best_match.get("id", str(best_match))
                
                diff_report["matches"].append({
                    "list_id": list_id,
                    "pdf_id": pdf_id,
                    "score": best_score,
                })
            else:
                # RAW only - this is primary
                merged.append(list_offer)
                list_id = list_offer.id if hasattr(list_offer, 'id') else list_offer.get("id", str(list_offer))
                diff_report["list_only"].append(list_id)
        
        # Add unmatched PDF offers only if no RAW exists (fallback)
        if not list_offers:
            for pdf_offer in pdf_offers:
                merged.append(pdf_offer)
                diff_report["pdf_only"].append(pdf_offer.id)
        else:
            # PDF offers without RAW match: only add if they add value (not duplicates)
            for i, pdf_offer in enumerate(pdf_offers):
                if i not in matched_pdf_indices:
                    # Check if it's truly unique
                    is_duplicate = False
                    for merged_offer in merged:
                        if Reconciler._match_score(pdf_offer, merged_offer) > 0.8:
                            is_duplicate = True
                            break
                    if not is_duplicate:
                        merged.append(pdf_offer)
                        pdf_id = pdf_offer.id if hasattr(pdf_offer, 'id') else pdf_offer.get("id", str(pdf_offer))
                        diff_report["pdf_only"].append(pdf_id)
        
        diff_report["merged_count"] = len(merged)
        
        return merged, diff_report
    
    @staticmethod
    def _match_score(offer1, offer2) -> float:
        """Calculate match score between two offers (handles both Offer objects and dicts)"""
        # Helper to get attributes
        def get_attr(o, attr, default=None):
            if isinstance(o, dict):
                return o.get(attr, default)
            return getattr(o, attr, default)
        
        def get_title(o):
            return get_attr(o, "title", "").lower()
        
        def get_brand(o):
            return get_attr(o, "brand")
        
        def get_quantity_value(o):
            qty = get_attr(o, "quantity")
            if isinstance(qty, dict):
                return qty.get("value")
            elif hasattr(qty, "value"):
                return qty.value
            return None
        
        def get_quantity_unit(o):
            qty = get_attr(o, "quantity")
            if isinstance(qty, dict):
                return qty.get("unit")
            elif hasattr(qty, "unit"):
                return qty.unit
            return None
        
        # Title similarity
        title1 = get_title(offer1)
        title2 = get_title(offer2)
        title_score = SequenceMatcher(None, title1, title2).ratio()
        
        # Brand match
        brand1 = get_brand(offer1)
        brand2 = get_brand(offer2)
        brand_score = 1.0 if brand1 == brand2 and brand1 else 0.5
        
        # Quantity similarity
        qty_score = 1.0
        qty_val1 = get_quantity_value(offer1)
        qty_val2 = get_quantity_value(offer2)
        qty_unit1 = get_quantity_unit(offer1)
        qty_unit2 = get_quantity_unit(offer2)
        
        if qty_val1 and qty_val2:
            if qty_unit1 == qty_unit2:
                ratio = min(qty_val1, qty_val2) / max(qty_val1, qty_val2)
                qty_score = ratio
            else:
                qty_score = 0.5
        elif not qty_val1 and not qty_val2:
            qty_score = 1.0
        else:
            qty_score = 0.5
        
        # Weighted average
        return (title_score * 0.6 + brand_score * 0.2 + qty_score * 0.2)
    
    @staticmethod
    def _merge_offers_raw_priority(raw_offer, pdf_offer):
        """
        Merge RAW (list) offer (PRIMARY) with PDF offer (fallback/correction).
        
        RAW wins on all conflicts. PDF can only:
        - Fill missing fields (if RAW has null)
        - Correct flags if PDF has clearer data
        """
        # Helper functions
        def get_attr(o, attr, default=None):
            if isinstance(o, dict):
                return o.get(attr, default)
            return getattr(o, attr, default)
        
        def set_attr(o, attr, value):
            if isinstance(o, dict):
                o[attr] = value
            else:
                setattr(o, attr, value)
        
        # RAW is base - start with RAW offer (create copy if dict)
        if isinstance(raw_offer, dict):
            merged = raw_offer.copy()
        else:
            # For Offer objects, we'd need to create a copy - for now, work with the object
            merged = raw_offer
        
        # PDF can only fill gaps (not override RAW)
        # Fill missing brand from PDF (only if RAW doesn't have it)
        raw_brand = get_attr(merged, "brand")
        pdf_brand = get_attr(pdf_offer, "brand")
        if not raw_brand and pdf_brand:
            set_attr(merged, "brand", pdf_brand)
            set_attr(merged, "brand_confidence", get_attr(pdf_offer, "brand_confidence", "medium"))
            inferred = get_attr(merged, "inferred", {})
            if isinstance(inferred, dict):
                inferred["brand"] = True
                set_attr(merged, "inferred", inferred)
        
        # Fill missing quantity from PDF
        raw_qty = get_attr(merged, "quantity")
        pdf_qty = get_attr(pdf_offer, "quantity")
        
        raw_qty_val = None
        if isinstance(raw_qty, dict):
            raw_qty_val = raw_qty.get("value")
        elif hasattr(raw_qty, "value"):
            raw_qty_val = raw_qty.value
        
        pdf_qty_val = None
        if isinstance(pdf_qty, dict):
            pdf_qty_val = pdf_qty.get("value")
        elif hasattr(pdf_qty, "value"):
            pdf_qty_val = pdf_qty.value
        
        if not raw_qty_val and pdf_qty_val:
            set_attr(merged, "quantity", pdf_qty)
            inferred = get_attr(merged, "inferred", {})
            if isinstance(inferred, dict):
                inferred["quantity"] = True
                set_attr(merged, "inferred", inferred)
        
        # Fill missing category from PDF
        raw_category = get_attr(merged, "category")
        pdf_category = get_attr(pdf_offer, "category")
        if not raw_category and pdf_category:
            set_attr(merged, "category", pdf_category)
        
        # If RAW has MULTI_PRICE_UNCLEAR flag and PDF has clearer prices, use PDF
        raw_flags = get_attr(merged, "flags", [])
        if not isinstance(raw_flags, list):
            raw_flags = []
        
        pdf_price_tiers = get_attr(pdf_offer, "price_tiers", [])
        if "MULTI_PRICE_UNCLEAR" in raw_flags and pdf_price_tiers:
            # Check if PDF has clear standard price
            pdf_standard = []
            for pt in pdf_price_tiers:
                if isinstance(pt, dict):
                    cond_type = pt.get("condition", {}).get("type") if isinstance(pt.get("condition"), dict) else None
                else:
                    cond_type = getattr(pt.condition, "type", None) if hasattr(pt, "condition") else None
                if cond_type == "standard":
                    pdf_standard.append(pt)
            
            # Check if RAW has standard price
            merged_price_tiers = get_attr(merged, "price_tiers", [])
            has_standard = False
            for pt in merged_price_tiers:
                if isinstance(pt, dict):
                    cond_type = pt.get("condition", {}).get("type") if isinstance(pt.get("condition"), dict) else None
                else:
                    cond_type = getattr(pt.condition, "type", None) if hasattr(pt, "condition") else None
                if cond_type == "standard":
                    has_standard = True
                    break
            
            if pdf_standard and not has_standard:
                # PDF has clear standard price, RAW doesn't - use PDF
                set_attr(merged, "price_tiers", pdf_price_tiers)
                set_attr(merged, "base_price", get_attr(pdf_offer, "base_price"))
                new_flags = [f for f in raw_flags if f != "MULTI_PRICE_UNCLEAR"]
                set_attr(merged, "flags", new_flags)
                inferred = get_attr(merged, "inferred", {})
                if isinstance(inferred, dict):
                    inferred["price"] = True
                    set_attr(merged, "inferred", inferred)
        
        # Update source to "merged"
        source = get_attr(merged, "source", {})
        if isinstance(source, dict):
            source["primary"] = "merged"
            pdf_source = get_attr(pdf_offer, "source", {})
            if isinstance(pdf_source, dict) and pdf_source.get("pdf_file"):
                source["pdf_file"] = pdf_source["pdf_file"]
            set_attr(merged, "source", source)
        elif hasattr(source, "primary"):
            source.primary = "merged"
            pdf_source = get_attr(pdf_offer, "source")
            if pdf_source and hasattr(pdf_source, "pdf_file") and pdf_source.pdf_file:
                source.pdf_file = pdf_source.pdf_file
        
        # Confidence: RAW-based is high, merged is medium
        if isinstance(source, dict):
            primary = source.get("primary", "merged")
        else:
            primary = getattr(source, "primary", "merged")
        
        if primary == "list":
            set_attr(merged, "confidence", "high")
        else:
            set_attr(merged, "confidence", "medium")
        
        return merged

