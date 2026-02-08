"""Logging utilities"""
import sys
from datetime import datetime
from typing import Optional


class Logger:
    """Simple logger with console and optional file output"""
    
    def __init__(self, verbose: bool = False, log_file: Optional[str] = None):
        self.verbose = verbose
        self.log_file = log_file
        self.logs = []
    
    def _log(self, level: str, msg: str):
        """Internal log"""
        timestamp = datetime.now().isoformat()
        log_entry = f"[{timestamp}] {level}: {msg}"
        self.logs.append(log_entry)
        
        if self.verbose or level in ["ERROR", "WARNING"]:
            print(log_entry)
        
        if self.log_file:
            with open(self.log_file, 'a', encoding='utf-8') as f:
                f.write(log_entry + '\n')
    
    def info(self, msg: str):
        self._log("INFO", msg)
    
    def warning(self, msg: str):
        self._log("WARNING", msg)
    
    def error(self, msg: str):
        self._log("ERROR", msg)
    
    def debug(self, msg: str):
        if self.verbose:
            self._log("DEBUG", msg)
    
    def get_logs(self) -> list:
        return self.logs

