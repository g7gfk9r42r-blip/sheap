# Asset-Struktur Analyse & Fix Prompt

## Problem
Die Rezept-JSON-Dateien sind möglicherweise in zusätzlichen Unterordnern innerhalb der Supermarkt-Ordner organisiert.

## Aktuelle Implementierung
- **Erwartete Struktur:** `assets/prospekte/<market>/<market>_recipes.json`
- **Code:** Extrahiert Market aus erstem Unterordner nach `assets/prospekte/`
- **Unterstützt:** Auch Unterordner wie `assets/prospekte/<market>/<subfolder>/<market>_recipes.json`

## Mögliche Strukturen (zu prüfen)

### Option 1: Einfache Struktur (aktuell implementiert)
```
assets/prospekte/
  ├── rewe/
  │   └── rewe_recipes.json
  ├── lidl/
  │   └── lidl_recipes.json
  └── ...
```

### Option 2: Mit Unterordnern (bereits unterstützt)
```
assets/prospekte/
  ├── rewe/
  │   ├── recipes/
  │   │   └── rewe_recipes.json
  │   └── ...
  └── ...
```

### Option 3: Mehrere JSON-Dateien pro Market
```
assets/prospekte/
  ├── rewe/
  │   ├── rewe_recipes.json
  │   ├── rewe_offers.json
  │   └── ...
  └── ...
```

### Option 4: Datum/Woche-basierte Unterordner
```
assets/prospekte/
  ├── rewe/
  │   ├── 2024-W01/
  │   │   └── rewe_recipes.json
  │   ├── 2024-W02/
  │   │   └── rewe_recipes.json
  │   └── ...
  └── ...
```

## Aktueller Code-Status

### ✅ Bereits implementiert:
- Unterstützung für Unterordner: `assets/prospekte/<market>/<subfolder>/<market>_recipes.json`
- Market-Extraktion aus erstem Unterordner
- Filter: `prefix == "assets/prospekte/"` AND `suffix == "_recipes.json"`

### 🔍 Zu prüfen:
1. **Gibt es mehrere JSON-Dateien pro Market?**
   - Wenn ja: Sollen alle geladen werden oder nur `*_recipes.json`?
   
2. **Gibt es Datum/Woche-basierte Unterordner?**
   - Wenn ja: Soll die neueste Datei geladen werden oder alle?

3. **Gibt es andere Dateinamen-Patterns?**
   - z.B. `recipes_<market>.json` statt `<market>_recipes.json`?

## Debug-Output

Der aktuelle Code gibt aus:
- Gesamtanzahl Assets im Manifest
- Erste 30 Asset-Pfade (Beispiele)
- Gefundene Recipe JSONs mit vollständigen Pfaden
- Warnungen bei Pattern-Mismatches

## Nächste Schritte

1. **Führe aus:** `flutter run -d chrome`
2. **Prüfe Terminal-Output:**
   - Wie viele Recipe JSON Files wurden gefunden?
   - Welche Pfade werden angezeigt?
   - Gibt es Warnungen zu Pattern-Mismatches?

3. **Falls 0 gefunden:**
   - Prüfe Debug-Output: "Sample asset paths"
   - Suche nach JSON-Dateien die nicht dem Pattern entsprechen
   - Passe Filter/Pattern entsprechend an

## Mögliche Anpassungen

### Falls mehrere JSON-Dateien pro Market:
```dart
// Sammle alle JSONs pro Market
final jsonFilesByMarket = <String, List<String>>{};
for (final path in allAssetPaths) {
  if (path.startsWith('assets/prospekte/') && path.endsWith('.json')) {
    final parts = path.split('/');
    if (parts.length >= 3) {
      final market = parts[2];
      jsonFilesByMarket.putIfAbsent(market, () => []).add(path);
    }
  }
}
// Dann filtere nach *_recipes.json
```

### Falls Datum-basierte Unterordner:
```dart
// Sortiere nach Pfad (neueste zuerst) und nimm erste
final recipeFiles = <String, String>{};
for (final market in jsonFilesByMarket.keys) {
  final files = jsonFilesByMarket[market]!
      .where((p) => p.endsWith('${market}_recipes.json'))
      .toList()
    ..sort((a, b) => b.compareTo(a)); // Neueste zuerst
  if (files.isNotEmpty) {
    recipeFiles[market] = files.first;
  }
}
```

## Test-Kommando

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

Prüfe dann den Terminal-Output für:
- `📦 Total assets in manifest: X`
- `📋 Sample asset paths (first 30):`
- `📄 Recipe JSON Files Found: X`

