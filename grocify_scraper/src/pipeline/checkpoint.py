"""Checkpoint system for resumable pipeline runs"""

import json
import logging
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class CheckpointManager:
    """Manage checkpoints for resumable pipeline runs"""
    
    def __init__(self, checkpoint_path: Path):
        self.checkpoint_path = checkpoint_path
        self.checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
        self.data: Optional[Dict[str, Any]] = None
    
    def load(self) -> Dict[str, Any]:
        """Load checkpoint from disk"""
        if self.checkpoint_path.exists():
            try:
                with open(self.checkpoint_path, 'r', encoding='utf-8') as f:
                    self.data = json.load(f)
                logger.info(f"Loaded checkpoint from {self.checkpoint_path}")
                return self.data
            except Exception as e:
                logger.warning(f"Failed to load checkpoint: {e}")
                self.data = None
        
        return {}
    
    def save(self, data: Dict[str, Any]) -> bool:
        """Save checkpoint to disk"""
        try:
            # Add timestamp
            data["last_updated"] = datetime.now().isoformat()
            
            # Write to temp file first, then rename (atomic)
            temp_path = self.checkpoint_path.with_suffix('.tmp')
            with open(temp_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            temp_path.replace(self.checkpoint_path)
            self.data = data
            logger.debug(f"Checkpoint saved to {self.checkpoint_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to save checkpoint: {e}")
            return False
    
    def get_supermarket_status(self, supermarket: str) -> str:
        """Get status for a supermarket"""
        if not self.data:
            self.load()
        
        if not self.data:
            return "NOT_STARTED"
        
        markets = self.data.get("supermarkets", {})
        return markets.get(supermarket, {}).get("status", "NOT_STARTED")
    
    def update_supermarket(
        self, 
        supermarket: str, 
        status: str,
        updates: Optional[Dict[str, Any]] = None
    ) -> bool:
        """Update supermarket status and data"""
        if not self.data:
            self.data = {
                "weekKey": "",
                "version": 1,
                "globalLoop": 0,
                "supermarkets": {}
            }
        
        if "supermarkets" not in self.data:
            self.data["supermarkets"] = {}
        
        if supermarket not in self.data["supermarkets"]:
            self.data["supermarkets"][supermarket] = {
                "status": "NOT_STARTED",
                "pdf": {"pagesTotal": 0, "pagesDone": 0, "pageStats": {}},
                "raw": {"loaded": False, "count": 0},
                "offers": {"pdfCount": 0, "rawCount": 0, "mergedCount": 0, "stableLoops": 0},
                "artifacts": {"offersOut": None, "reportsOut": [], "recipesOut": None}
            }
        
        self.data["supermarkets"][supermarket]["status"] = status
        
        if updates:
            for key, value in updates.items():
                if key in self.data["supermarkets"][supermarket]:
                    if isinstance(self.data["supermarkets"][supermarket][key], dict) and isinstance(value, dict):
                        self.data["supermarkets"][supermarket][key].update(value)
                    else:
                        self.data["supermarkets"][supermarket][key] = value
                else:
                    self.data["supermarkets"][supermarket][key] = value
        
        return self.save(self.data)
    
    def update_page_stats(
        self,
        supermarket: str,
        page_num: int,
        stats: Dict[str, Any]
    ) -> bool:
        """Update page extraction stats"""
        if not self.data:
            self.load()
        
        if not self.data:
            self.data = {
                "weekKey": "",
                "version": 1,
                "globalLoop": 0,
                "supermarkets": {}
            }
        
        if supermarket not in self.data["supermarkets"]:
            self.data["supermarkets"][supermarket] = {
                "status": "EXTRACTING",
                "pdf": {"pagesTotal": 0, "pagesDone": 0, "pageStats": {}},
                "raw": {"loaded": False, "count": 0},
                "offers": {"pdfCount": 0, "rawCount": 0, "mergedCount": 0, "stableLoops": 0},
                "artifacts": {"offersOut": None, "reportsOut": [], "recipesOut": None}
            }
        
        page_key = str(page_num)
        self.data["supermarkets"][supermarket]["pdf"]["pageStats"][page_key] = stats
        
        # Update pagesDone
        pages_done = len([k for k, v in self.data["supermarkets"][supermarket]["pdf"]["pageStats"].items() 
                          if v.get("stable", False)])
        self.data["supermarkets"][supermarket]["pdf"]["pagesDone"] = pages_done
        
        return self.save(self.data)

