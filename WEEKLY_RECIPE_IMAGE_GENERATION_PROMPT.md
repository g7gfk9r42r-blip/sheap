# 🖼️ WÖCHENTLICHER RECIPE-IMAGE-GENERIERUNGS-PROMPT

## 📋 VORAUSSETZUNGEN

**Dieser Prompt wird NUR ausgeführt wenn:**
- ✅ Alle 12 Supermärkte erkannt wurden
- ✅ Alle Recipe-JSONs erfolgreich geladen wurden
- ✅ Jedes Rezept hat eine gültige ID im Format `R###` (z.B. `R001`, `R023`)

**Erkannte Supermärkte (MUSS alle 12 vorhanden sein):**
1. `aldi_nord`
2. `aldi_sued`
3. `biomarkt`
4. `kaufland`
5. `kaufland`
6. `lidl`
7. `nahkauf`
8. `netto`
9. `norma`
10. `penny`
11. `rewe`
12. `tegut`

---

## 🎯 AUFGABE

Generiere für **JEDES Rezept** aus **JEDEM Supermarkt** genau **EIN Bild** und speichere es mit dem exakten Dateinamen:

```
assets/images/<market>_<recipeId>.png
```

**Beispiele:**
- `assets/images/aldi_sued_R023.png`
- `assets/images/biomarkt_R001.png`
- `assets/images/lidl_R050.png`

---

## 📐 STRENGE REGELN

### 1. Dateinamen-Konvention
- **Format:** `<market>_<recipeId>.png`
- **Market:** Exakt der Ordnername aus `assets/prospekte/<market>/`
- **RecipeId:** Exakt die ID aus dem JSON (z.B. `R001`, `R023`)
- **Keine Unterordner:** Direkt in `assets/images/`
- **Extension:** Immer `.png`

### 2. 1:1 Zuordnung
- **Jedes Rezept** → **Genau ein Bild**
- **Jede Recipe-ID** → **Genau ein Dateiname**
- **Keine Duplikate:** Wenn Bild bereits existiert, überspringe es NICHT (erneuere es)

### 3. Bild-Generierung
- Verwende das `image_prompt` Feld aus dem Rezept-JSON
- Falls `image_prompt` fehlt, generiere basierend auf:
  - `title` (Rezeptname)
  - `description` (Beschreibung)
  - `ingredients` (Hauptzutaten)
- Bild-Stil: Realistische Food-Fotografie, professionell, appetitlich

### 4. Validierung
- **Vor Generierung:** Prüfe ob alle 12 Markets vorhanden sind
- **Nach Generierung:** Prüfe ob jedes Rezept genau ein Bild hat
- **Fehler-Report:** Liste alle fehlenden Bilder auf

---

## 🔍 PRÜFUNG: Alle 12 Supermärkte erkannt?

**Code-Logik (Flutter/Dart):**
```dart
// Lade alle Recipe-Dateien
final recipeFiles = await RecipeLoaderFromProspekte.discoverRecipeFiles();
final markets = recipeFiles.keys.toSet();

// Erwartete Markets (alle 12)
const expectedMarkets = {
  'aldi_nord',
  'aldi_sued',
  'biomarkt',
  'kaufland',
  'lidl',
  'nahkauf',
  'netto',
  'norma',
  'penny',
  'rewe',
  'tegut',
};

// Prüfung
if (markets.length != 12 || !markets.containsAll(expectedMarkets)) {
  print('❌ FEHLER: Nicht alle 12 Supermärkte erkannt!');
  print('   Gefunden: ${markets.length} Markets');
  print('   Fehlend: ${expectedMarkets.difference(markets)}');
  print('   Überschüssig: ${markets.difference(expectedMarkets)}');
  return; // ABBRUCH - Prompt wird NICHT ausgeführt
}

print('✅ Alle 12 Supermärkte erkannt!');
print('   Markets: ${markets.join(", ")}');
// JETZT Prompt ausführen
```

---

## 🚀 AUSFÜHRUNG

### Schritt 1: Prüfung
```bash
# Prüfe ob alle 12 Markets vorhanden sind
# (Implementierung in Flutter/Dart oder Python)
```

### Schritt 2: Rezepte laden
```dart
// Lade alle Rezepte aus allen Markets
final allRecipes = await RecipeLoaderFromProspekte.loadAllRecipesFromAssets();

// Gruppiere nach Market
final recipesByMarket = <String, List<Recipe>>{};
for (final recipe in allRecipes) {
  final market = recipe.market ?? recipe.retailer.toLowerCase();
  recipesByMarket.putIfAbsent(market, () => []).add(recipe);
}
```

