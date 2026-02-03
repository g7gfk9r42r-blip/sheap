#!/usr/bin/env python3
"""
DEPRECATED: ReplicaImageClient - Alias für ReplicateImageClient
Diese Datei wird als Wrapper für Rückwärtskompatibilität bereitgestellt.
Nutze direkt tools/replicate_image.py::ReplicateImageClient
"""

from replicate_image import ReplicateImageClient

# Alias für Rückwärtskompatibilität
class ReplicaImageClient(ReplicateImageClient):
    """Alias für ReplicateImageClient - nutzt gleiche Implementierung"""
    pass

__all__ = ['ReplicaImageClient']
