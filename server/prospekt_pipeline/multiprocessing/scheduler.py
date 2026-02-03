"""
🔥 Sunday Scheduler
Startet die Pipeline jeden Sonntag automatisch.
"""

from __future__ import annotations

import time
import datetime
import subprocess
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))


def run_every_sunday():
    """Run prospekt pipeline every Sunday."""
    print("📅 Scheduler gestartet – wartet auf Sonntag...")
    
    while True:
        now = datetime.datetime.now()

        if now.weekday() == 6:  # Sonntag
            print(f"📅 Sonntag ({now.strftime('%Y-%m-%d %H:%M:%S')}) – starte Prospekt-Pipeline...")
            
            try:
                subprocess.run(
                    ["python3", "-m", "prospekt_pipeline.multiprocessing.run_all"],
                    check=True,
                )
                print("✅ Pipeline erfolgreich abgeschlossen.")
            except subprocess.CalledProcessError as e:
                print(f"❌ Pipeline fehlgeschlagen: {e}")
            except KeyboardInterrupt:
                print("\n⚠️  Pipeline abgebrochen durch Benutzer")
                break

            print("⏳ Warte 24 Stunden bis zum nächsten Sonntag...")
            time.sleep(24 * 3600)
        else:
            # Wait 1 hour and check again
            time.sleep(3600)


if __name__ == "__main__":
    try:
        run_every_sunday()
    except KeyboardInterrupt:
        print("\n⚠️  Scheduler gestoppt durch Benutzer")
        sys.exit(0)
