# 📸 Bild-Implementierung - Komplette Anleitung

## Übersicht

Die App lädt Rezept-Bilder aus lokal gebündelten Assets. Das System nutzt eine robuste Fallback-Kette: Asset → Network → Emoji.

---

## 1️⃣ Asset-Struktur (Bereits vorhanden ✅)

Deine Bilder sind bereits korrekt organisiert:

```
assets/
└── images/
    └── recipes/
        ├── aldi_nord/
        │   ├── R001.png
        │   ├── R002.png
        │   └── ...
        ├── aldi_sued/
        │   ├── R001.png
        │   └── ...
        ├── rewe/
        │   └── ...
        └── ...
```

**Wichtig:** 
- Format: PNG (oder WebP)
- Dateiname: Exakt `R###.png` (z.B. `R001.png`, `R050.png`)
- Pfad: `assets/images/recipes/<market>/<recipe_id>.png`

---

## 2️⃣ pubspec.yaml (Asset-Registrierung)

**Aktueller Stand:** Die Assets sind bereits registriert:

```yaml
flutter:
  assets:
    - assets/images/recipes/  # ✅ Bereits vorhanden
    - assets/recipes/
```

**Prüfung:**
```bash
# Stelle sicher, dass pubspec.yaml diese Zeile enthält:
grep -A 5 "flutter:" pubspec.yaml | grep "assets/images/recipes"
```

Falls die Zeile fehlt, füge sie hinzu und führe aus:
```bash
flutter clean
flutter pub get
```

---

## 3️⃣ JSON-Dateien (Recipe-Daten)

Deine JSON-Dateien sollten das `image_path` Feld enthalten:

```json
{
  "id": "R001",
  "title": "Hähnchen-Minutensteaks mit Avocado-Tomaten-Salsa",
  "market": "aldi_nord",
  "image_path": "assets/images/recipes/aldi_nord/R001.png",
  ...
}
```

**Falls `image_path` fehlt:** Das System berechnet es automatisch aus `market` + `id`.

---

## 4️⃣ Wie funktioniert die Bildladung?

### A) Recipe Model (`lib/data/models/recipe.dart`)

Das `Recipe` Model hat einen `imageAssetPath` Getter:

```dart
String? get imageAssetPath {
  // 1. Prüft image_path aus JSON
  if (heroImageUrl != null && heroImageUrl!.startsWith('assets/images/recipes/')) {
    return heroImageUrl;
  }
  
  // 2. Prüft image.asset_path
  if (image != null && image!['asset_path'] != null) {
    return image!['asset_path'];
  }
  
  // 3. Berechnet aus market + id
  final marketSlug = market ?? _extractMarketFromRetailer(retailer);
  if (marketSlug != null && id.isNotEmpty) {
    final normalizedId = id.replaceAll(RegExp(r'\.(webp|jpg|jpeg|png)$'), '');
    return 'assets/images/recipes/$marketSlug/$normalizedId.png';
  }
  
  return null;
}
```

### B) UI-Komponenten

#### 1. RecipeListCard (Listen-Ansicht)

```dart
Widget _buildRecipeImage() {
  final imagePath = recipe.imageAssetPath;
  
  // Versuche Asset-Bild
  if (imagePath != null && imagePath.startsWith('assets/')) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Fallback zu Emoji
        return Center(child: Text(_getEmoji(), style: TextStyle(fontSize: 52)));
      },
    );
  }
  
  // Fallback zu Network-Bild oder Emoji
  ...
}
```

#### 2. RecipeDetailScreen (Detail-Ansicht)

```dart
Widget _buildHeroImage(String emoji) {
  final imagePath = recipe.imageAssetPath;
  
  if (imagePath != null && imagePath.startsWith('assets/')) {
    return Positioned.fill(
      child: Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(child: Text(emoji, style: TextStyle(fontSize: 128)));
        },
      ),
    );
  }
  
  // Fallback zu Network-Bild oder Emoji
  ...
}
```

---

## 5️⃣ Fallback-Kette

Das System verwendet eine robuste Fallback-Kette:

1. **Asset-Bild** (`assets/images/recipes/<market>/R###.png`)
   - ✅ Wird bevorzugt verwendet
   - ✅ Funktioniert offline
   - ✅ Schnell (kein Netzwerk)