### Schritt 3: Für jedes Rezept Bild generieren
```python
# Python-Script (Beispiel)
import os
from pathlib import Path

# Basis-Pfad
assets_images_dir = Path("assets/images")

# Für jeden Market
for market, recipes in recipes_by_market.items():
    print(f"\n🖼️  Generiere Bilder für {market} ({len(recipes)} Rezepte)...")
    
    for recipe in recipes:
        recipe_id = recipe['id']  # z.B. "R001", "R023"
        
        # Dateiname: <market>_<recipeId>.png
        filename = f"{market}_{recipe_id}.png"
        filepath = assets_images_dir / filename
        
        # Image-Prompt aus Rezept
        image_prompt = recipe.get('image_prompt') or f"{recipe['title']} - {recipe.get('description', '')}"
        
        # Generiere Bild (z.B. mit DALL-E, Stable Diffusion, etc.)
        image_data = generate_image(image_prompt)
        
        # Speichere als PNG
        with open(filepath, 'wb') as f:
            f.write(image_data)
        
        print(f"   ✅ {filename}")
```

### Schritt 4: Validierung
```python
# Prüfe ob jedes Rezept genau ein Bild hat
missing_images = []
for market, recipes in recipes_by_market.items():
    for recipe in recipes:
        recipe_id = recipe['id']
        filename = f"{market}_{recipe_id}.png"
        filepath = assets_images_dir / filename
        
        if not filepath.exists():
            missing_images.append(f"{market}_{recipe_id}")

if missing_images:
    print(f"\n❌ FEHLER: {len(missing_images)} Bilder fehlen!")
    for missing in missing_images:
        print(f"   - {missing}.png")
else:
    print(f"\n✅ ERFOLG: Alle {sum(len(r) for r in recipes_by_market.values())} Rezepte haben Bilder!")
```

---

## 📝 VOLLSTÄNDIGER PROMPT (für AI/LLM)

```
Du bist ein automatisiertes System zur wöchentlichen Recipe-Image-Generierung.

KONTEXT:
- Rezepte liegen in: assets/prospekte/<market>/<market>_recipes.json
- Bilder werden gespeichert in: assets/images/
- Dateinamen-Format: <market>_<recipeId>.png (z.B. aldi_sued_R023.png)

VORAUSSETZUNG:
Dieser Prompt wird NUR ausgeführt wenn ALLE 12 Supermärkte erkannt wurden:
1. aldi_nord
2. aldi_sued
3. biomarkt
4. kaufland
5. kaufland
6. lidl
7. nahkauf
8. netto
9. norma
10. penny
11. rewe
12. tegut

AUFGABE:
1. Lade alle Recipe-JSONs aus assets/prospekte/
2. Prüfe ob alle 12 Markets vorhanden sind
3. Wenn NICHT alle 12 vorhanden → ABBRUCH mit Fehlermeldung
4. Wenn alle 12 vorhanden → Fahre fort

FÜR JEDES REZEPT:
1. Extrahiere:
   - market (aus Ordnername)
   - recipeId (aus JSON, z.B. "R001", "R023")
   - image_prompt (aus JSON, oder generiere aus title + description)
   
2. Generiere Bild basierend auf image_prompt
   - Stil: Realistische Food-Fotografie, professionell, appetitlich
   - Format: PNG, 1024x1024 oder höher
   
3. Speichere als:
   assets/images/<market>_<recipeId>.png
   
   Beispiele:
   - assets/images/aldi_sued_R023.png
   - assets/images/biomarkt_R001.png
   - assets/images/lidl_R050.png

4. VALIDIERUNG:
   - Prüfe ob Datei existiert
   - Prüfe ob Dateiname exakt stimmt
   - Logge Erfolg/Fehler

NACH ALLEN GENERIERUNGEN:
1. Prüfe ob JEDES Rezept genau EIN Bild hat
2. Liste fehlende Bilder auf (falls vorhanden)
3. Erstelle Report:
   - Anzahl generierter Bilder
   - Anzahl fehlender Bilder
   - Liste aller Dateinamen

KRITISCHE REGELN:
- ❌ KEINE Unterordner in assets/images/
- ❌ KEINE abweichenden Dateinamen
- ❌ KEINE Duplikate (überschreibe existierende)
- ✅ Exakte 1:1 Zuordnung: Recipe-ID → Bild-Dateiname
- ✅ Dateiname = <market>_<recipeId>.png (exakt!)

FEHLERBEHANDLUNG:
- Wenn Market fehlt → ABBRUCH, zeige fehlende Markets
- Wenn Recipe-ID ungültig → Überspringe, logge Warnung
- Wenn Bild-Generierung fehlschlägt → Wiederhole max. 3x, dann logge Fehler
- Wenn Datei nicht gespeichert werden kann → Logge Fehler, fahre mit nächstem fort

OUTPUT:
- Zeige Fortschritt für jeden Market
- Zeige Zusammenfassung am Ende
- Liste alle Fehler/Warnungen
```

