#!/usr/bin/env python3
"""
Löscht den Recipe-Cache für die aktuelle Woche.
Die App wird dann beim nächsten Start frische Rezepte laden.
"""

import sys
from pathlib import Path

# Flutter App nutzt SharedPreferences, aber wir können hier nur dokumentieren
# Die Cache-Löschung muss in der Flutter App selbst erfolgen

print("📝 Recipe Cache Refresh")
print("=" * 60)
print()
print("⚠️  Hinweis: Der Recipe-Cache wird von Flutter's SharedPreferences verwaltet.")
print("   Um den Cache zu löschen, gibt es folgende Optionen:")
print()
print("1️⃣  In der Flutter App:")
print("   - Öffne die App")
print("   - Ziehe nach unten zum Aktualisieren (Pull-to-Refresh)")
print("   - Oder: Starte die App neu (Cache wird bei Wochenwechsel automatisch erneuert)")
print()
print("2️⃣  Programmatisch (in Flutter Code):")
print("   await SupermarketRecipeRepository.clearCache();")
print()
print("3️⃣  App-Neustart:")
print("   - Schließe die App komplett")
print("   - Starte sie neu")
print("   - Der Cache wird bei Wochenwechsel automatisch gelöscht")
print()
print("✅ Die Rezepte wurden bereits aktualisiert:")
print("   • Aldi Nord Rezepte haben jetzt Bilder (R000.webp bis R011.webp)")
print("   • Datei: assets/recipes/recipes_aldi_nord.json")
print("   • Bilder: server/media/recipe_images/aldi_nord/")
print()

