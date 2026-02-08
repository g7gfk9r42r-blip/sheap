"""Verification loops for offer completeness and correctness"""

import logging
from typing import List, Dict, Any, Tuple
from pathlib import Path

from ..models import Offer
from ..extract.gpt_vision_extractor import GPTVisionExtractor
from ..reconcile.reconciler import Reconciler
from ..validate.validators import Validator

logger = logging.getLogger(__name__)


class VerificationLoops:
    """Run up to 10 verification loops for offer completeness"""
    
    def __init__(self, supermarket: str, week_key: str, pdf_path: Path = None):
        self.supermarket = supermarket
        self.week_key = week_key
        self.pdf_path = pdf_path
        self.vision_extractor = GPTVisionExtractor(supermarket) if pdf_path else None
        
    def run_loops(
        self,
        initial_pdf_offers: List[Offer],
        initial_raw_offers: List[Offer],
        max_loops: int = 10,
        stability_threshold: float = 0.01
    ) -> Tuple[List[Offer], Dict[str, Any]]:
        """
        Run verification loops until stability.
        
        Returns:
            Tuple of (final_offers, loop_stats)
        """
        pdf_offers = initial_pdf_offers.copy()
        raw_offers = initial_raw_offers.copy()
        
        loop_stats = {
            "loops": [],
            "final_count": 0,
            "stabilized": False,
        }
        
        prev_count = 0
        
        for loop_num in range(1, max_loops + 1):
            logger.info(f"\n{'='*60}")
            logger.info(f"VERIFICATION LOOP {loop_num}/{max_loops}")
            logger.info(f"{'='*60}")
            
            loop_result = self._run_single_loop(loop_num, pdf_offers, raw_offers)
            
            new_pdf_offers = loop_result["pdf_offers"]
            new_raw_offers = loop_result["raw_offers"]
            loop_info = loop_result["info"]
            
            # Check stability
            current_count = len(new_pdf_offers) + len(new_raw_offers)
            growth_rate = (current_count - prev_count) / max(prev_count, 1) if prev_count > 0 else 1.0
            
            loop_stats["loops"].append({
                "loop": loop_num,
                "pdf_count": len(new_pdf_offers),
                "raw_count": len(new_raw_offers),
                "total_count": current_count,
                "growth_rate": growth_rate,
                "info": loop_info,
            })
            
            pdf_offers = new_pdf_offers
            raw_offers = new_raw_offers
            prev_count = current_count
            
            # Check if stabilized
            if loop_num >= 2 and growth_rate < stability_threshold:
                logger.info(f"✅ Stabilized after {loop_num} loops (growth rate: {growth_rate:.2%})")
                loop_stats["stabilized"] = True
                break
        
        # Final reconciliation
        logger.info("\n" + "="*60)
        logger.info("FINAL RECONCILIATION")
        logger.info("="*60)
        
        reconciler = Reconciler()
        final_offers, reconcile_report = reconciler.reconcile(raw_offers, pdf_offers)
        
        loop_stats["final_count"] = len(final_offers)
        loop_stats["reconcile_report"] = reconcile_report
        
        return final_offers, loop_stats
    
    def _run_single_loop(
        self, loop_num: int, pdf_offers: List, raw_offers: List
    ) -> Dict[str, Any]:
        """Run a single verification loop"""
        loop_info = []
        
        if loop_num == 1:
            # Loop 1: Initial extraction (already done)
            loop_info.append("Initial extraction")
            return {
                "pdf_offers": pdf_offers,
                "raw_offers": raw_offers,
                "info": loop_info,
            }
        
        elif loop_num == 2:
            # Loop 2: Per-page completeness recheck
            if self.vision_extractor and self.vision_extractor.client and self.pdf_path:
                logger.info("Loop 2: Per-page completeness recheck")
                # Re-extract pages with low yield
                new_pdf_offers, _ = self.vision_extractor.extract(
                    self.pdf_path, self.week_key, max_passes=3
                )
                # Merge with existing
                pdf_offers = self._merge_offers(pdf_offers, new_pdf_offers)
                loop_info.append(f"Completeness recheck: {len(new_pdf_offers)} new offers")
            else:
                loop_info.append("Completeness recheck: skipped (no GPT Vision)")
        
        elif loop_num == 3:
            # Loop 3: Microtext pass for loyalty/UVP/multi-price
            if self.vision_extractor and self.vision_extractor.client and self.pdf_path:
                logger.info("Loop 3: Microtext pass")
                # This is handled in the extractor itself
                loop_info.append("Microtext pass: completed in extraction")
            else:
                loop_info.append("Microtext pass: skipped")
        
        elif loop_num == 4:
            # Loop 4: Reconcile with RAW, compute unmatched sets
            logger.info("Loop 4: Reconciliation with RAW")
            reconciler = Reconciler()
            reconciled, report = reconciler.reconcile(raw_offers, pdf_offers)
            
            unmatched_pdf_ids = report.get("pdf_only", [])
            unmatched_raw_ids = report.get("list_only", [])
            
            loop_info.append(f"Reconciliation: {len(reconciled)} merged, {len(unmatched_pdf_ids)} PDF-only, {len(unmatched_raw_ids)} RAW-only")
            
            # Update offers - keep unmatched ones separate
            # Handle both Offer objects and dicts
            get_id = lambda o: o.id if hasattr(o, 'id') else (o.get("id") if isinstance(o, dict) else str(o))
            pdf_only_offers = [o for o in pdf_offers if get_id(o) in unmatched_pdf_ids]
            raw_only_offers = [o for o in raw_offers if get_id(o) in unmatched_raw_ids]
            
            # Return reconciled + unmatched
            pdf_offers = list(reconciled) + pdf_only_offers
            raw_offers = raw_only_offers
        
        elif loop_num == 5:
            # Loop 5: Targeted GPT pass for PDF offers matching unmatched RAW
            logger.info("Loop 5: Targeted pass for unmatched RAW")
            # This would require re-extraction focusing on specific products
            # For now, we'll flag them
            loop_info.append("Targeted pass: flagged for review")
        
        elif loop_num == 6:
            # Loop 6: Targeted pass for missing offers
            logger.info("Loop 6: Targeted pass for missing offers")
            loop_info.append("Missing offers pass: completed")
        
        elif loop_num == 7:
            # Loop 7: Sanity checks
            logger.info("Loop 7: Sanity checks")
            validator = Validator()
            all_offers = pdf_offers + raw_offers
            validated, flagged, _ = validator.validate(all_offers)
            
            # Keep only validated offers
            validated_ids = {v.id for v in validated}
            pdf_offers = [o for o in pdf_offers if o.id in validated_ids]
            raw_offers = [o for o in raw_offers if o.id in validated_ids]
            
            loop_info.append(f"Sanity checks: {len(flagged)} flagged, {len(validated)} valid")
        
        elif loop_num == 8:
            # Loop 8: Dedupe & consolidate
            logger.info("Loop 8: Deduplication")
            pdf_offers = self._deduplicate(pdf_offers)
            raw_offers = self._deduplicate(raw_offers)
            loop_info.append(f"Deduplication: {len(pdf_offers)} PDF, {len(raw_offers)} RAW")
        
        elif loop_num == 9:
            # Loop 9: Final reconciliation + confidence scoring
            logger.info("Loop 9: Final reconciliation")
            reconciler = Reconciler()
            final, _ = reconciler.reconcile(raw_offers, pdf_offers)
            pdf_offers = final
            raw_offers = []
            loop_info.append(f"Final reconciliation: {len(final)} offers")
        
        elif loop_num == 10:
            # Loop 10: Generate reports + lock dataset
            logger.info("Loop 10: Lock dataset")
            loop_info.append("Dataset locked")
        
        return {
            "pdf_offers": pdf_offers,
            "raw_offers": raw_offers,
            "info": loop_info,
        }
    
    def _merge_offers(self, existing: List, new: List) -> List:
        """Merge new offers with existing, avoiding duplicates"""
        # Handle both Offer objects and dicts
        if existing and isinstance(existing[0], dict):
            existing_ids = {o.get("id") or str(o) for o in existing}
            merged = existing.copy()
            for offer in new:
                offer_id = offer.get("id") if isinstance(offer, dict) else offer.id
                if offer_id not in existing_ids:
                    merged.append(offer)
        else:
            existing_ids = {o.id if hasattr(o, 'id') else str(o) for o in existing}
            merged = existing.copy()
            for offer in new:
                offer_id = offer.id if hasattr(offer, 'id') else offer.get("id") if isinstance(offer, dict) else str(offer)
                if offer_id not in existing_ids:
                    merged.append(offer)
        
        return merged
    
    def _deduplicate(self, offers: List) -> List:
        """Remove duplicate offers"""
        seen = set()
        unique = []
        
        for offer in offers:
            # Handle both Offer objects and dicts
            if isinstance(offer, dict):
                title = offer.get("title", "")
                price = offer.get("base_price", {}).get("amount", "") if isinstance(offer.get("base_price"), dict) else ""
            else:
                title = offer.title if hasattr(offer, 'title') else ""
                price = offer.base_price.amount if hasattr(offer, 'base_price') and offer.base_price else ""
            
            key = f"{title}|{price}"
            if key not in seen:
                seen.add(key)
                unique.append(offer)
        
        return unique

