"""Configuration for multiprocessing pipeline."""
from __future__ import annotations

import multiprocessing

# CPU Limit: Use all cores minus 1 (leave one for system)
CPU_LIMIT = max(1, multiprocessing.cpu_count() - 1)
