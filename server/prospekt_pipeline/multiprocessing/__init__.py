"""Multiprocessing module for parallel prospekt processing."""
from __future__ import annotations

from .run_all import run_all
from .worker import process_folder, process_file
from .config import CPU_LIMIT

__all__ = [
    "run_all",
    "process_folder",
    "process_file",
    "CPU_LIMIT",
]

