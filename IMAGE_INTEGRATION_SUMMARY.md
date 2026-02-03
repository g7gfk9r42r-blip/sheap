# Image Integration - Zusammenfassung

## Was wurde implementiert:

### 1. Recipe Model erweitert
- `Recipe.fromJson()` liest jetzt `image_path` aus JSON
- Konvertiert `image_path` zu `heroImageUrl` (Server-URL)
- Unterstützt verschiedene Pfad-Formate (relativ, absolut, mit/ohne "server/" Präfix)

### 2. URL-Konvertierung
- `_convertImagePathToUrl()` konvertiert lokale Pfade zu Server-URLs
- Nutzt `API_BASE_URL` aus Umgebung (Default: `http://localhost:3000`)
- Konvertiert z.B.: `server/media/recipe_images/norma/norma-rewe-1.webp` 
  → `http://localhost:3000/media/recipe_images/norma/norma-rewe-1.webp`

### 3. JSON-Dateien aktualisiert
- `recipes_with_images_*.json` Dateien wurden nach `assets/recipes/` kopiert
- Überschreiben die ursprünglichen `recipes_*.json` Dateien
- Enthalten `image_path` und `image_status` Felder

### 4. Server `/media` Endpoint
- Server serviert Bilder bereits über `/media/*` (laut `server/src/route.ts`)
- Bilder sind in `server/media/recipe_images/` verfügbar

## Nächste Schritte:

1. **Server starten** (falls noch nicht läuft):
   ```bash
   cd server
   npm run dev
   ```

2. **Flutter App starten** mit API_BASE_URL:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://localhost:3000
   ```

3. **Bilder testen**: Rezepte sollten jetzt Bilder anzeigen, wenn `image_path` in JSON vorhanden ist

## Hinweis:

Die Bilder werden über den Server geladen. Stelle sicher, dass:
- Server läuft (Port 3000)
- `/media` Endpoint korrekt gemountet ist
- Bilder in `server/media/recipe_images/` existieren