---

## 🔧 IMPLEMENTIERUNG (Python-Beispiel)

```python
#!/usr/bin/env python3
"""
Wöchentliche Recipe-Image-Generierung
Nur ausgeführt wenn alle 12 Supermärkte erkannt wurden
"""

import json
import os
from pathlib import Path
from typing import Dict, List

# Erwartete Markets (alle 12)
EXPECTED_MARKETS = {
    'aldi_nord', 'aldi_sued', 'biomarkt',
    'kaufland', 'lidl', 'nahkauf', 'netto',
    'norma', 'penny', 'rewe', 'tegut'
}

def check_all_markets_present() -> bool:
    """Prüft ob alle 12 Markets vorhanden sind"""
    prospekte_dir = Path("assets/prospekte")
    found_markets = set()
    
    for market_dir in prospekte_dir.iterdir():
        if not market_dir.is_dir():
            continue
        
        market = market_dir.name
        
        # Prüfe ob *_recipes.json oder <market>.json existiert
        recipes_file = market_dir / f"{market}_recipes.json"
        fallback_file = market_dir / f"{market}.json"
        
        if recipes_file.exists() or fallback_file.exists():
            found_markets.add(market)
    
    if found_markets != EXPECTED_MARKETS:
        missing = EXPECTED_MARKETS - found_markets
        extra = found_markets - EXPECTED_MARKETS
        print(f"❌ FEHLER: Nicht alle 12 Supermärkte erkannt!")
        print(f"   Gefunden: {len(found_markets)} Markets")
        if missing:
            print(f"   Fehlend: {missing}")
        if extra:
            print(f"   Überschüssig: {extra}")
        return False
    
    print(f"✅ Alle 12 Supermärkte erkannt: {sorted(found_markets)}")
    return True

def load_all_recipes() -> Dict[str, List[dict]]:
    """Lädt alle Rezepte gruppiert nach Market"""
    prospekte_dir = Path("assets/prospekte")
    recipes_by_market = {}
    
    for market_dir in prospekte_dir.iterdir():
        if not market_dir.is_dir():
            continue
        
        market = market_dir.name
        
        # Versuche *_recipes.json zuerst
        recipes_file = market_dir / f"{market}_recipes.json"
        if not recipes_file.exists():
            recipes_file = market_dir / f"{market}.json"
        
        if not recipes_file.exists():
            continue
        
        with open(recipes_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Handle verschiedene JSON-Strukturen
        if isinstance(data, list):
            recipes = data
        elif isinstance(data, dict):
            recipes = data.get('recipes', data.get('items', data.get('offers', [])))
        else:
            recipes = []
        
        recipes_by_market[market] = recipes
        print(f"   ✅ {market}: {len(recipes)} Rezepte")
    
    return recipes_by_market

def generate_image_for_recipe(market: str, recipe: dict) -> bytes:
    """Generiert Bild für ein Rezept (Implementierung je nach API)"""
    # TODO: Implementiere Bild-Generierung (DALL-E, Stable Diffusion, etc.)
    # Verwende recipe.get('image_prompt') oder generiere aus title + description
    image_prompt = recipe.get('image_prompt') or f"{recipe.get('title', '')} - {recipe.get('description', '')}"
    
    # Placeholder - ersetze mit echter API
    raise NotImplementedError("Implementiere Bild-Generierung")

def save_recipe_image(market: str, recipe_id: str, image_data: bytes):
    """Speichert Bild mit exaktem Dateinamen"""
    assets_images_dir = Path("assets/images")
    assets_images_dir.mkdir(parents=True, exist_ok=True)
    
    # Dateiname: <market>_<recipeId>.png
    filename = f"{market}_{recipe_id}.png"
    filepath = assets_images_dir / filename
    
    with open(filepath, 'wb') as f:
        f.write(image_data)
    
    return filepath

def main():
    """Hauptfunktion"""
    print("=" * 60)
    print("🖼️  WÖCHENTLICHE RECIPE-IMAGE-GENERIERUNG")
    print("=" * 60)
    
    # Schritt 1: Prüfe ob alle 12 Markets vorhanden sind
    print("\n📋 Schritt 1: Prüfe alle 12 Supermärkte...")
    if not check_all_markets_present():
        print("\n❌ ABBRUCH: Prompt wird NICHT ausgeführt!")
        return
    
    # Schritt 2: Lade alle Rezepte
    print("\n📋 Schritt 2: Lade alle Rezepte...")
    recipes_by_market = load_all_recipes()
    
    total_recipes = sum(len(recipes) for recipes in recipes_by_market.values())
    print(f"\n   Gesamt: {total_recipes} Rezepte in {len(recipes_by_market)} Markets")
    
    # Schritt 3: Generiere Bilder
    print("\n📋 Schritt 3: Generiere Bilder...")
    generated = 0
    failed = []
    
    for market, recipes in recipes_by_market.items():
        print(f"\n   🖼️  {market.upper()} ({len(recipes)} Rezepte)...")
        
        for recipe in recipes:
            recipe_id = recipe.get('id', '').strip()
            
            # Validiere Recipe-ID Format (R###)
            if not recipe_id.startswith('R') or len(recipe_id) != 4:
                print(f"      ⚠️  Überspringe ungültige ID: {recipe_id}")
                failed.append(f"{market}_{recipe_id}")
                continue
            
            try:
                # Generiere Bild
                image_data = generate_image_for_recipe(market, recipe)
                
                # Speichere
                filepath = save_recipe_image(market, recipe_id, image_data)
                print(f"      ✅ {filepath.name}")
                generated += 1
                
            except Exception as e:
                print(f"      ❌ Fehler bei {market}_{recipe_id}: {e}")
                failed.append(f"{market}_{recipe_id}")
    
    # Schritt 4: Validierung
    print("\n📋 Schritt 4: Validierung...")
    assets_images_dir = Path("assets/images")
    missing_images = []
    
    for market, recipes in recipes_by_market.items():
        for recipe in recipes:
            recipe_id = recipe.get('id', '').strip()
            if not recipe_id.startswith('R') or len(recipe_id) != 4:
                continue
            
            filename = f"{market}_{recipe_id}.png"
            filepath = assets_images_dir / filename
            
            if not filepath.exists():
                missing_images.append(filename)
    
    # Report
    print("\n" + "=" * 60)
    print("📊 ZUSAMMENFASSUNG")
    print("=" * 60)
    print(f"✅ Generiert: {generated} Bilder")
    if failed:
        print(f"❌ Fehlgeschlagen: {len(failed)} Rezepte")
        for f in failed[:10]:  # Zeige erste 10
            print(f"   - {f}.png")
    if missing_images:
        print(f"⚠️  Fehlend: {len(missing_images)} Bilder")
        for m in missing_images[:10]:  # Zeige erste 10
            print(f"   - {m}")
    else:
        print(f"✅ Alle {total_recipes} Rezepte haben Bilder!")
    print("=" * 60)

if __name__ == "__main__":
    main()
```

---

## ✅ CHECKLISTE

- [ ] Alle 12 Supermärkte erkannt?
- [ ] Alle Recipe-JSONs geladen?
- [ ] Für jedes Rezept Bild generiert?
- [ ] Dateinamen exakt: `<market>_<recipeId>.png`?
- [ ] Alle Bilder in `assets/images/` (keine Unterordner)?
- [ ] Jedes Rezept hat genau ein Bild?
- [ ] Validierung erfolgreich?
- [ ] Report erstellt?

---

## 🎯 ERGEBNIS

Nach erfolgreicher Ausführung:
- ✅ Alle Rezepte haben Bilder
- ✅ Dateinamen: `<market>_R###.png` (exakt!)
- ✅ 1:1 Zuordnung: Recipe-ID → Bild-Dateiname
- ✅ Keine falschen Zuordnungen möglich
- ✅ App lädt Bilder korrekt über `Image.asset("assets/images/<market>_<recipeId>.png")`