2. **Network-Bild** (`heroImageUrl` mit http:// oder https://)
   - Falls Asset nicht existiert
   - Lädt vom Server

3. **Emoji Fallback** (🍝, 🍛, 🥗, etc.)
   - Falls kein Bild verfügbar
   - Wird automatisch aus Rezept-Titel bestimmt

---

## 6️⃣ Was musst du tun?

### Schritt 1: Bilder organisieren

Stelle sicher, dass alle Bilder im richtigen Format vorliegen:

```bash
# Prüfe Struktur
ls -la assets/images/recipes/aldi_nord/

# Erwartete Ausgabe:
# R001.png
# R002.png
# R003.png
# ...
```

### Schritt 2: JSON-Dateien prüfen

Falls `image_path` in JSON fehlt, ist das OK - das System berechnet es automatisch.

**Optional:** Füge `image_path` manuell hinzu (macht es expliziter):

```bash
# Beispiel für aldi_nord_recipes.json
{
  "id": "R001",
  "title": "...",
  "market": "aldi_nord",
  "image_path": "assets/images/recipes/aldi_nord/R001.png",
  ...
}
```

### Schritt 3: Flutter Assets neu laden

Nach Änderungen an Assets:

```bash
flutter clean
flutter pub get
```

**Wichtig:** `flutter clean` löscht den Build-Cache - danach werden Assets neu gebündelt.

### Schritt 4: App testen

```bash
# Starte App im Debug-Mode
flutter run

# Oder im Release-Mode
flutter run --release
```

---

## 7️⃣ Debugging - Bilder werden nicht angezeigt?

### Problem 1: Bild existiert, wird aber nicht geladen

**Lösung:**
1. Prüfe `pubspec.yaml` - ist `assets/images/recipes/` registriert?
2. Führe `flutter clean && flutter pub get` aus
3. Prüfe Konsolen-Logs für Asset-Fehler

### Problem 2: Falscher Pfad in JSON

**Lösung:**
- Prüfe `image_path` in JSON
- Oder entferne es - das System berechnet es automatisch

### Problem 3: Market-Name stimmt nicht

**Lösung:**
- Stelle sicher, dass `market` in JSON korrekt ist (z.B. `"aldi_nord"`, nicht `"ALDI NORD"`)
- Oder füge `"market": "aldi_nord"` explizit hinzu

### Problem 4: ID-Format falsch

**Lösung:**
- IDs müssen exakt `R###` Format haben (z.B. `R001`, `R050`)
- Dateiname muss exakt `R###.png` sein (z.B. `R001.png`)

---

## 8️⃣ Beispiel-Workflow

### Szenario: Neues Rezept mit Bild hinzufügen

1. **Bild speichern:**
   ```bash
   # Speichere Bild als:
   assets/images/recipes/aldi_nord/R051.png
   ```

2. **JSON aktualisieren:**
   ```json
   {
     "id": "R051",
     "title": "Neues Rezept",
     "market": "aldi_nord",
     "image_path": "assets/images/recipes/aldi_nord/R051.png",
     ...
   }
   ```

3. **Flutter neu bauen:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

4. **Ergebnis:**
   - Bild wird automatisch in RecipeListCard angezeigt
   - Bild wird in RecipeDetailScreen als Hero-Image angezeigt
   - Falls Bild fehlt → Emoji Fallback

---

## 9️⃣ Code-Übersicht

### Recipe Model
- **Datei:** `lib/data/models/recipe.dart`
- **Getter:** `imageAssetPath` (berechnet Pfad automatisch)
- **Methoden:** `_extractMarketFromRetailer()` (hilft bei Retailer-Namen)

### UI-Komponenten
- **RecipeListCard:** `lib/features/recipes/presentation/widgets/recipe_list_card.dart`
  - Methode: `_buildRecipeImage()`
  
- **RecipeDetailScreen:** `lib/features/discover/recipe_detail_screen_new.dart`
  - Widget: `_HeroSection._buildHeroImage()`

### Repository
- **RecipeRepositoryOffline:** `lib/data/repositories/recipe_repository_offline.dart`
  - Lädt Rezepte aus Assets
  - Fügt automatisch `market` Feld hinzu (falls fehlt)

---

## 🔟 Quick-Start Checkliste

- [ ] `pubspec.yaml` enthält `assets/images/recipes/`
- [ ] Bilder sind im Format `R###.png` organisiert
- [ ] JSON enthält `market` Feld (oder wird automatisch erkannt)
- [ ] `flutter clean && flutter pub get` ausgeführt
- [ ] App getestet - Bilder werden angezeigt

---

## 📋 Zusammenfassung

**Die Bild-Implementierung ist bereits vollständig!**

Du musst nur sicherstellen, dass:
1. ✅ Bilder im richtigen Format/Ordner liegen
2. ✅ `pubspec.yaml` Assets registriert hat
3. ✅ `flutter clean && flutter pub get` ausgeführt wurde

Das System:
- ✅ Lädt Bilder automatisch aus Assets
- ✅ Berechnet Pfad aus `market` + `id` (falls `image_path` fehlt)
- ✅ Hat robuste Fallbacks (Asset → Network → Emoji)
- ✅ Funktioniert vollständig offline

**Nichts mehr zu implementieren - nur noch Assets organisieren und testen!** 🎉

